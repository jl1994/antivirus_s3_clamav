output "sqs_queue_url" {
  description = "URL of the SQS scan queue"
  value       = aws_sqs_queue.scan_queue.url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS scan queue"
  value       = aws_sqs_queue.scan_queue.arn
}

output "sqs_queue_name" {
  description = "Name of the SQS scan queue"
  value       = aws_sqs_queue.scan_queue.name
}

output "sqs_dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = aws_sqs_queue.scan_dlq.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS malware alerts topic"
  value       = aws_sns_topic.malware_alerts.arn
}
