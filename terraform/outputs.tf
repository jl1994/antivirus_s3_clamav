# ============================================
# TERRAFORM OUTPUTS
# ============================================

# ============================================
# Account Information
# ============================================

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = var.region
}

# ============================================
# Storage Outputs
# ============================================

output "monitored_bucket_name" {
  description = "Name of the monitored S3 bucket (upload files here for scanning)"
  value       = module.storage.monitored_bucket_id
}

output "monitored_bucket_arn" {
  description = "ARN of the monitored S3 bucket"
  value       = module.storage.monitored_bucket_arn
}

output "quarantine_bucket_name" {
  description = "Name of the quarantine S3 bucket (infected files)"
  value       = module.storage.quarantine_bucket_id
}

output "quarantine_bucket_arn" {
  description = "ARN of the quarantine S3 bucket"
  value       = module.storage.quarantine_bucket_arn
}

# ============================================
# Networking Outputs
# ============================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "nat_gateway_ips" {
  description = "NAT Gateway public IPs"
  value       = module.networking.nat_gateway_ips
}

# ============================================
# Compute Outputs
# ============================================

output "ecr_repository_url" {
  description = "ECR repository URL (use for docker push)"
  value       = module.compute.ecr_repository_url
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = module.compute.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS Service name"
  value       = module.compute.ecs_service_name
}

# ============================================
# Notifications Outputs
# ============================================

output "sqs_queue_name" {
  description = "SQS Queue name"
  value       = module.notifications.sqs_queue_name
}

output "sqs_queue_url" {
  description = "SQS Queue URL"
  value       = module.notifications.sqs_queue_url
}

output "sqs_queue_arn" {
  description = "SQS Queue ARN"
  value       = module.notifications.sqs_queue_arn
}

output "sqs_dlq_name" {
  description = "SQS Dead Letter Queue name"
  value       = module.notifications.sqs_dlq_name
}

output "sqs_dlq_arn" {
  description = "SQS Dead Letter Queue ARN"
  value       = module.notifications.sqs_dlq_arn
}

output "sns_topic_name" {
  description = "SNS Topic name for malware alerts"
  value       = split(":", module.notifications.sns_topic_arn)[5]
}

output "sns_topic_arn" {
  description = "SNS Topic ARN for malware alerts"
  value       = module.notifications.sns_topic_arn
}

output "notification_email" {
  description = "Email configured for notifications"
  value       = var.notification_email
}

output "notification_phone" {
  description = "Phone number configured for SMS notifications"
  value       = var.notification_phone != "" ? var.notification_phone : "Not configured"
}

# ============================================
# CloudWatch Outputs
# ============================================

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name"
  value       = module.compute.cloudwatch_log_group_name
}

# ============================================
# Security & IAM Outputs
# ============================================

output "ecs_task_role_arn" {
  description = "ECS Task Role ARN"
  value       = module.security.ecs_task_role_arn
}

output "ecs_task_execution_role_arn" {
  description = "ECS Task Execution Role ARN"
  value       = module.security.ecs_task_execution_role_arn
}

# ============================================
# Networking Details
# ============================================

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = var.vpc_cidr
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

# ============================================
# Configuration Summary
# ============================================

output "configuration_summary" {
  description = "Configuration summary"
  value = {
    project            = var.project
    environment        = var.environment
    region             = var.region
    vpc_cidr           = var.vpc_cidr
    task_cpu           = var.task_cpu
    task_memory        = var.task_memory
    desired_task_count = var.desired_task_count
    autoscaling_enabled = var.enable_autoscaling
    min_tasks          = var.min_task_count
    max_tasks          = var.max_task_count
  }
}

# ============================================
# Quick Start Commands
# ============================================

