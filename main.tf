resource "aws_s3_bucket" "antivirus" {
  bucket = var.project

  tags = {
    Name = "${var.project}"
  }
}

resource "aws_sqs_queue" "antivirus" {
  name = "sqs-${var.project}-queue"

  tags = {
    Name = "sqs-${var.project}-queue"
  }
}

resource "aws_sqs_queue_policy" "antivirus" {
  queue_url = aws_sqs_queue.antivirus.id

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "sqs_policy",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.antivirus.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.antivirus.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "antivirus" {
  bucket = aws_s3_bucket.antivirus.id

  queue {
    queue_arn     = aws_sqs_queue.antivirus.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".pdf"
  }

  queue {
    queue_arn     = aws_sqs_queue.antivirus.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".txt"
  }

  depends_on = [aws_sqs_queue.antivirus, aws_sqs_queue_policy.antivirus]
}
