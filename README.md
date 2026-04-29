# S3 Antivirus Scanner

[![Terraform](https://img.shields.io/badge/Terraform-v1.5+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-ECS_Fargate-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![ClamAV](https://img.shields.io/badge/ClamAV-1.4-00A4EF)](https://www.clamav.net/)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Event-driven architecture on AWS that automatically scans every file uploaded to S3 with ClamAV. Infected files are moved to a quarantine bucket and the admin is notified by email/SMS.

---

## Architecture

```
User → S3 Uploads → SQS → ECS Fargate (Python + ClamAV)
                                  │
                          INFECTED │
                                  ▼
                     S3 Quarantine + SNS (email + SMS)
```

**AWS stack:** S3, SQS + DLQ, ECS Fargate, ECR, ClamAV 1.4, SNS, CloudWatch, VPC (multi-AZ), NAT Gateway, IAM (least-privilege roles).

---

## Prerequisites

- Terraform >= 1.5
- AWS CLI v2 configured (`aws configure`)
- Docker (for building the scanner image)
- Make

---

## Quick Start

### 1. Configure variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform/terraform.tfvars — set your email and AWS profile
```

### 2. Deploy infrastructure

```bash
make init
make plan       # review: expects ~58 resources
```

If the plan looks correct:

```bash
terraform -chdir=terraform apply -auto-approve
```

### 3. Build and push Docker image

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $(terraform -chdir=terraform output -raw ecr_repository_url)

# Build (linux/amd64 required for Fargate — mandatory on Apple Silicon)
docker buildx build --platform linux/amd64 -t s3-antivirus .

# Tag and push
docker tag s3-antivirus:latest \
  $(terraform -chdir=terraform output -raw ecr_repository_url):latest

docker push \
  $(terraform -chdir=terraform output -raw ecr_repository_url):latest
```

### 4. Force ECS redeployment and wait for stability

```bash
aws ecs update-service \
  --cluster $(terraform -chdir=terraform output -raw ecs_cluster_name) \
  --service $(terraform -chdir=terraform output -raw ecs_service_name) \
  --force-new-deployment \
  --region us-east-1 > /dev/null

aws ecs wait services-stable \
  --cluster $(terraform -chdir=terraform output -raw ecs_cluster_name) \
  --services $(terraform -chdir=terraform output -raw ecs_service_name) \
  --region us-east-1

echo "Service stable"
```

### 5. Confirm SNS subscription

After deploy, AWS sends a confirmation email. **Click "Confirm subscription"** in your inbox — without this, malware alert emails will not be delivered.

---

## Upload Files

```bash
# Single clean file
make upload-clean

# Single EICAR test file (simulated malware)
make upload-eicar

# Custom file
make upload-file FILE=/path/to/file.pdf KEY=uploads/file.pdf

# Or directly with AWS CLI
BUCKET=$(terraform -chdir=terraform output -raw monitored_bucket_name)

aws s3 cp myfile.pdf s3://$BUCKET/uploads/myfile.pdf --region us-east-1
```

After ~30 seconds, verify the scan result:

```bash
BUCKET=$(terraform -chdir=terraform output -raw monitored_bucket_name)

# Check tags on a scanned file
aws s3api get-object-tagging \
  --bucket $BUCKET \
  --key uploads/myfile.pdf \
  --region us-east-1
```

Expected tags:

| Tag | Value |
|-----|-------|
| `ScanStatus` | `CLEAN` or `INFECTED` |
| `ScanDate` | ISO 8601 timestamp |
| `FileHash` | SHA-256 of the file |
| `VirusName` | ClamAV signature name (only if INFECTED) |

Infected files are automatically moved to:

```
s3://<quarantine-bucket>/infected/YYYY/MM/DD/<sha256>_<original-key>
```

---

## Monitoring

```bash
# Stream worker logs live
make logs

# ECS service status
make status

# List running tasks
make tasks

# Check SQS queue depth
aws sqs get-queue-attributes \
  --queue-url $(terraform -chdir=terraform output -raw sqs_queue_url) \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  --region us-east-1
```

---

## Autoscaling Test

The service scales from 1 to 5 tasks when the SQS queue exceeds 10 visible messages (TargetTracking policy, scale-out cooldown 60 s).

```bash
# Upload 50 EICAR files in parallel to trigger autoscaling
make scale-test COUNT=50

# Watch scaling in real time (Ctrl+C to stop)
make watch-scale
```

Expected output from `watch-scale`:

```
Hora     | SQS Msgs   | Running    | Desired    | Pending
---------|------------|------------|------------|------------
16:14:00 | 47 (+3)    | 1          | 1          | 0
16:14:10 | 45 (+5)    | 1          | 5          | 4   ← scaled
16:16:00 | 12 (+5)    | 5          | 5          | 0   ← all running
16:18:00 | 0  (+0)    | 5          | 1          | 0   ← scale in
```

---

## Destroy

```bash
make destroy
```

`make destroy` empties both S3 buckets (including all versions) and then runs `terraform destroy -auto-approve`. Both S3 buckets and ECR are configured with `force_destroy = true` so no manual cleanup is needed.

After destroy, verify that the NAT Gateway is gone (it charges ~$0.045/h if left running):

```bash
aws ec2 describe-nat-gateways \
  --filter "Name=tag:Project,Values=s3-antivirus-tfm" \
  --region us-east-1 \
  --query 'NatGateways[?State!=`deleted`].[NatGatewayId,State]' \
  --output table
```

An empty table confirms full cleanup.

---

## All Make Targets

```bash
make help           # list all targets

# Infrastructure
make init           # terraform init
make validate       # terraform validate
make plan           # terraform plan
make deploy         # full deploy: terraform + docker build + ECR push + ECS update
make destroy        # empty buckets + terraform destroy

# Docker
make docker-build   # build image locally
make docker-run     # run container locally
make docker-stop    # stop local container

# Upload
make upload-clean   # upload a clean test file
make upload-eicar   # upload an EICAR test file
make upload-file    # upload FILE=path [KEY=s3-key]

# Monitoring
make logs           # tail CloudWatch logs (Ctrl+C to stop)
make status         # ECS service status table
make tasks          # list active ECS tasks
make outputs        # print Terraform outputs

# Testing
make test-eicar         # upload clean + EICAR and print verification commands
make test-eicar-local   # run EICAR scan inside local Docker container
make scale-test         # upload COUNT=N files to trigger autoscaling (default 25)
make watch-scale        # monitor SQS depth + ECS task count in real time

# Cleanup
make clean          # remove local temp files and Docker image
make empty-buckets  # empty S3 buckets (runs automatically inside destroy)
```

---

## Cost Estimate (us-east-1, 24/7)

| Service | Config | Monthly (USD) |
|---------|--------|---------------|
| ECS Fargate | 1 task, 0.5 vCPU, 1 GB | ~$15 |
| NAT Gateway | 2 AZs | ~$66 |
| VPC Endpoints | 3 Interface | ~$22 |
| S3 + SQS + SNS + CW | baseline | ~$4 |
| **Total** | | **~$107/mo** |

To cut costs, set `enable_nat_gateway = false` (saves ~$66/mo — requires manual ClamAV signature updates).

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Task stops with `CannotPullContainerError` | Image not in ECR or wrong arch | Re-run docker build + push steps |
| Files not scanned | S3→SQS notification not set | Run `terraform apply` again |
| Email not received | SNS subscription not confirmed | Check inbox + spam for confirmation link |
| Task loops restarting | Not enough memory | Set `task_memory = "2048"` in tfvars + apply |
| `terraform destroy` fails on S3 | Bucket not empty | Run `make empty-buckets` first |

---

## Author

**Johan Ederlien Luna Bermeo**
Master in Cybersecurity — Universidad Internacional de La Rioja (UNIR)
[LinkedIn](https://www.linkedin.com/in/johan-ederlien-luna-bermeo-b425ab98/) · [GitHub](https://github.com/jl1994)

---

## License

Apache License 2.0 — see [LICENSE](LICENSE).