output "next_steps" {
  description = "Next steps for deployment"
  value       = <<-EOT

  ╔═══════════════════════════════════════════════════════════════╗
  ║              DEPLOYMENT COMPLETADO - PRÓXIMOS PASOS           ║
  ╚═══════════════════════════════════════════════════════════════╝

  1️⃣  CONFIRMAR SUSCRIPCIÓN EMAIL:
     → Revisa tu email: ${var.notification_email}
     → Confirma la suscripción SNS

  2️⃣  BUILD & PUSH IMAGEN DOCKER:
     → cd ..
     → aws ecr get-login-password --region ${var.region} --profile ${var.profile} | docker login --username AWS --password-stdin ${module.compute.ecr_repository_url}
     → docker build -t ${local.ecr_repository_name} .
     → docker tag ${local.ecr_repository_name}:latest ${module.compute.ecr_repository_url}:latest
     → docker push ${module.compute.ecr_repository_url}:latest

  3️⃣  VERIFICAR DEPLOYMENT:
     → aws ecs describe-services --cluster ${module.compute.ecs_cluster_name} --services ${module.compute.ecs_service_name} --region ${var.region} --profile ${var.profile}

  4️⃣  PROBAR CON FICHERO EICAR:
     → echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > eicar.txt
     → aws s3 cp eicar.txt s3://${module.storage.monitored_bucket_id}/ --profile ${var.profile}

  5️⃣  MONITOREAR LOGS:
     → aws logs tail ${module.compute.cloudwatch_log_group_name} --follow --region ${var.region} --profile ${var.profile}

  📊 RECURSOS CREADOS:
     → Monitored Bucket: ${module.storage.monitored_bucket_id}
     → Quarantine Bucket: ${module.storage.quarantine_bucket_id}
     → ECR Repository: ${module.compute.ecr_repository_url}
     → ECS Cluster: ${module.compute.ecs_cluster_name}
     → SQS Queue: ${module.notifications.sqs_queue_name}
     → SNS Topic: ${split(":", module.notifications.sns_topic_arn)[5]}

  EOT
}

# ============================================
# AWS Console URLs
# ============================================

output "aws_console_urls" {
  description = "AWS Console URLs for easy access"
  value = {
    s3_monitored_bucket = "https://s3.console.aws.amazon.com/s3/buckets/${module.storage.monitored_bucket_id}?region=${var.region}"
    s3_quarantine_bucket = "https://s3.console.aws.amazon.com/s3/buckets/${module.storage.quarantine_bucket_id}?region=${var.region}"
    ecs_cluster = "https://${var.region}.console.aws.amazon.com/ecs/v2/clusters/${module.compute.ecs_cluster_name}/services?region=${var.region}"
    ecs_service = "https://${var.region}.console.aws.amazon.com/ecs/v2/clusters/${module.compute.ecs_cluster_name}/services/${module.compute.ecs_service_name}?region=${var.region}"
    ecr_repository = "https://${var.region}.console.aws.amazon.com/ecr/repositories/private/${data.aws_caller_identity.current.account_id}/${local.ecr_repository_name}?region=${var.region}"
    sqs_queue = "https://${var.region}.console.aws.amazon.com/sqs/v2/home?region=${var.region}#/queues/https%3A%2F%2Fsqs.${var.region}.amazonaws.com%2F${data.aws_caller_identity.current.account_id}%2F${module.notifications.sqs_queue_name}"
    sns_topic = "https://${var.region}.console.aws.amazon.com/sns/v3/home?region=${var.region}#/topic/${module.notifications.sns_topic_arn}"
    cloudwatch_logs = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#logsV2:log-groups/log-group/${replace(module.compute.cloudwatch_log_group_name, "/", "$252F")}"
    vpc = "https://${var.region}.console.aws.amazon.com/vpc/home?region=${var.region}#VpcDetails:VpcId=${module.networking.vpc_id}"
  }
}

# ============================================
# Admin Commands
# ============================================

output "useful_commands" {
  description = "Useful commands for administration"
  value = {
    view_logs = "aws logs tail ${module.compute.cloudwatch_log_group_name} --follow --region ${var.region}"
    list_tasks = "aws ecs list-tasks --cluster ${module.compute.ecs_cluster_name} --region ${var.region}"
    describe_service = "aws ecs describe-services --cluster ${module.compute.ecs_cluster_name} --services ${module.compute.ecs_service_name} --region ${var.region}"
    list_monitored_files = "aws s3 ls s3://${module.storage.monitored_bucket_id}/ --recursive"
    list_quarantine_files = "aws s3 ls s3://${module.storage.quarantine_bucket_id}/infected/ --recursive"
    check_sqs_messages = "aws sqs get-queue-attributes --queue-url ${module.notifications.sqs_queue_url} --attribute-names ApproximateNumberOfMessages --region ${var.region}"
    upload_test_file = "aws s3 cp <file> s3://${module.storage.monitored_bucket_id}/"
  }
}
