# ============================================
# MAIN TERRAFORM CONFIGURATION
# S3 Antivirus Scanner with ClamAV
# ============================================
# Deployment automático de arquitectura serverless
# para escaneo de malware en S3 con cuarentena
# ============================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.52.0"
    }
  }

  # Backend S3 para state remoto (opcional)
  # Descomentar y configurar según tu bucket de state
  # backend "s3" {
  #   bucket  = "your-terraform-state-bucket"
  #   key     = "s3-antivirus/terraform.tfstate"
  #   region  = "us-east-1"
  #   encrypt = true
  # }
}

provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "Terraform"
      Repository  = "terraform-aws-s3-antivirus"
    }
  }
}

# ============================================
# DATA SOURCES
# ============================================

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================
# LOCAL VARIABLES
# ============================================

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  monitored_bucket_name  = "${var.project}-uploads-${var.region}"
  quarantine_bucket_name = "${var.project}-quarantine-${var.region}"
  ecr_repository_name    = "${var.project}-scanner"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
  }
}

# ============================================
# MODULE: NETWORKING
# ============================================

module "networking" {
  source = "./modules/networking"

  project_name       = var.project
  environment        = var.environment
  aws_region         = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = local.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
}

# ============================================
# MODULE: NOTIFICATIONS (SQS + SNS)
# ============================================

module "notifications" {
  source = "./modules/notifications"

  project_name       = var.project
  environment        = var.environment
  notification_email = var.notification_email
  notification_phone = var.notification_phone
}

# ============================================
# MODULE: STORAGE (S3 Buckets)
# ============================================

module "storage" {
  source = "./modules/storage"

  project_name           = var.project
  monitored_bucket_name  = local.monitored_bucket_name
  quarantine_bucket_name = local.quarantine_bucket_name
  environment            = var.environment
  sqs_queue_arn          = module.notifications.sqs_queue_arn
  sqs_queue_url          = module.notifications.sqs_queue_url

  depends_on = [module.notifications]
}

# ============================================
# MODULE: SECURITY (IAM Roles)
# ============================================

module "security" {
  source = "./modules/security"

  project_name          = var.project
  environment           = var.environment
  monitored_bucket_arn  = module.storage.monitored_bucket_arn
  quarantine_bucket_arn = module.storage.quarantine_bucket_arn
  sqs_queue_arn         = module.notifications.sqs_queue_arn
  sns_topic_arn         = module.notifications.sns_topic_arn

  depends_on = [module.storage, module.notifications]
}

# ============================================
# MODULE: COMPUTE (ECR + ECS)
# ============================================

module "compute" {
  source = "./modules/compute"

  project_name           = var.project
  environment            = var.environment
  aws_region             = var.region
  ecr_repository_name    = local.ecr_repository_name
  execution_role_arn     = module.security.ecs_task_execution_role_arn
  task_role_arn          = module.security.ecs_task_role_arn
  private_subnet_ids     = module.networking.private_subnet_ids
  security_group_id      = module.networking.ecs_tasks_security_group_id
  sqs_queue_url          = module.notifications.sqs_queue_url
  sqs_queue_name         = module.notifications.sqs_queue_name
  monitored_bucket_name  = local.monitored_bucket_name
  quarantine_bucket_name = local.quarantine_bucket_name
  sns_topic_arn          = module.notifications.sns_topic_arn

  task_cpu           = var.task_cpu
  task_memory        = var.task_memory
  desired_task_count = var.desired_task_count
  enable_autoscaling = var.enable_autoscaling
  min_task_count     = var.min_task_count
  max_task_count     = var.max_task_count

  depends_on = [module.networking, module.security]
}
