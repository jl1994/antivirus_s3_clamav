# 🛡️ S3 Antivirus Scanner

[![Terraform](https://img.shields.io/badge/Terraform-v1.5+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-ECS_Fargate-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![ClamAV](https://img.shields.io/badge/ClamAV-Latest-00A4EF?logo=clamav)](https://www.clamav.net/)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

**Arquitectura serverless automatizada en AWS para detección y cuarentena de malware en tiempo real en buckets S3 usando ClamAV.**

---

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Arquitectura](#-arquitectura)
- [Requisitos Previos](#-requisitos-previos)
- [Instalación](#-instalación)
- [Configuración](#-configuración)
- [Despliegue](#-despliegue)
- [Testing Local con Docker](#-testing-local-con-docker)
- [Pruebas con EICAR](#-pruebas-con-eicar)
- [Monitoreo](#-monitoreo)
- [Costos Estimados](#-costos-estimados)
- [Troubleshooting](#-troubleshooting)
- [Contribuciones](#-contribuciones)
- [Licencia](#-licencia)

---

## ✨ Características

- ✅ **Escaneo automático** de todos los archivos subidos a S3
- ✅ **Arquitectura serverless** con AWS ECS Fargate (sin servidores que administrar)
- ✅ **Infraestructura como Código** (IaC) con Terraform modular y reutilizable
- ✅ **Alta disponibilidad** con deployment Multi-AZ
- ✅ **Auto-escalado** basado en la profundidad de la cola SQS (1-5 tareas)
- ✅ **Cuarentena automática** de archivos infectados con metadata enriquecida
- ✅ **Notificaciones por email** vía SNS ante detección de malware
- ✅ **Actualización automática** de firmas ClamAV mediante FreshClam
- ✅ **Seguridad robusta**: VPC privada, least privilege IAM, cifrado en reposo
- ✅ **Costos optimizados** con VPC Endpoints y lifecycle policies

---

## 🏗️ Arquitectura

### Diagrama General

```
┌─────────────┐
│   Usuario   │
│  Upload File│
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│              AWS CLOUD (us-east-1)                       │
│                                                           │
│  ┌─────────────┐  ②Event   ┌─────────────┐             │
│  │ S3 Monitored├──────────►│ EventBridge │             │
│  │   Bucket    │            └──────┬──────┘             │
│  └─────────────┘                   │                     │
│                                    │ ③Send               │
│  ┌─────────────┐                   ▼                     │
│  │ S3 Quarantine│◄─⑦────┌──────────────┐                │
│  │   Bucket     │ Copy  │  SQS Queue   │                │
│  └─────────────┘        └──────┬───────┘                │
│                                 │                         │
│                          ④Poll  │                         │
│  ┌──────────────────────────────▼──────────────┐        │
│  │  VPC 10.200.0.0/16                          │        │
│  │  ┌────────────────────────────────────┐     │        │
│  │  │ Private Subnets (/27)              │     │        │
│  │  │                                     │     │        │
│  │  │  ┌──────────────────────────┐     │     │        │
│  │  │  │  ECS Fargate Tasks       │     │     │        │
│  │  │  │  ┌────────────────────┐  │     │     │        │
│  │  │  │  │ ClamAV Engine      │  │     │     │        │
│  │  │  │  │ Python Worker      │  │     │     │        │
│  │  │  │  └────────────────────┘  │     │     │        │
│  │  │  │  CPU: 0.5 vCPU          │     │     │        │
│  │  │  │  RAM: 1 GB              │     │     │        │
│  │  │  │  Auto-scale: 1-5 tasks  │     │     │        │
│  │  │  └──────────────────────────┘     │     │        │
│  │  └────────────────────────────────────┘     │        │
│  │                                               │        │
│  │  ┌────────────────────────────────────┐     │        │
│  │  │ Public Subnets (/24)               │     │        │
│  │  │  ┌──────────────┐                  │     │        │
│  │  │  │ NAT Gateway  │                  │     │        │
│  │  │  └──────────────┘                  │     │        │
│  │  └────────────────────────────────────┘     │        │
│  └──────────────────────────────────────────────┘        │
│                                                           │
│  ⑧ Malware Detected?                                     │
│         │                                                 │
│         ▼                                                 │
│  ┌─────────────┐                                         │
│  │  SNS Topic  │─────────────────────────────────────┐   │
│  └─────────────┘                                     │   │
└──────────────────────────────────────────────────────┼───┘
                                                       │
                                                       ▼
                                             ┌─────────────────┐
                                             │ 📧 Email Alert  │
                                             │johanluna777@... │
                                             └─────────────────┘
```

### Flujo de Procesamiento

1. **Upload**: Usuario sube archivo a S3 bucket monitoreado
2. **Event**: S3 genera evento `ObjectCreated` → EventBridge
3. **Queue**: EventBridge envía mensaje a SQS Queue
4. **Poll**: ECS Fargate tasks consumen mensajes (long polling 20s)
5. **Scan**: Descarga archivo, ejecuta `clamscan`, calcula hash SHA256
6. **Decision**:
   - **CLEAN**: Aplica tags `ScanStatus: CLEAN` al objeto S3
   - **INFECTED**: Copia a bucket de cuarentena con metadata + envía alerta SNS
7. **Cleanup**: Elimina archivo temporal y mensaje SQS
8. **Notification**: SNS envía email si se detectó malware

---

## 📦 Requisitos Previos

### Software Necesario

- **Terraform** >= 1.5.0 ([Descargar](https://www.terraform.io/downloads))
- **AWS CLI** >= 2.x ([Instalar](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **Docker** >= 20.x (para testing local) ([Instalar](https://docs.docker.com/get-docker/))
- **Make** (incluido en macOS/Linux, Git Bash en Windows)

### Cuenta AWS

- Cuenta AWS activa
- IAM User con permisos suficientes:
  - `AmazonEC2FullAccess`
  - `AmazonS3FullAccess`
  - `AmazonECSFullAccess`
  - `IAMFullAccess`
  - `AmazonVPCFullAccess`
  - `AmazonSQSFullAccess`
  - `AmazonSNSFullAccess`

> **Nota**: En producción, usa roles IAM más restrictivos basados en el principio de mínimo privilegio.

### Configurar AWS CLI

```bash
# Configurar AWS CLI (usar perfil default)
aws configure

# Verificar credenciales
aws sts get-caller-identity
```

---

## 🚀 Instalación

### 1. Clonar Repositorio

```bash
git clone https://github.com/jl1994/terraform-aws-s3-antivirus.git
cd terraform-aws-s3-antivirus
```

### 2. Verificar Requisitos

```bash
# Verificar versiones
terraform version    # Debe ser >= 1.5.0
aws --version        # Debe ser >= 2.x
docker --version     # Para testing local
make --version       # Para comandos automatizados
```

---

## ⚙️ Configuración

### 1. Crear Archivo de Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### 2. Editar `terraform/terraform.tfvars`

```hcl
# AWS Configuration
region  = "us-east-1"       # Región AWS donde desplegar
profile = "default"         # Perfil AWS CLI configurado

# Project Configuration
project     = "s3-antivirus"
environment = "dev"
owner       = "Johan Luna"

# Networking Configuration
vpc_cidr           = "10.200.0.0/16"  # CIDR poco común para evitar solapamiento
enable_nat_gateway = true              # Habilitar NAT Gateway ($0.045/hora)

# Notification Configuration
notification_email = "tu-email@example.com"     # ⚠️ IMPORTANTE: Cambiar a tu email
notification_phone = "+57XXXXXXXXXX"            # (Opcional) Número para alertas SMS en formato E.164

# ECS Task Configuration
task_cpu    = "512"   # 0.5 vCPU
task_memory = "1024"  # 1 GB

# Auto Scaling Configuration
desired_task_count = 1    # Número inicial de tareas
enable_autoscaling = true
min_task_count     = 1    # Mínimo de tareas
max_task_count     = 5    # Máximo de tareas
```

### 3. (Opcional) Configurar Backend Remoto S3

Si quieres almacenar el state de Terraform en S3:

1. Crear bucket para Terraform state:

```bash
aws s3 mb s3://tu-terraform-state-bucket ```

2. Descomentar y configurar en `terraform/main.tf`:

```hcl
backend "s3" {
  bucket  = "tu-terraform-state-bucket"
  key     = "s3-antivirus/terraform.tfstate"
  region  = "us-east-1"
  profile = "default"
  encrypt = true
}
```

---

## 🎯 Despliegue

### Opción 1: Despliegue Completo Automatizado

Usar el Makefile para deployment completo:

```bash
# Ver todos los comandos disponibles
make help

# Despliegue completo (Terraform + Docker build + ECS deploy)
make deploy
```

### Opción 2: Despliegue Manual Paso a Paso

#### **Paso 1: Inicializar Terraform**

```bash
cd terraform
terraform init
```

#### **Paso 2: Revisar Plan de Infraestructura**

```bash
terraform plan
```

Revisa los recursos que se crearán:
- 1 VPC con 4 subnets (2 públicas, 2 privadas)
- 2 NAT Gateways
- 4 VPC Endpoints
- 2 S3 Buckets
- 1 SQS Queue + DLQ
- 1 SNS Topic
- 1 ECR Repository
- 1 ECS Cluster + Service
- Varios IAM Roles y Security Groups

#### **Paso 3: Aplicar Infraestructura**

```bash
terraform apply
```

Escribe `yes` cuando se te solicite confirmación.

⏱️ **Tiempo estimado**: 5-7 minutos

#### **Paso 4: Confirmar Suscripciones SNS**

Después del deploy, recibirás notificaciones de AWS SNS:

**Email:**
```
Subject: AWS Notification - Subscription Confirmation
```
**¡IMPORTANTE!** Haz clic en **"Confirm subscription"** en el email para activar las notificaciones por correo.

**SMS (si configuraste notification_phone):**
Recibirás un mensaje de texto con un enlace de confirmación. Responde según las instrucciones para activar alertas SMS.

#### **Paso 5: Build y Push de Imagen Docker**

```bash
# Obtener URL del repositorio ECR
ECR_URL=$(terraform output -raw ecr_repository_url)

# Login a ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_URL

# Build imagen Docker (desde el root del proyecto)
cd ..
docker build -t s3-antivirus-scanner .

# Tag imagen
docker tag s3-antivirus-scanner:latest $ECR_URL:latest

# Push a ECR
docker push $ECR_URL:latest
```

#### **Paso 6: Forzar Redespliegue de ECS**

```bash
# Volver a terraform/
cd terraform

# Obtener nombre del servicio ECS
ECS_SERVICE=$(terraform output -raw ecs_service_name)
ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)

# Forzar nuevo deployment
aws ecs update-service \
  --cluster $ECS_CLUSTER \
  --service $ECS_SERVICE \
  --force-new-deployment \
  ```

#### **Paso 7: Verificar Deployment**

```bash
# Ver tareas ECS activas
aws ecs list-tasks \
  --cluster $ECS_CLUSTER \
  --service-name $ECS_SERVICE \
  
# Ver logs de CloudWatch
make logs

# O manualmente:
aws logs tail /ecs/s3-antivirus --follow ```

---

## 🐳 Testing Local con Docker

Antes de desplegar a AWS, puedes probar el scanner localmente:

### 1. Construir Imagen

```bash
make docker-build
```

### 2. Ejecutar Contenedor Local

```bash
make docker-run
```

### 3. Probar Escaneo Local

```bash
# Crear archivo de prueba EICAR
make test-eicar-local

# Verificar logs del contenedor
docker logs s3-antivirus-local
```

### 4. Detener Contenedor

```bash
make docker-stop
```

---

## 🦠 Pruebas con EICAR

[EICAR](https://www.eicar.org/download-anti-malware-testfile/) es un archivo de prueba estándar para antivirus (NO es malware real).

### Prueba 1: Archivo CLEAN (Texto Simple)

```bash
# Crear archivo limpio
echo "This is a clean test file" > clean-test.txt

# Subir a S3 (cambiar BUCKET_NAME por el nombre de tu bucket)
BUCKET_NAME=$(cd terraform && terraform output -raw monitored_bucket_name)
aws s3 cp clean-test.txt s3://$BUCKET_NAME/ 
# Verificar tags después de ~30 segundos
aws s3api get-object-tagging \
  --bucket $BUCKET_NAME \
  --key clean-test.txt \
  
# Output esperado:
# {
#   "TagSet": [
#     {"Key": "ScanStatus", "Value": "CLEAN"},
#     {"Key": "ScanDate", "Value": "2024-01-XX..."},
#     {"Key": "FileHash", "Value": "sha256:..."}
#   ]
# }
```

### Prueba 2: Archivo INFECTADO (EICAR)

```bash
# Crear archivo EICAR (firma de prueba estándar)
echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > eicar.txt

# Subir a S3
aws s3 cp eicar.txt s3://$BUCKET_NAME/ 
# Verificar que fue movido a cuarentena después de ~30 segundos
QUARANTINE_BUCKET=$(cd terraform && terraform output -raw quarantine_bucket_name)
aws s3 ls s3://$QUARANTINE_BUCKET/infected/ --recursive 
# Verificar que recibiste email de alerta
```

**Output esperado**:

- ✅ Archivo `eicar.txt` copiado a bucket de cuarentena con path: `infected/YYYY/MM/DD/sha256_eicar.txt`
- ✅ Email de alerta recibido con detalles del malware
- ✅ Logs en CloudWatch indicando "MALWARE DETECTED"

### Comando Automatizado

```bash
# Ejecutar suite completa de pruebas EICAR
make test-eicar
```

---

## 📊 Monitoreo

### Ver Logs en Tiempo Real

```bash
# Logs de CloudWatch (últimos 10 minutos)
make logs

# Logs con filtro
aws logs filter-log-events \
  --log-group-name /ecs/s3-antivirus \
  --filter-pattern "INFECTED" \
  ```

### Métricas en CloudWatch

1. Ir a **AWS Console** → **CloudWatch** → **Metrics**
2. Buscar namespace: `AWS/SQS`, `AWS/ECS`
3. Métricas clave:
   - **SQS ApproximateNumberOfMessagesVisible**: Mensajes pendientes en cola
   - **ECS CPUUtilization**: Uso de CPU de tareas
   - **ECS MemoryUtilization**: Uso de memoria
   - **SQS ApproximateAgeOfOldestMessage**: Edad del mensaje más antiguo

### Alarmas Configuradas

- **DLQ Messages Alarm**: Se activa cuando hay >5 mensajes en Dead Letter Queue
  - Acción: Envía notificación SNS a tu email

---

## 💰 Costos Estimados

Estimación de costos mensuales en `us-east-1` (730 horas/mes):

| Servicio | Configuración | Costo Mensual (USD) |
|----------|---------------|---------------------|
| **ECS Fargate** | 1 task (0.5 vCPU, 1 GB) 24/7 | ~$14.60 |
| **NAT Gateway** | 2 NAT Gateways x 2 AZs | ~$65.70 (+ $0.045/GB data) |
| **VPC Endpoints** | 3 Interface Endpoints | ~$21.90 (+ $0.01/GB) |
| **S3 Storage** | 10 GB almacenamiento | ~$0.23 |
| **SQS** | 1M requests | ~$0.40 |
| **SNS** | 100 emails | ~$0.00 (gratis) |
| **CloudWatch Logs** | 5 GB logs | ~$2.50 |
| **Data Transfer** | 10 GB salida | ~$0.90 |
| **TOTAL ESTIMADO** | | **~$106/mes** |

### Optimización de Costos

1. **Deshabilitar NAT Gateway si no necesitas actualizar firmas ClamAV frecuentemente**:
   ```hcl
   enable_nat_gateway = false
   ```
   Ahorro: ~$66/mes ⚠️ Requiere actualización manual de firmas

2. **Usar regiones más baratas** (ej: `us-east-2`):
   Ahorro: ~10-15%

3. **Auto-scaling agresivo**: Escalar a 0 tareas cuando no hay archivos
   Requiere: Lambda para iniciar tareas bajo demanda

---

## 🔧 Troubleshooting

### Problema: Tareas ECS fallan inmediatamente

**Síntoma**: Tareas ECS se detienen en 1-2 minutos

**Soluciones**:

```bash
# 1. Verificar logs de tareas
make logs

# 2. Verificar que la imagen Docker existe en ECR
aws ecr describe-images --repository-name s3-antivirus-scanner 
# 3. Verificar roles IAM
aws iam get-role --role-name s3-antivirus-ecs-task-role ```

### Problema: No recibo emails de alerta

**Soluciones**:

1. Verificar que confirmaste la suscripción SNS (revisa tu bandeja de spam)
2. Verificar que el topic SNS tiene suscripciones activas:

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn $(cd terraform && terraform output -raw sns_topic_arn) \
  ```

### Problema: Archivo no se escanea

**Diagnóstico**:

```bash
# 1. Verificar mensajes en SQS
aws sqs get-queue-attributes \
  --queue-url $(cd terraform && terraform output -raw sqs_queue_url) \
  --attribute-names All \
  
# 2. Verificar notificaciones S3 están configuradas
BUCKET=$(cd terraform && terraform output -raw monitored_bucket_name)
aws s3api get-bucket-notification-configuration --bucket $BUCKET ```

### Problema: Error "terraform init failed"

**Solución**:

```bash
# Eliminar cache y reinicializar
rm -rf .terraform .terraform.lock.hcl
terraform init
```

---

## 🛠️ Comandos Make Útiles

```bash
make help              # Ver todos los comandos disponibles
make validate          # Validar sintaxis Terraform
make plan              # Ver plan de cambios
make deploy            # Despliegue completo automatizado
make destroy           # Destruir toda la infraestructura
make logs              # Ver logs de CloudWatch
make docker-build      # Construir imagen Docker local
make docker-run        # Ejecutar contenedor local
make test-eicar        # Pruebas con ficheros EICAR
make clean             # Limpiar archivos temporales
```

---

## 🧹 Destruir Infraestructura

⚠️ **ADVERTENCIA**: Esto eliminará TODOS los recursos creados.

```bash
# Usando Make
make destroy

# O manualmente
cd terraform
terraform destroy
```

Escribe `yes` para confirmar.

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una branch (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la branch (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

---

## 📄 Licencia

Este proyecto está licenciado bajo Apache License 2.0 - ver [LICENSE](LICENSE) para detalles.

---

## 👨‍💻 Autor

**Johan Ederlien Luna Bermeo**  
🎓 Máster en Ciberseguridad - Universidad Internacional de La Rioja (UNIR)  
📧 Email: johanluna777@gmail.com  
🔗 LinkedIn: [linkedin.com/in/johanluna](https://www.linkedin.com/in/johan-ederlien-luna-bermeo-b425ab98/)  
🐙 GitHub: [@jl1994](https://github.com/jl1994)

---

## 📚 Referencias

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [ClamAV Documentation](https://docs.clamav.net/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EICAR Test Files](https://www.eicar.org/download-anti-malware-testfile/)

---

**⭐ Si este proyecto te fue útil, considera darle una estrella en GitHub!**
