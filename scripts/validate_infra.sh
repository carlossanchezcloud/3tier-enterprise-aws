#!/bin/bash
# ==============================================================================
# validate_infra.sh — Validacion completa de la infraestructura AWS 3-tier
# Requiere: AWS CLI configurado con credenciales validas
# Uso: bash scripts/validate_infra.sh
# ==============================================================================

set -euo pipefail

REGION="us-east-1"
PASS=0
FAIL=0

ok()   { echo "  ✅  $1"; ((PASS++)); }
fail() { echo "  ❌  $1"; ((FAIL++)); }

check() {
  local label="$1"
  local result="$2"
  local expected="$3"
  if echo "$result" | grep -q "$expected"; then
    ok "$label"
  else
    fail "$label (obtenido: '$result')"
  fi
}

echo ""
echo "========================================"
echo "  Validando infraestructura AWS 3-tier  "
echo "========================================"
echo ""

# ------------------------------------------------------------------------------
# 1. VPC — existe y estado = available
# ------------------------------------------------------------------------------
VPC_STATE=$(aws ec2 describe-vpcs \
  --filters "Name=cidr,Values=10.0.0.0/16" \
  --query "Vpcs[0].State" --output text --region "$REGION" 2>/dev/null || echo "none")
check "1. VPC 10.0.0.0/16 disponible" "$VPC_STATE" "available"

VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=cidr,Values=10.0.0.0/16" \
  --query "Vpcs[0].VpcId" --output text --region "$REGION" 2>/dev/null || echo "")

# ------------------------------------------------------------------------------
# 2-3. Subredes publicas
# ------------------------------------------------------------------------------
for CIDR in "10.0.1.0/24" "10.0.2.0/24"; do
  STATE=$(aws ec2 describe-subnets \
    --filters "Name=cidrBlock,Values=$CIDR" "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[0].State" --output text --region "$REGION" 2>/dev/null || echo "none")
  check "$([ "$CIDR" = "10.0.1.0/24" ] && echo "2" || echo "3"). Subred publica $CIDR" "$STATE" "available"
done

# ------------------------------------------------------------------------------
# 4-5. Subredes privadas Website
# ------------------------------------------------------------------------------
IDX=4
for CIDR in "10.0.11.0/24" "10.0.12.0/24"; do
  STATE=$(aws ec2 describe-subnets \
    --filters "Name=cidrBlock,Values=$CIDR" "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[0].State" --output text --region "$REGION" 2>/dev/null || echo "none")
  check "$IDX. Subred Website $CIDR" "$STATE" "available"
  ((IDX++))
done

# ------------------------------------------------------------------------------
# 6-7. Subredes privadas Backend
# ------------------------------------------------------------------------------
for CIDR in "10.0.21.0/24" "10.0.22.0/24"; do
  STATE=$(aws ec2 describe-subnets \
    --filters "Name=cidrBlock,Values=$CIDR" "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[0].State" --output text --region "$REGION" 2>/dev/null || echo "none")
  check "$IDX. Subred Backend $CIDR" "$STATE" "available"
  ((IDX++))
done

# ------------------------------------------------------------------------------
# 8-9. Subredes DB
# ------------------------------------------------------------------------------
for CIDR in "10.0.31.0/24" "10.0.32.0/24"; do
  STATE=$(aws ec2 describe-subnets \
    --filters "Name=cidrBlock,Values=$CIDR" "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[0].State" --output text --region "$REGION" 2>/dev/null || echo "none")
  check "$IDX. Subred DB $CIDR" "$STATE" "available"
  ((IDX++))
done

# ------------------------------------------------------------------------------
# 10. NAT Instance — running + source_dest_check = false
# ------------------------------------------------------------------------------
NAT_STATE=$(aws ec2 describe-instances \
  --filters "Name=tag:Role,Values=nat" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].State.Name" --output text --region "$REGION" 2>/dev/null || echo "none")
check "10. NAT Instance running" "$NAT_STATE" "running"

NAT_SDC=$(aws ec2 describe-instances \
  --filters "Name=tag:Role,Values=nat" \
  --query "Reservations[0].Instances[0].SourceDestCheck" --output text --region "$REGION" 2>/dev/null || echo "True")
if [ "$NAT_SDC" = "False" ]; then
  ok "10b. NAT Instance source_dest_check=false"
else
  fail "10b. NAT Instance source_dest_check debe ser false (actual: $NAT_SDC)"
fi

# ------------------------------------------------------------------------------
# 11. Security Groups — existen los 6 SGs (flujo capa a capa)
# ------------------------------------------------------------------------------
IDX=11
for SG_NAME in "sg-alb-public" "sg-website" "sg-alb-internal" "sg-backend" "sg-database" "sg-nat"; do
  SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=aws_3tier-$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text --region "$REGION" 2>/dev/null || echo "None")
  if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
    ok "$IDX. SG aws_3tier-$SG_NAME existe ($SG_ID)"
  else
    fail "$IDX. SG aws_3tier-$SG_NAME no encontrado"
  fi
  ((IDX++))
done

