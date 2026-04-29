# ============================================
# Makefile - S3 Antivirus Scanner
# ============================================
# Comandos automatizados para desarrollo, testing y deployment
# ============================================

.PHONY: help init validate plan apply deploy destroy logs docker-build docker-run docker-stop test-eicar test-eicar-local clean

# Variables
PROJECT_NAME := s3-antivirus
DOCKER_IMAGE := $(PROJECT_NAME):latest
DOCKER_CONTAINER := s3-antivirus-local
AWS_REGION := us-east-1
AWS_PROFILE := default

# Colores para output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

## ============================================
## COMANDOS PRINCIPALES
## ============================================

help: ## Mostrar esta ayuda
	@echo "$(BLUE)════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  S3 Antivirus Scanner - Makefile Commands$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BLUE)════════════════════════════════════════════════════$(NC)"

## ============================================
## TERRAFORM COMMANDS
## ============================================

init: ## Inicializar Terraform
	@echo "$(GREEN)Inicializando Terraform...$(NC)"
	@cd terraform && terraform init

validate: ## Validar sintaxis de Terraform
	@echo "$(GREEN)Validando configuración Terraform...$(NC)"
	@cd terraform && terraform validate
	@echo "$(GREEN)✓ Validación exitosa!$(NC)"

plan: validate ## Ver plan de cambios de Terraform
	@echo "$(GREEN)Generando plan de Terraform...$(NC)"
	@cd terraform && terraform plan

apply: validate ## Aplicar cambios de Terraform
	@echo "$(YELLOW)⚠️  Aplicando cambios de Terraform...$(NC)"
	@cd terraform && terraform apply
	@echo "$(GREEN)✓ Infraestructura desplegada!$(NC)"
	@echo "$(YELLOW)⚠️  IMPORTANTE: Revisa tu email y confirma la suscripción SNS$(NC)"

## ============================================
## DOCKER COMMANDS
## ============================================

docker-build: ## Construir imagen Docker localmente
	@echo "$(GREEN)Construyendo imagen Docker (linux/amd64)...$(NC)"
	@docker buildx build --platform linux/amd64 -t $(DOCKER_IMAGE) .
	@echo "$(GREEN)✓ Imagen construida: $(DOCKER_IMAGE)$(NC)"

docker-run: docker-build ## Ejecutar contenedor localmente
	@echo "$(GREEN)Ejecutando contenedor Docker...$(NC)"
	@docker run -d \
		--name $(DOCKER_CONTAINER) \
		-e AWS_REGION=$(AWS_REGION) \
		-e LOG_LEVEL=DEBUG \
		$(DOCKER_IMAGE)
	@echo "$(GREEN)✓ Contenedor ejecutándose: $(DOCKER_CONTAINER)$(NC)"
	@echo "$(YELLOW)Ver logs: docker logs -f $(DOCKER_CONTAINER)$(NC)"

docker-stop: ## Detener y eliminar contenedor local
	@echo "$(YELLOW)Deteniendo contenedor...$(NC)"
	@docker stop $(DOCKER_CONTAINER) 2>/dev/null || true
	@docker rm $(DOCKER_CONTAINER) 2>/dev/null || true
	@echo "$(GREEN)✓ Contenedor detenido$(NC)"

docker-logs: ## Ver logs del contenedor local
	@docker logs -f $(DOCKER_CONTAINER)

## ============================================
## DEPLOYMENT COMPLETO
## ============================================

