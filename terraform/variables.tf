# ============================================
# TERRAFORM VARIABLES
# ============================================

# ============================================
# AWS Configuration
# ============================================

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "default"
}

# ============================================
# Project Configuration
# ============================================

variable "project" {
  description = "Project name (used for resource naming)"
  type        = string
  default     = "s3-antivirus"
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Project owner"
  type        = string
  default     = "Johan Luna"
}

# ============================================
# Networking Configuration
# ============================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway (costs ~$0.045/hour = ~$32/month)"
  type        = bool
  default     = true
}

# ============================================
# Notification Configuration
# ============================================

variable "notification_email" {
  description = "Email address for malware detection alerts"
  type        = string
  default     = "johanluna777@gmail.com"
}

variable "notification_phone" {
  description = "Phone number for SMS alerts (E.164 format: +573105405342)"
  type        = string
  default     = ""
}

# ============================================
# ECS Task Configuration
# ============================================

variable "task_cpu" {
  description = "CPU units for ECS task (256=0.25vCPU, 512=0.5vCPU, 1024=1vCPU)"
  type        = string
  default     = "512"

  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096"], var.task_cpu)
    error_message = "Valid values: 256, 512, 1024, 2048, 4096"
  }
}

variable "task_memory" {
  description = "Memory for ECS task in MB"
  type        = string
  default     = "1024"

  validation {
    condition     = contains(["512", "1024", "2048", "3072", "4096", "5120", "6144", "7168", "8192"], var.task_memory)
    error_message = "Must be valid Fargate memory value"
  }
}

variable "desired_task_count" {
  description = "Desired number of running ECS tasks"
  type        = number
  default     = 1
}

# ============================================
# Auto-Scaling Configuration
# ============================================

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