# ------------------------------------------------------------------------------
# 15. ALB publico — active, internet-facing
# ------------------------------------------------------------------------------
PUBLIC_ALB=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName,'public-alb')]" \
  --region "$REGION" 2>/dev/null || echo "[]")

ALB_STATE=$(echo "$PUBLIC_ALB" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['State']['Code'] if d else 'none')" 2>/dev/null || echo "none")
ALB_SCHEME=$(echo "$PUBLIC_ALB" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['Scheme'] if d else 'none')" 2>/dev/null || echo "none")
check "15. ALB publico estado=active" "$ALB_STATE" "active"
check "15b. ALB publico scheme=internet-facing" "$ALB_SCHEME" "internet-facing"

PUBLIC_ALB_DNS=$(echo "$PUBLIC_ALB" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['DNSName'] if d else '')" 2>/dev/null || echo "")

# ------------------------------------------------------------------------------
# 16. ALB interno — active, internal
# ------------------------------------------------------------------------------
INTERNAL_ALB=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName,'internal-alb')]" \
  --region "$REGION" 2>/dev/null || echo "[]")

INT_STATE=$(echo "$INTERNAL_ALB" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['State']['Code'] if d else 'none')" 2>/dev/null || echo "none")
INT_SCHEME=$(echo "$INTERNAL_ALB" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['Scheme'] if d else 'none')" 2>/dev/null || echo "none")
check "16. ALB interno estado=active" "$INT_STATE" "active"
check "16b. ALB interno scheme=internal" "$INT_SCHEME" "internal"

# ------------------------------------------------------------------------------
# 17. Target Group Website — minimo 2 targets healthy
# ------------------------------------------------------------------------------
TG_WEBSITE_ARN=$(aws elbv2 describe-target-groups \
  --query "TargetGroups[?contains(TargetGroupName,'website-tg')].TargetGroupArn" \
  --output text --region "$REGION" 2>/dev/null || echo "")

if [ -n "$TG_WEBSITE_ARN" ]; then
  HEALTHY_WEBSITE=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_WEBSITE_ARN" \
    --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
    --output text --region "$REGION" 2>/dev/null || echo "0")
  if [ "$HEALTHY_WEBSITE" -ge 2 ] 2>/dev/null; then
    ok "17. Target Group Website — $HEALTHY_WEBSITE targets healthy"
  else
    fail "17. Target Group Website — solo $HEALTHY_WEBSITE targets healthy (esperado >=2)"
  fi
else
  fail "17. Target Group Website no encontrado"
fi

# ------------------------------------------------------------------------------
# 18. Target Group Backend — minimo 2 targets healthy
# ------------------------------------------------------------------------------
TG_BACKEND_ARN=$(aws elbv2 describe-target-groups \
  --query "TargetGroups[?contains(TargetGroupName,'backend-tg')].TargetGroupArn" \
  --output text --region "$REGION" 2>/dev/null || echo "")

if [ -n "$TG_BACKEND_ARN" ]; then
  HEALTHY_BACKEND=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_BACKEND_ARN" \
    --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
    --output text --region "$REGION" 2>/dev/null || echo "0")
  if [ "$HEALTHY_BACKEND" -ge 2 ] 2>/dev/null; then
    ok "18. Target Group Backend — $HEALTHY_BACKEND targets healthy"
  else
    fail "18. Target Group Backend — solo $HEALTHY_BACKEND targets healthy (esperado >=2)"
  fi
else
  fail "18. Target Group Backend no encontrado"
fi

# ------------------------------------------------------------------------------
# 19. ASG Website — 2 instancias InService
# ------------------------------------------------------------------------------
WEBSITE_INSERVICE=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "aws_3tier-website-asg" \
  --query "length(AutoScalingGroups[0].Instances[?LifecycleState=='InService'])" \
  --output text --region "$REGION" 2>/dev/null || echo "0")
if [ "$WEBSITE_INSERVICE" -ge 2 ] 2>/dev/null; then
  ok "19. ASG Website — $WEBSITE_INSERVICE instancias InService"
else
  fail "19. ASG Website — solo $WEBSITE_INSERVICE instancias InService (esperado >=2)"
fi

# ------------------------------------------------------------------------------
# 20. ASG Backend — 2 instancias InService
# ------------------------------------------------------------------------------
BACKEND_INSERVICE=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "aws_3tier-backend-asg" \
  --query "length(AutoScalingGroups[0].Instances[?LifecycleState=='InService'])" \
  --output text --region "$REGION" 2>/dev/null || echo "0")
if [ "$BACKEND_INSERVICE" -ge 2 ] 2>/dev/null; then
  ok "20. ASG Backend — $BACKEND_INSERVICE instancias InService"
else
  fail "20. ASG Backend — solo $BACKEND_INSERVICE instancias InService (esperado >=2)"
fi

# ------------------------------------------------------------------------------
# 21. EC2 Website — sin IP publica
# ------------------------------------------------------------------------------
WEBSITE_PUBLIC_IPS=$(aws ec2 describe-instances \
  --filters "Name=tag:Role,Values=website" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].PublicIpAddress" \
  --output text --region "$REGION" 2>/dev/null | tr -s '\t\n ' '\n' | grep -v '^$' | grep -v 'None' | wc -l)
