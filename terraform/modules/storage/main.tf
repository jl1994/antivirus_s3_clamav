# ============================================
# MODULE: Storage (S3 Buckets)
# ============================================
# Buckets monitoreados para escaneo + cuarentena
# ============================================

data "aws_region" "current" {}

# ============================================
# BUCKET MONITOREADO
# ============================================

resource "aws_s3_bucket" "monitored" {
  bucket = var.monitored_bucket_name

  tags = {
    Name        = var.monitored_bucket_name
    Purpose     = "Antivirus Scanning - Monitored Files"
    Environment = var.environment
  }
}

# Versionado para bucket monitoreado
resource "aws_s3_bucket_versioning" "monitored" {
  bucket = aws_s3_bucket.monitored.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado en reposo
resource "aws_s3_bucket_server_side_encryption_configuration" "monitored" {
  bucket = aws_s3_bucket.monitored.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloquear acceso público
resource "aws_s3_bucket_public_access_block" "monitored" {
  bucket = aws_s3_bucket.monitored.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================
# BUCKET DE CUARENTENA
# ============================================

resource "aws_s3_bucket" "quarantine" {
  bucket = var.quarantine_bucket_name

  tags = {
    Name        = var.quarantine_bucket_name
    Purpose     = "Antivirus Scanning - Quarantine for Infected Files"
    Environment = var.environment
  }
}

# Versionado para cuarentena
resource "aws_s3_bucket_versioning" "quarantine" {
  bucket = aws_s3_bucket.quarantine.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado para archivos en cuarentena
resource "aws_s3_bucket_server_side_encryption_configuration" "quarantine" {
  bucket = aws_s3_bucket.quarantine.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloquear acceso público a cuarentena
resource "aws_s3_bucket_public_access_block" "quarantine" {
  bucket = aws_s3_bucket.quarantine.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle para auto-eliminar archivos en cuarentena después de 90 días
resource "aws_s3_bucket_lifecycle_configuration" "quarantine" {
  bucket = aws_s3_bucket.quarantine.id

  rule {
    id     = "delete-quarantine-after-90-days"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ============================================
# SQS POLICY - Permitir que S3 envíe mensajes
# ============================================

resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = var.sqs_queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3ToSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = var.sqs_queue_arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.monitored.arn
          }
        }
      }
    ]
  })
}

# ============================================
# NOTIFICACIONES S3 → SQS
# ============================================

resource "aws_s3_bucket_notification" "monitored" {
  bucket = aws_s3_bucket.monitored.id

  queue {
    queue_arn     = var.sqs_queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = "" # Escanear todos los archivos
  }

  depends_on = [aws_sqs_queue_policy.allow_s3]
}
