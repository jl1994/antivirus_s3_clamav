variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "notification_email" {
  description = "Email address for malware detection alerts"
  type        = string
}

variable "notification_phone" {
  description = "Phone number for SMS alerts (E.164 format)"
  type        = string
  default     = ""
}
