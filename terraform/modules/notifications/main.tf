# ============================================
# MODULE: Notifications (SNS + SQS)
# ============================================
# SNS para alertas de malware + SQS para procesamiento
# ============================================

# ============================================
# SQS QUEUE para eventos S3
# ============================================

resource "aws_sqs_queue" "scan_queue" {
  name                       = "${var.project_name}-scan-queue"
  visibility_timeout_seconds = 900     # 15 minutos para procesar
  message_retention_seconds  = 1209600 # 14 días
  receive_wait_time_seconds  = 20      # Long polling

  tags = {
    Name        = "${var.project_name}-scan-queue"
    Environment = var.environment
    Purpose     = "Antivirus scan event queue"
  }
}

# Dead Letter Queue para mensajes fallidos
resource "aws_sqs_queue" "scan_dlq" {
  name                      = "${var.project_name}-scan-dlq"
  message_retention_seconds = 1209600 # 14 días

  tags = {
    Name        = "${var.project_name}-scan-dlq"
    Environment = var.environment
    Purpose     = "Dead letter queue for failed scans"
  }
}

# Redrive policy
resource "aws_sqs_queue_redrive_policy" "scan_queue" {
  queue_url = aws_sqs_queue.scan_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.scan_dlq.arn
    maxReceiveCount     = 3
  })
}

# ============================================
# SNS TOPIC para alertas de malware
# ============================================

resource "aws_sns_topic" "malware_alerts" {
  name = "${var.project_name}-malware-alerts"

  tags = {
    Name        = "${var.project_name}-malware-alerts"
    Environment = var.environment
    Purpose     = "Malware detection alerts"
  }
}

# Subscription email
resource "aws_sns_topic_subscription" "malware_email" {
  topic_arn = aws_sns_topic.malware_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Subscription SMS (only if phone number provided)
resource "aws_sns_topic_subscription" "malware_sms" {
  count     = var.notification_phone != "" ? 1 : 0
  topic_arn = aws_sns_topic.malware_alerts.arn
  protocol  = "sms"
  endpoint  = var.notification_phone
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "malware_alerts" {
  arn = aws_sns_topic.malware_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSToPublish"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.malware_alerts.arn
      }
    ]
  })
}

# ============================================
# CLOUDWATCH ALARM - DLQ Monitoring
# ============================================

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project_name}-dlq-messages-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "Alarm when DLQ has more than 5 messages"
  alarm_actions       = [aws_sns_topic.malware_alerts.arn]

  dimensions = {
    QueueName = aws_sqs_queue.scan_dlq.name
  }

  tags = {
    Name        = "${var.project_name}-dlq-alarm"
    Environment = var.environment
  }
}