deploy: validate ## Despliegue completo (Terraform + Docker + ECS)
	@echo "$(BLUE)════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  INICIANDO DESPLIEGUE COMPLETO$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(GREEN)[0/6] Inicializando providers Terraform...$(NC)"
	@cd terraform && terraform init -upgrade
	@echo ""
	@echo "$(GREEN)[1/6] Aplicando infraestructura Terraform...$(NC)"
	@cd terraform && terraform apply -auto-approve
	@echo ""
	@echo "$(GREEN)[2/6] Obteniendo URL del repositorio ECR...$(NC)"
	@set -e; \
	ECR_URL=$$(cd terraform && terraform output -raw ecr_repository_url); \
	echo "$(YELLOW)ECR URL: $$ECR_URL$(NC)"; \
	echo ""; \
	echo "$(GREEN)[3/6] Login a ECR...$(NC)"; \
	aws ecr get-login-password --region $(AWS_REGION) --profile $(AWS_PROFILE) | \
		docker login --username AWS --password-stdin $$ECR_URL; \
	echo ""; \
	echo "$(GREEN)[4/6] Construyendo imagen Docker (linux/amd64)...$(NC)"; \
	docker buildx build --platform linux/amd64 -t $(PROJECT_NAME) .; \
	echo ""; \
	echo "$(GREEN)[5/6] Pushing imagen a ECR...$(NC)"; \
	docker tag $(PROJECT_NAME):latest $$ECR_URL:latest; \
	docker push $$ECR_URL:latest; \
	echo ""; \
	echo "$(GREEN)[6/6] Forzando redespliegue de ECS...$(NC)"; \
	ECS_CLUSTER=$$(cd terraform && terraform output -raw ecs_cluster_name); \
	ECS_SERVICE=$$(cd terraform && terraform output -raw ecs_service_name); \
	aws ecs update-service \
		--cluster $$ECS_CLUSTER \
		--service $$ECS_SERVICE \
		--force-new-deployment \
		--profile $(AWS_PROFILE) > /dev/null; \
	echo ""; \
	echo "$(BLUE)════════════════════════════════════════════════════$(NC)"; \
	echo "$(GREEN)✓ DESPLIEGUE COMPLETADO EXITOSAMENTE!$(NC)"; \
	echo "$(BLUE)════════════════════════════════════════════════════$(NC)"; \
	echo ""; \
	echo "$(YELLOW)⚠️  IMPORTANTE:$(NC)"; \
	echo "  1. Revisa tu email y confirma la suscripción SNS"; \
	echo "  2. Espera ~2 minutos para que ECS inicie las tareas"; \
	echo "  3. Verifica logs: make logs"; \
	echo "  4. Ejecuta pruebas: make test-eicar"; \
	echo ""

## ============================================
## MONITORING
## ============================================

logs: ## Ver logs de CloudWatch en tiempo real
	@echo "$(GREEN)Mostrando logs de CloudWatch (Ctrl+C para salir)...$(NC)"
	$(eval LOG_GROUP := $(shell cd terraform && terraform output -raw cloudwatch_log_group))
	@aws logs tail $(LOG_GROUP) --follow --profile $(AWS_PROFILE)

status: ## Ver estado del servicio ECS
	@echo "$(GREEN)Estado del servicio ECS:$(NC)"
	$(eval ECS_CLUSTER := $(shell cd terraform && terraform output -raw ecs_cluster_name))
	$(eval ECS_SERVICE := $(shell cd terraform && terraform output -raw ecs_service_name))
	@aws ecs describe-services \
		--cluster $(ECS_CLUSTER) \
		--services $(ECS_SERVICE) \
		--profile $(AWS_PROFILE) \
		--query 'services[0].{Status:status,DesiredCount:desiredCount,RunningCount:runningCount,PendingCount:pendingCount}' \
		--output table

tasks: ## Listar tareas ECS activas
	@echo "$(GREEN)Tareas ECS activas:$(NC)"
	$(eval ECS_CLUSTER := $(shell cd terraform && terraform output -raw ecs_cluster_name))
	@aws ecs list-tasks --cluster $(ECS_CLUSTER) --profile $(AWS_PROFILE)

## ============================================
## TESTING
## ============================================

test-eicar-local: ## Probar escaneo EICAR localmente
	@echo "$(GREEN)Creando archivo de prueba EICAR...$(NC)"
	@echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$$H+H*' > /tmp/eicar.txt
	@echo "$(GREEN)Copiando archivo al contenedor...$(NC)"
	@docker cp /tmp/eicar.txt $(DOCKER_CONTAINER):/tmp/eicar.txt
	@echo "$(GREEN)Ejecutando escaneo...$(NC)"
	@docker exec $(DOCKER_CONTAINER) clamscan /tmp/eicar.txt
	@rm /tmp/eicar.txt

