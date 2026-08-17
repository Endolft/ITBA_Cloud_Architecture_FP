#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

ALB_NAME="taller-alb"
TG_NAME="taller-tg"

echo "Configurando Application Load Balancer (ALB)..."

# 1. Recuperar IDs de recursos base (VPC, Subredes Públicas y SG)
VPC_ID=$(get_vpc_id)
SUBNET_1=$(get_subnet_id "taller-public-subnet-1")
SUBNET_2=$(get_subnet_id "taller-public-subnet-2")
ALB_SG=$(get_sg_id "taller-alb-sg")

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "❌ ERROR: No se encontró la VPC. Ejecutá la red primero."
    exit 1
fi

# 2. Obtener o Crear el Target Group (Apunta al puerto 8000 de ECS)
TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_NAME" --endpoint-url $ENDPOINT --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "None")

if [ "$TG_ARN" == "None" ] || [ -z "$TG_ARN" ]; then
    echo "🎯 Creando Target Group '$TG_NAME'..."
    TG_ARN=$(aws elbv2 create-target-group \
      --name "$TG_NAME" \
      --protocol HTTP \
      --port 8000 \
      --vpc-id $VPC_ID \
      --health-check-path "/" \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'TargetGroups[0].TargetGroupArn' --output text)
else
    echo "Target Group ya existe: $TG_ARN"
fi

# 3. Obtener o Crear el Application Load Balancer
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --endpoint-url $ENDPOINT --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "None")

if [ "$ALB_ARN" == "None" ] || [ -z "$ALB_ARN" ]; then
    echo "Creando Load Balancer '$ALB_NAME' (Internet-facing)..."
    ALB_ARN=$(aws elbv2 create-load-balancer \
      --name "$ALB_NAME" \
      --subnets $SUBNET_1 $SUBNET_2 \
      --security-groups $ALB_SG \
      --scheme internet-facing \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'LoadBalancers[0].LoadBalancerArn' --output text)
else
    echo "Load Balancer ya existe: $ALB_ARN"
fi

# 4. Obtener o Crear el Listener (Escucha en puerto 80)
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --endpoint-url $ENDPOINT --query 'Listeners[?Port==`80`].ListenerArn' --output text 2>/dev/null || echo "None")

if [ "$LISTENER_ARN" == "None" ] || [ -z "$LISTENER_ARN" ]; then
    echo "Configurando Listener en puerto 80..."
    LISTENER_ARN=$(aws elbv2 create-listener \
      --load-balancer-arn $ALB_ARN \
      --protocol HTTP \
      --port 80 \
      --default-actions Type=forward,TargetGroupArn=$TG_ARN \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'Listeners[0].ListenerArn' --output text)
    echo "✅ Listener creado."
else
    echo "Listener ya existe."
fi

# Obtener URL del Load Balancer
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --endpoint-url $ENDPOINT --query 'LoadBalancers[0].DNSName' --output text)

echo "========================================="
echo "✅ ALB Configurado Exitosamente"
echo "👉 DNS del Balanceador: http://$ALB_DNS"
echo "========================================="