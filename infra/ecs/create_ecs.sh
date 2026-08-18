#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

CLUSTER_NAME="taller-cluster"
TASK_DEF_FAMILY="taller-task"
SERVICE_NAME="taller-service"
IMAGE_NAME="${REPO_NAME:-itba_cloud_architecture_fp-taller-backend}:latest"

echo "Configurando Amazon ECS..."

# --- DETECCIÓN DE ENTORNO LOCAL ---
if [[ "$ENDPOINT" == *"localhost:4566"* ]] || [[ "$ENDPOINT" == *"127.0.0.1:4566"* ]]; then
    echo "⚠️ Entorno local detectado. Configurando mock integrado con LocalStack y Postgres..."

    # 1. Recuperar la contraseña guardada en Secrets Manager (LocalStack)
    echo "🔑 Recuperando secreto desde LocalStack..."
    DB_PASS=$(aws secretsmanager get-secret-value \
      --secret-id "$DB_SECRET_NAME" \
      --endpoint-url "$ENDPOINT" \
      --region "$REGION" \
      --query 'SecretString' \
      --output text | python3 -c "import sys, json; print(json.load(sys.stdin).get('password', 'postgres'))" 2>/dev/null || echo "postgres")

    # 2. Identificar la red de Docker (donde viven Postgres y LocalStack)
    NETWORK=$(docker network ls --format "{{.Name}}" | grep "default" | grep -i "itba" | head -n 1)
    [ -z "$NETWORK" ] && NETWORK="bridge"

    # 3. Limpiar contenedor anterior si ya existía
    docker rm -f taller-backend-local 2>/dev/null || true

    # 4. Levantar contenedor inyectando variables (simulación de roles y secrets)
    echo "Levantando contenedor Docker 'taller-backend-local' en la red '$NETWORK'..."
    docker run -d \
      --name taller-backend-local \
      --network "$NETWORK" \
      -e POSTGRES_HOST="postgres" \
      -e POSTGRES_PORT="5432" \
      -e POSTGRES_DB="${POSTGRES_DB:-appdb}" \
      -e POSTGRES_USER="${POSTGRES_USER:-postgres}" \
      -e POSTGRES_PASSWORD="$DB_PASS" \
      -e AWS_ENDPOINT_URL="http://cloud-foundations-localstack:4566" \
      -e AWS_DEFAULT_REGION="$REGION" \
      -e AWS_ACCESS_KEY_ID="test" \
      -e AWS_SECRET_ACCESS_KEY="test" \
      -e S3_BACKEND_BUCKET="${S3_BACKEND_BUCKET:-taller-backend-storage}" \
      "$IMAGE_NAME" > /dev/null

    echo "========================================="
    echo "✅ ECS (Simulado): Contenedor integrado y ejecutándose correctamente"
    echo "========================================="
    exit 0
fi
# ----------------------------------

echo "Usando ECS en AWS Real..."

# 1. Recuperar IDs de infraestructura
PRIVATE_SUBNET_1=$(get_subnet_id "taller-private-subnet-1")
PRIVATE_SUBNET_2=$(get_subnet_id "taller-private-subnet-2")
ECS_SG=$(get_sg_id "taller-ecs-sg")
TG_ARN=$(aws elbv2 describe-target-groups --names "taller-tg" --region "$REGION" --endpoint-url "$ENDPOINT" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "None")
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --region "$REGION" --endpoint-url "$ENDPOINT")

if [ -z "$PRIVATE_SUBNET_1" ] || [ "$PRIVATE_SUBNET_1" == "None" ] || [ "$TG_ARN" == "None" ]; then
    echo "❌ ERROR: Faltan recursos base (Subredes privadas o Target Group del ALB)."
    exit 1
fi

# 2. Registrar Task Definition (Con IAM Roles, Secrets y Logs)
echo "📄 Registrando Task Definition '$TASK_DEF_FAMILY'..."
CONTAINER_DEF=$(cat <<EOF
[
  {
    "name": "$REPO_NAME",
    "image": "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$IMAGE_NAME",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 8000,
        "hostPort": 8000,
        "protocol": "tcp"
      }
    ],
    "secrets": [
      {
        "name": "DB_CREDENTIALS",
        "valueFrom": "arn:aws:secretsmanager:$REGION:$ACCOUNT_ID:secret:$DB_SECRET_NAME"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/taller-backend",
        "awslogs-region": "$REGION",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
EOF
)

aws ecs register-task-definition \
  --family "$TASK_DEF_FAMILY" \
  --network-mode "awsvpc" \
  --requires-compatibilities "FARGATE" \
  --cpu "256" \
  --memory "512" \
  --execution-role-arn "arn:aws:iam::${ACCOUNT_ID}:role/taller-ecs-execution-role" \
  --task-role-arn "arn:aws:iam::${ACCOUNT_ID}:role/taller-ecs-task-role" \
  --container-definitions "$CONTAINER_DEF" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" > /dev/null

# 3. Crear Cluster y Servicio de ECS conectado al ALB
echo "🏗️ Creando Cluster ECS '$CLUSTER_NAME'..."
aws ecs create-cluster --cluster-name "$CLUSTER_NAME" --region "$REGION" --endpoint-url "$ENDPOINT" > /dev/null

echo "🚀 Creando o Actualizando Servicio ECS '$SERVICE_NAME'..."
aws ecs create-service \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --task-definition "$TASK_DEF_FAMILY" \
  --desired-count 2 \
  --launch-type "FARGATE" \
  --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=$TG_ARN,containerName=$REPO_NAME,containerPort=8000" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" > /dev/null || echo "ℹ️ El servicio ECS ya existía o se está actualizando."

echo "========================================="
echo "✅ Amazon ECS configurado exitosamente en AWS"
echo "========================================="