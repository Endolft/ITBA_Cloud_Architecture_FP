#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

SECRET_NAME="taller/db/credentials"
DB_USER="${POSTGRES_USER:-postgres}"


# Generación dinámica con bifurcación Local vs AWS
if [[ "$ENDPOINT" == *"localhost:4566"* ]] || [[ "$ENDPOINT" == *"127.0.0.1:4566"* ]]; then
    echo "⚠️ Entorno local detectado. Usando contraseña del entorno o la estática por defecto..."
    DB_PASS="${POSTGRES_PASSWORD:-postgres}"
else
    echo "Generando contraseña segura aleatoria en AWS..."
    DB_PASS=$(aws secretsmanager get-random-password \
      --password-length 16 \
      --exclude-punctuation \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'RandomPassword' \
      --output text 2>/dev/null)
fi

echo "Configurando AWS Secrets Manager..."

SECRET_STRING="{\"username\":\"$DB_USER\",\"password\":\"$DB_PASS\",\"engine\":\"postgres\",\"port\":5432}"

# Guardar secreto idempotente
SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id "$SECRET_NAME" \
  --region $REGION \
  --endpoint-url $ENDPOINT \
  --query 'ARN' \
  --output text 2>/dev/null || echo "None")

if [ "$SECRET_ARN" == "None" ] || [ -z "$SECRET_ARN" ]; then
    echo "🔒 Creando secreto '$SECRET_NAME'..."
    aws secretsmanager create-secret \
      --name "$SECRET_NAME" \
      --description "Credenciales para PostgreSQL en RDS" \
      --secret-string "$SECRET_STRING" \
      --region $REGION \
      --endpoint-url $ENDPOINT > /dev/null
    echo "✅ Secreto creado exitosamente."
else
    echo "El secreto '$SECRET_NAME' ya existe."
fi