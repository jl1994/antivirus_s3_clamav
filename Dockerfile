# Imagen base
FROM python:3.9-slim

# Instalar ClamAV
RUN apt-get update && \
    apt-get install -y clamav clamav-daemon && \
    freshclam && \
    apt-get clean

# Copiar el archivo de requisitos y la aplicación
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt


# Copiar los archivos de la aplicación
COPY . .

# Establecer directorio de trabajo
WORKDIR /antivirus_s3/

# Crear directorio para subidas
RUN mkdir -p /tmp/uploads

# Establecer variables de entorno
ENV DJANGO_ENV=development
ENV DJANGO_DEBUG=True

# Exponer el puerto en el que Django correrá
EXPOSE 80

# Comando para ejecutar la aplicación
CMD ["python", "manage.py", "runserver", "0.0.0.0:80"]