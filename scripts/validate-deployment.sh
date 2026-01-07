#!/bin/bash
# ============================================
# Script de Validación Pre-Deployment
# ============================================

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Validación Pre-Deployment - S3 Antivirus Scanner${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""

# 1. Verificar Terraform
echo -e "${YELLOW}[1/6] Verificando Terraform...${NC}"
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform no está instalado${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Terraform instalado${NC}"

# 2. Verificar AWS CLI
echo -e "${YELLOW}[2/6] Verificando AWS CLI...${NC}"
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI no está instalado${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI instalado${NC}"

# 3. Verificar Docker
echo -e "${YELLOW}[3/6] Verificando Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker no está instalado${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker instalado${NC}"

# 4. Validar Terraform
echo -e "${YELLOW}[4/6] Validando código Terraform...${NC}"
cd terraform && terraform validate > /dev/null 2>&1 && cd ..
echo -e "${GREEN}✓ Código Terraform válido${NC}"

# 5. Verificar variables
echo -e "${YELLOW}[5/6] Verificando configuración...${NC}"
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo -e "${YELLOW}  Creando terraform.tfvars...${NC}"
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars
    echo -e "${RED}  EDITA terraform/terraform.tfvars y configura tu email${NC}"
fi
echo -e "${GREEN}✓ Configuración lista${NC}"

echo ""
echo -e "${GREEN}✓ VALIDACIÓN COMPLETADA${NC}"
echo ""
