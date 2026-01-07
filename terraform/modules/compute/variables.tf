variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ecr_repository_name" {
  description = "Name for ECR repository"
  type        = string
}

variable "execution_role_arn" {
  description = "ARN of ECS task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of ECS task role"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "sqs_queue_url" {
  description = "URL of the SQS queue"
  type        = string
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "quarantine_bucket_name" {
  description = "Name of the quarantine bucket"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of SNS topic for notifications"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for ECS task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "Memory for ECS task in MB (512, 1024, 2048, 4096, etc.)"
  type        = string
  default     = "1024"
}

variable "desired_task_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "enable_autoscaling" {
  description = "Enable auto-scaling based on SQS queue depth"
  type        = bool
  default     = true
}

variable "min_task_count" {
  description = "Minimum number of tasks for auto-scaling"
  type        = number
  default     = 1
}

variable "max_task_count" {
  description = "Maximum number of tasks for auto-scaling"
  type        = number
  default     = 5
}

variable "sqs_target_value" {
  description = "Target SQS queue depth for scaling (messages per task)"
  type        = number
  default     = 10
}
