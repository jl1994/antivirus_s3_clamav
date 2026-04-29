#!/usr/bin/env bash
# Prueba de carga para disparar autoscaling ECS
# Uso: bash scripts/scale_test.sh [COUNT]
# COUNT: número de ficheros a subir (default 25)

set -euo pipefail

COUNT=${1:-25}
REGION="us-east-1"
BUCKET=$(terraform -chdir=terraform output -raw monitored_bucket_name)
CLUSTER=$(terraform -chdir=terraform output -raw ecs_cluster_name)
SERVICE=$(terraform -chdir=terraform output -raw ecs_service_name)
QUEUE_URL=$(terraform -chdir=terraform output -raw sqs_queue_url)

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  SCALE TEST — subiendo $COUNT ficheros EICAR${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Bucket : $BUCKET${NC}"
echo -e "${YELLOW}Cluster: $CLUSTER${NC}"
echo -e "${YELLOW}Target autoscaling: >10 msgs en SQS${NC}"
echo ""

# Estado inicial
INITIAL_TASKS=$(aws ecs describe-services \
  --cluster "$CLUSTER" --services "$SERVICE" \
  --region "$REGION" \
  --query 'services[0].runningCount' --output text)
echo -e "Tareas ECS antes del test: ${GREEN}$INITIAL_TASKS${NC}"
echo ""

# Generar y subir ficheros en paralelo
echo -e "${YELLOW}Subiendo $COUNT ficheros EICAR en paralelo...${NC}"
TIMESTAMP=$(date +%s)
PIDS=()

for i in $(seq 1 "$COUNT"); do
  (
    FILE="/tmp/eicar_scale_${TIMESTAMP}_${i}.exe"
    printf 'X5O!P%%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "$FILE"
    aws s3 cp "$FILE" "s3://$BUCKET/scale-test/${TIMESTAMP}/eicar_${i}.exe" \
      --region "$REGION" --quiet
    rm -f "$FILE"
    echo -ne "."
  ) &
  PIDS+=($!)
done

# Esperar que todos terminen
for pid in "${PIDS[@]}"; do wait "$pid"; done
echo ""
echo -e "${GREEN}✓ $COUNT ficheros subidos${NC}"
echo ""

# Monitorear cola SQS y escalado durante 3 minutos
echo -e "${BLUE}Monitoreando SQS y ECS (3 min)...${NC}"
echo -e "${YELLOW}Tiempo  | Msgs SQS | Tareas ECS${NC}"
echo "--------|----------|------------"

MAX_TASKS=1
for i in $(seq 1 18); do
  MSGS=$(aws sqs get-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --attribute-names ApproximateNumberOfMessages \
    --region "$REGION" \
    --query 'Attributes.ApproximateNumberOfMessages' \
    --output text 2>/dev/null || echo "?")

  TASKS=$(aws ecs describe-services \
    --cluster "$CLUSTER" --services "$SERVICE" \
    --region "$REGION" \
    --query 'services[0].{r:runningCount,d:desiredCount}' \
    --output text 2>/dev/null | awk '{print $2"running/"$1"desired"}')

  RUNNING=$(aws ecs describe-services \
    --cluster "$CLUSTER" --services "$SERVICE" \
    --region "$REGION" \
    --query 'services[0].runningCount' --output text 2>/dev/null || echo "0")

  [ "$RUNNING" -gt "$MAX_TASKS" ] && MAX_TASKS=$RUNNING

  ELAPSED=$((i * 10))
  printf "  %3ds   |    %4s    |  %s\n" "$ELAPSED" "$MSGS" "$TASKS"
  sleep 10
done

echo ""
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  RESULTADO DEL SCALE TEST${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "Ficheros subidos  : ${GREEN}$COUNT${NC}"
echo -e "Tareas iniciales  : ${YELLOW}$INITIAL_TASKS${NC}"
echo -e "Tareas máximas    : ${GREEN}$MAX_TASKS${NC}"

if [ "$MAX_TASKS" -gt "$INITIAL_TASKS" ]; then
  echo -e "${GREEN}✅ AUTOSCALING FUNCIONÓ — escaló de $INITIAL_TASKS a $MAX_TASKS tareas${NC}"
else
  echo -e "${YELLOW}⚠️  No escaló aún — puede tomar más tiempo (cooldown 60s + arranque ~2min)${NC}"
  echo -e "${YELLOW}   Ejecuta 'make watch-scale' para seguir monitoreando${NC}"
fi
echo -e "${BLUE}════════════════════════════════════════════${NC}"
