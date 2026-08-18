#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

CLUSTER_NAME="taller-cluster"
SERVICE_NAME="taller-service"
MIN_CAPACITY="${ECS_MIN_CAPACITY:-2}"
MAX_CAPACITY="${ECS_MAX_CAPACITY:-10}"
CPU_TARGET="${ECS_CPU_TARGET:-70}"
SCALE_OUT_COOLDOWN="${ECS_SCALE_OUT_COOLDOWN:-60}"
SCALE_IN_COOLDOWN="${ECS_SCALE_IN_COOLDOWN:-300}"

if [[ "$ENDPOINT" == *"localhost:4566"* ]] || [[ "$ENDPOINT" == *"127.0.0.1:4566"* ]]; then
    echo "ADVERTENCIA: Entorno local detectado. Auto Scaling se simula porque LocalStack no ejecuta Application Auto Scaling."
    echo "OK: Objetivo simulado: $MIN_CAPACITY-$MAX_CAPACITY tareas, CPU objetivo $CPU_TARGET%."
    exit 0
fi

echo "Configurando Auto Scaling para el servicio ECS '$SERVICE_NAME'..."

RESOURCE_ID="service/$CLUSTER_NAME/$SERVICE_NAME"

aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id "$RESOURCE_ID" \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity "$MIN_CAPACITY" \
  --max-capacity "$MAX_CAPACITY" \
  --region "$REGION"

echo "Aplicando política de escalado por CPU ($CPU_TARGET%)..."

SCALING_POLICY_ARN=$(aws application-autoscaling put-scaling-policy \
  --policy-name "taller-ecs-cpu-scaling" \
  --service-namespace ecs \
  --resource-id "$RESOURCE_ID" \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration "TargetValue=$CPU_TARGET,PredefinedMetricSpecification={PredefinedMetricType=ECSServiceAverageCPUUtilization},ScaleOutCooldown=$SCALE_OUT_COOLDOWN,ScaleInCooldown=$SCALE_IN_COOLDOWN" \
  --region "$REGION" \
  --query 'PolicyARN' \
  --output text)

echo "OK: Auto Scaling configurado correctamente."
echo "Política: $SCALING_POLICY_ARN"
echo "Capacidad: mínimo $MIN_CAPACITY, máximo $MAX_CAPACITY tareas."