test-eicar: ## Probar escaneo EICAR en AWS
	@echo "$(GREEN)Ejecutando pruebas EICAR en AWS...$(NC)"
	@echo ""
	
	$(eval BUCKET := $(shell cd terraform && terraform output -raw monitored_bucket_name))
	$(eval QUARANTINE := $(shell cd terraform && terraform output -raw quarantine_bucket_name))
	
	@echo "$(YELLOW)[TEST 1] Archivo LIMPIO$(NC)"
	@echo "Este es un archivo de prueba limpio" > /tmp/clean-test.txt
	@aws s3 cp /tmp/clean-test.txt s3://$(BUCKET)/ --profile $(AWS_PROFILE)
	@echo "$(GREEN)✓ Archivo limpio subido a S3$(NC)"
	@echo "  Espera 30 segundos y verifica tags con:"
	@echo "  aws s3api get-object-tagging --bucket $(BUCKET) --key clean-test.txt"
	@echo ""
	
	@echo "$(YELLOW)[TEST 2] Archivo INFECTADO (EICAR)$(NC)"
	@echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$$H+H*' > /tmp/eicar-test.txt
	@aws s3 cp /tmp/eicar-test.txt s3://$(BUCKET)/ --profile $(AWS_PROFILE)
	@echo "$(GREEN)✓ Archivo EICAR subido a S3$(NC)"
	@echo "  Espera 30 segundos y verifica cuarentena con:"
	@echo "  aws s3 ls s3://$(QUARANTINE)/infected/ --recursive"
	@echo ""
	
	@rm /tmp/clean-test.txt /tmp/eicar-test.txt
	@echo "$(BLUE)════════════════════════════════════════════════════$(NC)"
	@echo "$(YELLOW)⚠️  Espera ~30-60 segundos para que se procesen los archivos$(NC)"
	@echo "$(YELLOW)⚠️  Deberías recibir un email de alerta por el archivo EICAR$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════$(NC)"

## ============================================
## UPLOAD & SCALING TESTS
## ============================================

upload-file: ## Subir un fichero al bucket (FILE=ruta, KEY=destino opcional)
	$(eval BUCKET := $(shell cd terraform && terraform output -raw monitored_bucket_name))
	$(eval KEY := $(if $(KEY),$(KEY),upload/$(notdir $(FILE))))
	@aws s3 cp $(FILE) s3://$(BUCKET)/$(KEY) --profile $(AWS_PROFILE)
	@echo "$(GREEN)✓ Subido: s3://$(BUCKET)/$(KEY)$(NC)"

upload-clean: ## Subir archivo limpio de prueba
	$(eval BUCKET := $(shell cd terraform && terraform output -raw monitored_bucket_name))
	@echo "Archivo limpio TFM Johan Luna" > /tmp/clean-demo.txt
	@aws s3 cp /tmp/clean-demo.txt s3://$(BUCKET)/demo/clean-demo.txt --profile $(AWS_PROFILE)
	@echo "$(GREEN)✓ Archivo limpio subido$(NC)"
	@echo "  Verifica en ~30s: aws s3api get-object-tagging --bucket $(BUCKET) --key demo/clean-demo.txt"

upload-eicar: ## Subir archivo EICAR infectado de prueba
	$(eval BUCKET := $(shell cd terraform && terraform output -raw monitored_bucket_name))
	$(eval QUARANTINE := $(shell cd terraform && terraform output -raw quarantine_bucket_name))
	@printf 'X5O!P%%@AP[4\PZX54(P^)7CC)7}$$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$$H+H*' > /tmp/eicar-demo.exe
	@aws s3 cp /tmp/eicar-demo.exe s3://$(BUCKET)/demo/eicar-demo.exe --profile $(AWS_PROFILE)
	@echo "$(GREEN)✓ EICAR subido$(NC)"
	@echo "  Verifica tags en ~30s:"
	@echo "  aws s3api get-object-tagging --bucket $(BUCKET) --key demo/eicar-demo.exe"
	@echo "  Verifica cuarentena en ~30s:"
	@echo "  aws s3 ls s3://$(QUARANTINE)/ --recursive"

scale-test: ## Prueba de carga para disparar autoscaling (sube COUNT=25 ficheros EICAR)
	@echo "$(BLUE)════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  INICIANDO PRUEBA DE ESCALADO$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════$(NC)"
	@bash scripts/scale_test.sh $(if $(COUNT),$(COUNT),25)

