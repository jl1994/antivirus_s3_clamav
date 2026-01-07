#!/usr/bin/env python3
"""
S3 Antivirus Scanner Worker
============================
Consume mensajes SQS, descarga archivos S3, escanea con ClamAV,
mueve infectados a cuarentena y envía notificaciones SNS.

Autor: Johan Luna
TFM: Máster en Ciberseguridad - UNIR
"""

import os
import json
import logging
import subprocess
import tempfile
import hashlib
from datetime import datetime
from urllib.parse import unquote_plus

import boto3
from botocore.exceptions import ClientError

# ============================================
# CONFIGURACIÓN
# ============================================

AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
SQS_QUEUE_URL = os.getenv('SQS_QUEUE_URL')
S3_QUARANTINE_BUCKET = os.getenv('S3_QUARANTINE_BUCKET')
SNS_TOPIC_ARN = os.getenv('SNS_TOPIC_ARN')
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')

# Configuración de logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Clientes AWS
s3_client = boto3.client('s3', region_name=AWS_REGION)
sqs_client = boto3.client('sqs', region_name=AWS_REGION)
sns_client = boto3.client('sns', region_name=AWS_REGION)

# ============================================
# FUNCIONES AUXILIARES
# ============================================

def calculate_file_hash(file_path):
    """Calcula SHA256 del archivo."""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()


def scan_file_with_clamav(file_path):
    """
    Escanea archivo con ClamAV.

    Returns:
        tuple: (is_infected, virus_name, scan_output)
    """
    try:
        # Ejecutar clamscan
        result = subprocess.run(
            ['clamscan', '--no-summary', file_path],
            capture_output=True,
            text=True,
            timeout=300  # 5 minutos timeout
        )

        output = result.stdout.strip()
        logger.info(f"ClamAV scan output: {output}")

        # ClamAV return codes:
        # 0 = no virus found
        # 1 = virus found
        # 2 = error

        if result.returncode == 0:
            return False, None, output
        elif result.returncode == 1:
            # Extraer nombre del virus
            virus_name = "Unknown"
            if "FOUND" in output:
                parts = output.split(":")
                if len(parts) > 1:
                    virus_name = parts[1].replace("FOUND", "").strip()
            return True, virus_name, output
        else:
            logger.error(f"ClamAV scan error: {result.stderr}")
            return None, None, f"ERROR: {result.stderr}"

    except subprocess.TimeoutExpired:
        logger.error("ClamAV scan timeout")
        return None, None, "ERROR: Scan timeout"
    except Exception as e:
        logger.error(f"ClamAV scan exception: {e}")
        return None, None, f"ERROR: {str(e)}"


def download_from_s3(bucket, key, local_path):
    """Descarga archivo desde S3."""
    try:
        logger.info(f"Downloading s3://{bucket}/{key} to {local_path}")
        s3_client.download_file(bucket, key, local_path)
        return True
    except ClientError as e:
        logger.error(f"Error downloading from S3: {e}")
        return False


def move_to_quarantine(bucket, key, virus_name, file_hash):
    """Mueve archivo infectado a bucket de cuarentena."""
    try:
        # Copiar a cuarentena con metadata
        quarantine_key = f"infected/{datetime.utcnow().strftime('%Y/%m/%d')}/{file_hash}_{key}"

        copy_source = {'Bucket': bucket, 'Key': key}
        s3_client.copy_object(
            CopySource=copy_source,
            Bucket=S3_QUARANTINE_BUCKET,
            Key=quarantine_key,
            Metadata={
                'virus-name': virus_name or 'Unknown',
                'original-bucket': bucket,
                'original-key': key,
                'quarantine-date': datetime.utcnow().isoformat(),
                'file-hash': file_hash
            },
            MetadataDirective='REPLACE',
            ServerSideEncryption='AES256'
        )

        logger.info(f"File moved to quarantine: s3://{S3_QUARANTINE_BUCKET}/{quarantine_key}")

        # Etiquetar archivo original como infectado
        s3_client.put_object_tagging(
            Bucket=bucket,
            Key=key,
            Tagging={
                'TagSet': [
                    {'Key': 'ScanStatus', 'Value': 'INFECTED'},
                    {'Key': 'VirusName', 'Value': virus_name or 'Unknown'},
                    {'Key': 'ScanDate', 'Value': datetime.utcnow().isoformat()}
                ]
            }
        )

        return quarantine_key

    except ClientError as e:
        logger.error(f"Error moving to quarantine: {e}")
        return None


def tag_file_as_clean(bucket, key, file_hash):
    """Etiqueta archivo como limpio."""
    try:
        s3_client.put_object_tagging(
            Bucket=bucket,
            Key=key,
            Tagging={
                'TagSet': [
                    {'Key': 'ScanStatus', 'Value': 'CLEAN'},
                    {'Key': 'ScanDate', 'Value': datetime.utcnow().isoformat()},
                    {'Key': 'FileHash', 'Value': file_hash}
                ]
            }
        )
        logger.info(f"File tagged as CLEAN: s3://{bucket}/{key}")
        return True
    except ClientError as e:
        logger.error(f"Error tagging file: {e}")
        return False


