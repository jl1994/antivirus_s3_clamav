#!/usr/bin/env bash
# Monitoreo en tiempo real de SQS + ECS scaling
# Uso: bash scripts/watch_scale.sh

REGION="us-east-1"
CLUSTER=$(terraform -chdir=terraform output -raw ecs_cluster_name 2>/dev/null)
SERVICE=$(terraform -chdir=terraform output -raw ecs_service_name 2>/dev/null)
QUEUE_URL=$(terraform -chdir=terraform output -raw sqs_queue_url 2>/dev/null)

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Monitoreando — Ctrl+C para salir${NC}"
echo -e "${YELLOW}$(printf '%-8s | %-10s | %-10s | %-10s | %-10s' 'Hora' 'SQS Msgs' 'Running' 'Desired' 'Pending')${NC}"
echo "---------|------------|------------|------------|------------"

while true; do
  MSGS=$(aws sqs get-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
    --region "$REGION" \
    --query 'Attributes' --output json 2>/dev/null)

  VISIBLE=$(echo "$MSGS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('ApproximateNumberOfMessages','?'))" 2>/dev/null || echo "?")
  IN_FLIGHT=$(echo "$MSGS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('ApproximateNumberOfMessagesNotVisible','?'))" 2>/dev/null || echo "?")

  SVC=$(aws ecs describe-services \
    --cluster "$CLUSTER" --services "$SERVICE" \
    --region "$REGION" \
    --query 'services[0].{r:runningCount,d:desiredCount,p:pendingCount}' \
    --output json 2>/dev/null)

  RUNNING=$(echo "$SVC" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['r'])" 2>/dev/null || echo "?")
  DESIRED=$(echo "$SVC" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['d'])" 2>/dev/null || echo "?")
  PENDING=$(echo "$SVC" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['p'])" 2>/dev/null || echo "?")

  COLOR=$NC
  [ "$RUNNING" != "?" ] && [ "$RUNNING" -gt 1 ] 2>/dev/null && COLOR=$GREEN
  [ "$VISIBLE" != "?" ] && [ "$VISIBLE" -gt 10 ] 2>/dev/null && COLOR=$YELLOW

  HORA=$(date '+%H:%M:%S')
  printf "${COLOR}%-8s | %-6s(+%-3s) | %-10s | %-10s | %-10s${NC}\n" \
    "$HORA" "$VISIBLE" "$IN_FLIGHT" "$RUNNING" "$DESIRED" "$PENDING"

  sleep 10
done