if [ "$WEBSITE_PUBLIC_IPS" -eq 0 ] 2>/dev/null; then
  ok "21. EC2 Website — sin IP publica (correcto)"
else
  fail "21. EC2 Website — $WEBSITE_PUBLIC_IPS instancias tienen IP publica (debe ser 0)"
fi

# ------------------------------------------------------------------------------
# 22. EC2 Backend — sin IP publica
# ------------------------------------------------------------------------------
BACKEND_PUBLIC_IPS=$(aws ec2 describe-instances \
  --filters "Name=tag:Role,Values=backend" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].PublicIpAddress" \
  --output text --region "$REGION" 2>/dev/null | tr -s '\t\n ' '\n' | grep -v '^$' | grep -v 'None' | wc -l)
if [ "$BACKEND_PUBLIC_IPS" -eq 0 ] 2>/dev/null; then
  ok "22. EC2 Backend — sin IP publica (correcto)"
else
  fail "22. EC2 Backend — $BACKEND_PUBLIC_IPS instancias tienen IP publica (debe ser 0)"
fi

# ------------------------------------------------------------------------------
# 23. SSM Agent — responde en todas las instancias privadas
# ------------------------------------------------------------------------------
SSM_ONLINE=$(aws ssm describe-instance-information \
  --query "length(InstanceInformationList[?PingStatus=='Online'])" \
  --output text --region "$REGION" 2>/dev/null || echo "0")
if [ "$SSM_ONLINE" -ge 4 ] 2>/dev/null; then
  ok "23. SSM Agent online en $SSM_ONLINE instancias"
else
  fail "23. SSM Agent — solo $SSM_ONLINE instancias online (esperado >=4: 2 website + 2 backend)"
fi

# ------------------------------------------------------------------------------
# 24. RDS — available, mysql, MultiAZ=false, StorageEncrypted=true
# ------------------------------------------------------------------------------
RDS_INFO=$(aws rds describe-db-instances \
  --query "DBInstances[?contains(DBInstanceIdentifier,'aws-3tier')]" \
  --region "$REGION" 2>/dev/null || echo "[]")

RDS_STATUS=$(echo "$RDS_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['DBInstanceStatus'] if d else 'none')" 2>/dev/null || echo "none")
RDS_ENGINE=$(echo "$RDS_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['Engine'] if d else 'none')" 2>/dev/null || echo "none")
RDS_MULTIAZ=$(echo "$RDS_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['MultiAZ'] if d else 'True')" 2>/dev/null || echo "True")
RDS_ENCRYPTED=$(echo "$RDS_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['StorageEncrypted'] if d else 'False')" 2>/dev/null || echo "False")

check "24. RDS estado=available" "$RDS_STATUS" "available"
check "24b. RDS motor=mysql" "$RDS_ENGINE" "mysql"
if [ "$RDS_MULTIAZ" = "False" ]; then
  ok "24c. RDS MultiAZ=false (free tier)"
else
  fail "24c. RDS MultiAZ debe ser false (actual: $RDS_MULTIAZ)"
fi
if [ "$RDS_ENCRYPTED" = "True" ]; then
  ok "24d. RDS StorageEncrypted=true"
else
  fail "24d. RDS StorageEncrypted debe ser true (actual: $RDS_ENCRYPTED)"
fi

# ------------------------------------------------------------------------------
# 25. Health check end-to-end via ALB publico
# ------------------------------------------------------------------------------
if [ -n "$PUBLIC_ALB_DNS" ]; then
  # /health
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 --max-time 15 \
    "http://$PUBLIC_ALB_DNS/health" 2>/dev/null || echo "000")
  check "25. GET /health → 200" "$HTTP_STATUS" "200"

  # /api/servicios → 5 servicios
  API_RESPONSE=$(curl -s --connect-timeout 10 --max-time 15 \
    "http://$PUBLIC_ALB_DNS/api/servicios" 2>/dev/null || echo "[]")
  SERVICE_COUNT=$(echo "$API_RESPONSE" | python3 -c \
    "import sys,json
try:
    d=json.load(sys.stdin)
    print(len(d) if isinstance(d,list) else 0)
except:
    print(0)" 2>/dev/null || echo "0")
  if [ "$SERVICE_COUNT" -ge 5 ] 2>/dev/null; then
    ok "25b. GET /api/servicios → $SERVICE_COUNT servicios"
  else
    fail "25b. GET /api/servicios → $SERVICE_COUNT servicios (esperado >=5)"
  fi
else
  fail "25. No se pudo obtener DNS del ALB publico"
  fail "25b. Health check end-to-end omitido"
fi

# ==============================================================================
# RESUMEN FINAL
# ==============================================================================
TOTAL=$((PASS + FAIL))
echo ""
echo "========================================"
echo "  RESULTADO: $PASS/$TOTAL checks pasaron"
echo "========================================"
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "  🚀 Infraestructura lista para produccion"
else
  echo "  ⚠️  Revisar los items marcados con ❌"
fi
echo ""
