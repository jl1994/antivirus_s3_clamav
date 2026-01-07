output "monitored_bucket_id" {
  description = "ID of the monitored S3 bucket"
  value       = aws_s3_bucket.monitored.id
}

output "monitored_bucket_arn" {
  description = "ARN of the monitored S3 bucket"
  value       = aws_s3_bucket.monitored.arn
}

output "quarantine_bucket_id" {
  description = "ID of the quarantine S3 bucket"
  value       = aws_s3_bucket.quarantine.id
}

output "quarantine_bucket_arn" {
  description = "ARN of the quarantine S3 bucket"
  value       = aws_s3_bucket.quarantine.arn
}