def send_sns_notification(subject, message):
    """Envía notificación SNS."""
    try:
        response = sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        logger.info(f"SNS notification sent: {response['MessageId']}")
        return True
    except ClientError as e:
        logger.error(f"Error sending SNS notification: {e}")
        return False


# ============================================
# PROCESAMIENTO DE MENSAJES
# ============================================

def process_s3_event(message):
    """
    Procesa un mensaje SQS con evento S3.

    Args:
        message: Mensaje SQS

    Returns:
        bool: True si se procesó correctamente
    """
    try:
        # Parse del mensaje
        body = json.loads(message['Body'])

        # Extraer información del evento S3
        if 'Records' not in body:
            logger.warning("No S3 records in message")
            return True  # Delete message

        for record in body['Records']:
            bucket = record['s3']['bucket']['name']
            key = unquote_plus(record['s3']['object']['key'])
            file_size = record['s3']['object']['size']

            logger.info(f"Processing: s3://{bucket}/{key} ({file_size} bytes)")

            # Crear archivo temporal
            with tempfile.NamedTemporaryFile(delete=False) as tmp_file:
                tmp_path = tmp_file.name

            try:
                # Descargar archivo
                if not download_from_s3(bucket, key, tmp_path):
                    logger.error("Failed to download file")
                    return False

                # Calcular hash
                file_hash = calculate_file_hash(tmp_path)
                logger.info(f"File hash (SHA256): {file_hash}")

                # Escanear con ClamAV
                is_infected, virus_name, scan_output = scan_file_with_clamav(tmp_path)

                if is_infected is None:
                    logger.error("Scan failed")
                    return False

                if is_infected:
                    # MALWARE DETECTADO
                    logger.warning(f"🚨 MALWARE DETECTED: {virus_name} in s3://{bucket}/{key}")

                    # Mover a cuarentena
                    quarantine_key = move_to_quarantine(bucket, key, virus_name, file_hash)

                    # Enviar alerta SNS
                    subject = f"🚨 MALWARE DETECTADO - {virus_name}"
                    message = f"""
ALERTA DE SEGURIDAD - MALWARE DETECTADO
========================================

Archivo Infectado: {key}
Bucket Original: {bucket}
Virus Detectado: {virus_name}
Hash (SHA256): {file_hash}
Tamaño: {file_size} bytes
Fecha: {datetime.utcnow().isoformat()}

Acción Tomada:
→ Archivo movido a cuarentena: s3://{S3_QUARANTINE_BUCKET}/{quarantine_key}
→ Archivo original etiquetado como INFECTED

Detalles del Escaneo:
{scan_output}

---
🤖 Generado automáticamente por S3 Antivirus Scanner
TFM - Johan Luna - UNIR
                    """
                    send_sns_notification(subject, message)

                else:
                    # ARCHIVO LIMPIO
                    logger.info(f"✅ File is CLEAN: s3://{bucket}/{key}")
                    tag_file_as_clean(bucket, key, file_hash)

            finally:
                # Limpiar archivo temporal
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)

        return True

    except Exception as e:
        logger.error(f"Error processing message: {e}", exc_info=True)
        return False


def main():
    """Loop principal del worker."""
    logger.info("🚀 S3 Antivirus Scanner Worker started")
    logger.info(f"SQS Queue: {SQS_QUEUE_URL}")
    logger.info(f"Quarantine Bucket: {S3_QUARANTINE_BUCKET}")
    logger.info(f"SNS Topic: {SNS_TOPIC_ARN}")

    # Verificar que ClamAV está disponible
    try:
        result = subprocess.run(['clamscan', '--version'], capture_output=True, text=True)
        logger.info(f"ClamAV version: {result.stdout.strip()}")
    except Exception as e:
        logger.error(f"ClamAV not available: {e}")
        return

    # Loop principal
    while True:
        try:
            # Recibir mensajes de SQS
            response = sqs_client.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=20,  # Long polling
                VisibilityTimeout=900  # 15 minutos
            )

            if 'Messages' not in response:
                logger.debug("No messages in queue")
                continue

            for message in response['Messages']:
                receipt_handle = message['ReceiptHandle']

                # Procesar mensaje
                success = process_s3_event(message)

                if success:
                    # Eliminar mensaje de la cola
                    sqs_client.delete_message(
                        QueueUrl=SQS_QUEUE_URL,
                        ReceiptHandle=receipt_handle
                    )
                    logger.info("Message processed and deleted from queue")
                else:
                    logger.error("Message processing failed, will retry")

        except KeyboardInterrupt:
            logger.info("Worker stopped by user")
            break
        except Exception as e:
            logger.error(f"Error in main loop: {e}", exc_info=True)
            continue


if __name__ == "__main__":
    main()
