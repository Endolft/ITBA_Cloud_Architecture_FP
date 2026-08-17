#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

echo "Configurando repositorio Amazon ECR..."

# Check if we're using LocalStack
if [[ "$ENDPOINT" == *"localhost:4566"* ]] || [[ "$ENDPOINT" == *"127.0.0.1:4566"* ]]; then
    echo "⚠️  ECR no está disponible en LocalStack Community Edition"
    echo "Para desarrollo local, las imágenes Docker se construyen directamente"
    echo "Para usar ECR, despliega en AWS con credenciales reales"
    exit 0
fi

# Production AWS deployment - use real ECR
echo "Usando ECR en AWS..."

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
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'repository.repositoryUri' \
      --output text)

    echo "Repositorio ECR creado con éxito: $REPO_URI"
else
    echo "El repositorio ECR '$REPO_NAME' ya existe: $REPO_URI"
fi

echo "URI del Repositorio: $REPO_URI"