watch-scale: ## Monitorear escalado ECS en tiempo real (Ctrl+C para salir)
	@echo "$(GREEN)Monitoreando escalado ECS (Ctrl+C para salir)...$(NC)"
	@echo "$(YELLOW)Target: >10 msgs en SQS dispara scale-out. Cooldown scale-in: 300s$(NC)"
	@echo ""
	@bash scripts/watch_scale.sh

## ============================================
## CLEANUP
## ============================================

empty-buckets: ## Vaciar los buckets S3 (necesario antes de destroy)
	$(eval BUCKET := $(shell cd terraform && terraform output -raw monitored_bucket_name))
	$(eval QUARANTINE := $(shell cd terraform && terraform output -raw quarantine_bucket_name))
	@echo "$(YELLOW)Vaciando bucket uploads...$(NC)"
	@aws s3 rm s3://$(BUCKET) --recursive --profile $(AWS_PROFILE)
	@echo "$(YELLOW)Vaciando bucket cuarentena...$(NC)"
	@aws s3 rm s3://$(QUARANTINE) --recursive --profile $(AWS_PROFILE)
	@echo "$(GREEN)✓ Buckets vaciados$(NC)"

destroy: empty-buckets ## Destruir toda la infraestructura (vacía buckets + terraform destroy)
	@echo "$(RED)⚠️  ADVERTENCIA: Esto eliminará TODA la infraestructura$(NC)"
	@echo "$(RED)⚠️  Presiona Ctrl+C para cancelar, Enter para continuar...$(NC)"
	@read -p ""
	@cd terraform && terraform destroy -auto-approve
	@echo "$(GREEN)✓ Infraestructura destruida$(NC)"
	@echo ""
	@echo "$(YELLOW)Verificando NAT Gateway (puede tardar 1 min en eliminar)...$(NC)"
	@aws ec2 describe-nat-gateways \
		--filter "Name=tag:Project,Values=s3-antivirus-tfm" \
		--region $(AWS_REGION) \
		--query 'NatGateways[?State!=`deleted`].[NatGatewayId,State]' \
		--output table --profile $(AWS_PROFILE) 2>/dev/null || true
	@echo "$(GREEN)Tabla vacía = NAT Gateway eliminado correctamente$(NC)"

clean: ## Limpiar archivos temporales
	@echo "$(GREEN)Limpiando archivos temporales...$(NC)"
	@rm -rf .terraform terraform/.terraform
	@rm -f terraform/.terraform.lock.hcl
	@rm -f /tmp/clean-test.txt /tmp/eicar*.txt
	@docker rmi $(DOCKER_IMAGE) 2>/dev/null || true
	@echo "$(GREEN)✓ Archivos temporales eliminados$(NC)"

## ============================================
## OUTPUTS
## ============================================

outputs: ## Mostrar outputs de Terraform
	@cd terraform && terraform output

urls: ## Mostrar URLs importantes
	@echo "$(BLUE)════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  URLs y Recursos Importantes$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Monitored Bucket:$(NC)"
	@cd terraform && terraform output monitored_bucket_name
	@echo ""
	@echo "$(YELLOW)Quarantine Bucket:$(NC)"
	@cd terraform && terraform output quarantine_bucket_name
	@echo ""
	@echo "$(YELLOW)ECR Repository:$(NC)"
	@cd terraform && terraform output ecr_repository_url
	@echo ""
	@echo "$(YELLOW)ECS Cluster:$(NC)"
	@cd terraform && terraform output ecs_cluster_name
	@echo ""
	@echo "$(YELLOW)SQS Queue URL:$(NC)"
	@cd terraform && terraform output sqs_queue_url
	@echo ""

## ============================================
## DOCUMENTATION
## ============================================

docs: ## Generar documentación de Terraform
	@echo "$(GREEN)Generando documentación de módulos Terraform...$(NC)"
	@cd terraform && terraform-docs markdown . > TERRAFORM.md
	@echo "$(GREEN)✓ Documentación generada en terraform/TERRAFORM.md$(NC)"
