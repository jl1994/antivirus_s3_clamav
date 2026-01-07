variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "monitored_bucket_name" {
  description = "Name for the S3 bucket to be monitored for antivirus scanning"
  type        = string
}

variable "quarantine_bucket_name" {
  description = "Name for the S3 bucket to store infected files"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue for S3 event notifications"
  type        = string
}

variable "sqs_queue_url" {
  description = "URL of the SQS queue for S3 event notifications"
  type        = string
}
