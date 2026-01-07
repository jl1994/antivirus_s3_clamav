# ============================================
# S3 ANTIVIRUS SCANNER - DOCKERFILE
# ============================================
# Imagen Docker con ClamAV + Python Worker
# Para escaneo automatizado de archivos S3
# ============================================

FROM python:3.11-slim

LABEL maintainer="Johan Luna <johanluna777@gmail.com>"
LABEL description="S3 Antivirus Scanner with ClamAV - TFM UNIR"
LABEL version="1.0.0"

# Evitar prompts interactivos durante instalación
ENV DEBIAN_FRONTEND=noninteractive

# ============================================
# INSTALACIÓN DE CLAMAV
# ============================================

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        clamav \
        clamav-daemon \
        clamav-freshclam \
        wget \
        curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Actualizar firmas de ClamAV
RUN freshclam || echo "FreshClam update failed, continuing..."

# ============================================
# CONFIGURACIÓN PYTHON
# ============================================

# Directorio de trabajo
WORKDIR /app

# Copiar requirements
COPY requirements.txt .

# Instalar dependencias Python
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ============================================
# COPIAR CÓDIGO
# ============================================

# Copiar worker script
COPY scanner_worker.py .

# Hacer ejecutable
RUN chmod +x scanner_worker.py

# ============================================
# VARIABLES DE ENTORNO
# ============================================

ENV AWS_REGION=us-east-1
ENV LOG_LEVEL=INFO
ENV PYTHONUNBUFFERED=1

# ============================================
# HEALTHCHECK
# ============================================

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f scanner_worker.py || exit 1

# ============================================
# ENTRYPOINT
# ============================================

# Actualizar ClamAV en background y ejecutar worker
CMD freshclam -d & python3 -u scanner_worker.py