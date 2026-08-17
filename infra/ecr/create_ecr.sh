#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

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