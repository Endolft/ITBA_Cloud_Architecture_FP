#!/bin/bash

set -e

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"

REGION="us-east-1"
ENDPOINT="http://localhost:4566"
REPO_NAME="taller-backend"

echo "Configurando repositorio Amazon ECR..."

# 1. Consultar si el repositorio ya existe
REPO_URI=$(aws ecr describe-repositories \
  --repository-names "$REPO_NAME" \
  --region $REGION \
  --endpoint-url $ENDPOINT \
  --query 'repositories[0].repositoryUri' \
  --output text 2>/dev/null || echo "None")

# 2. Crear el repositorio
if [ "$REPO_URI" == "None" ] || [ -z "$REPO_URI" ]; then
    echo "Creando repositorio ECR '$REPO_NAME'..."
    
    REPO_URI=$(aws ecr create-repository \
      --repository-name "$REPO_NAME" \
      --image-scanning-configuration scanOnPush=true \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'repository.repositoryUri' \
      --output text)

    echo "Repositorio ECR creado con éxito: $REPO_URI"
else
    echo "El repositorio ECR '$REPO_NAME' ya existe: $REPO_URI"
fi

echo "URI del Repositorio: $REPO_URI"