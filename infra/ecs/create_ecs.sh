#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

CLUSTER_NAME="taller-cluster"
TASK_DEF_FAMILY="taller-task"
SERVICE_NAME="taller-service"

echo "Configurando Amazon ECS..."

# --- DETECCIÓN DE ENTORNO LOCAL ---
if [[ "$ENDPOINT" == *"localhost:4566"* ]] || [[ "$ENDPOINT" == *"127.0.0.1:4566"* ]]; then
    echo "⚠️  La ejecución real de contenedores ECS requiere LocalStack Pro."
    echo "Para desarrollo local, levantamos el contenedor aislado en Docker (emulando la VPC)..."
    
    # Buscar la red del docker-compose actual
    NETWORK=$(docker network ls --format "{{.Name}}" | grep "default" | grep -i "itba" | head -n 1)
    if [ -z "$NETWORK" ]; then
        NETWORK="bridge"
    fi

    # Limpiar contenedor anterior si existe
    docker rm -f taller-backend-local 2>/dev/null || true

    # Levantar contenedor localmente simulando ser la Task de ECS
    # No exponemos puertos al host, Caddy actúa como ALB público
    docker run -d \
      --name taller-backend-local \
      --network "$NETWORK" \
      "$REPO_NAME:latest" > /dev/null

    echo "========================================="
    echo "✅ ECS (Simulado): Contenedor corriendo en red privada."
    echo "Caddy (ALB Mock) está ruteando el tráfico en el puerto 80."
    echo "========================================="
    exit 0
fi
# ----------------------------------

echo "Usando ECS en AWS..."

# 1. Recuperar IDs de recursos requeridos
PRIVATE_SUBNET_1=$(get_subnet_id "taller-private-subnet-1")
PRIVATE_SUBNET_2=$(get_subnet_id "taller-private-subnet-2")
ECS_SG=$(get_sg_id "taller-ecs-sg")

if [ -z "$PRIVATE_SUBNET_1" ] || [ "$PRIVATE_SUBNET_1" == "None" ]; then
    echo "❌ ERROR: No se encontraron las subredes. Ejecutá la red primero."
    exit 1
fi

# 2. Crear Cluster de ECS
echo "🏗️ Creando Cluster ECS '$CLUSTER_NAME'..."
aws ecs create-cluster \
  --cluster-name "$CLUSTER_NAME" \
  --region $REGION \
  --endpoint-url $ENDPOINT \
  > /dev/null

# 3. Registrar la Definición de Tarea (Task Definition)
echo "📄 Registrando Task Definition '$TASK_DEF_FAMILY'..."
CONTAINER_DEF=$(cat <<EOF
[
  {
    "name": "$REPO_NAME",
    "image": "$REPO_NAME:latest",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 8000,
        "hostPort": 8000,
        "protocol": "tcp"
      }
    ]
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
  --container-definitions "$CONTAINER_DEF" \
  --region $REGION \
  --endpoint-url $ENDPOINT \
  > /dev/null

# 4. Crear el Servicio de ECS
echo "🚀 Creando Servicio ECS '$SERVICE_NAME'..."
aws ecs create-service \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --task-definition "$TASK_DEF_FAMILY" \
  --desired-count 1 \
  --launch-type "FARGATE" \
  --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG],assignPublicIp=ENABLED}" \
  --region $REGION \
  --endpoint-url $ENDPOINT \
  > /dev/null || echo "ℹ️ El servicio ECS ya existía o se está actualizando."

echo "========================================="
echo "✅ Amazon ECS configurado exitosamente en AWS"
echo "========================================="