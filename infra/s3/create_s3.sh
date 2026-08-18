#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

LOG_GROUP_NAME="/ecs/taller-backend"
BACKEND_BUCKET="${S3_BACKEND_BUCKET:-taller-backend-storage}"
FRONTEND_BUCKET="${S3_FRONTEND_BUCKET:-taller-frontend-static}"

echo "[Paso 1] Configurando Recursos Base: CloudWatch Logs y S3 Buckets..."

# 1. Crear CloudWatch Log Group para los contenedores de ECS
echo "Verificando CloudWatch Log Group '$LOG_GROUP_NAME'..."
LOG_EXISTS=$(aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP_NAME" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --query "logGroups[?logGroupName=='$LOG_GROUP_NAME'].logGroupName" \
  --output text 2>/dev/null || echo "")

if [ -z "$LOG_EXISTS" ]; then
    echo "Creando Log Group '$LOG_GROUP_NAME'..."
    aws logs create-log-group \
      --log-group-name "$LOG_GROUP_NAME" \
      --region "$REGION" \
      --endpoint-url "$ENDPOINT"
    echo "✅ Log Group creado."
else
    echo "ℹ️ El Log Group '$LOG_GROUP_NAME' ya existe."
fi

# 2. Función idempotente para la creación de S3 Buckets
create_bucket() {
    local BUCKET=$1
    echo "Verificando S3 Bucket '$BUCKET'..."
    
    if aws s3api head-bucket --bucket "$BUCKET" --region "$REGION" --endpoint-url "$ENDPOINT" 2>/dev/null; then
        echo "ℹ️ El bucket '$BUCKET' ya existe."
    else
        echo "Creando S3 Bucket '$BUCKET'..."
        if [ "$REGION" == "us-east-1" ]; then
            aws s3api create-bucket \
              --bucket "$BUCKET" \
              --region "$REGION" \
              --endpoint-url "$ENDPOINT" > /dev/null
        else
            aws s3api create-bucket \
              --bucket "$BUCKET" \
              --region "$REGION" \
              --endpoint-url "$ENDPOINT" \
              --create-bucket-configuration LocationConstraint="$REGION" > /dev/null
        fi
        echo "✅ Bucket '$BUCKET' creado exitosamente."
    fi
}

create_bucket "$BACKEND_BUCKET"
create_bucket "$FRONTEND_BUCKET"

echo "========================================="
echo "✅ Recursos base (S3 y Logs) creados correctamente"
echo "========================================="