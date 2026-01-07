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

output "quarantine_bucket_name" {
  description = "Name of the quarantine S3 bucket (infected files)"
  value       = module.storage.quarantine_bucket_id
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

output "sqs_queue_url" {
  description = "SQS Queue URL"
  value       = module.notifications.sqs_queue_url
}

output "sns_topic_arn" {
  description = "SNS Topic ARN for malware alerts"
  value       = module.notifications.sns_topic_arn
}

# ============================================
# CloudWatch Outputs
# ============================================

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name"
  value       = module.compute.cloudwatch_log_group_name
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
     → SQS Queue: ${module.notifications.sqs_queue_url}

  EOT
}
