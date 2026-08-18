#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

IMAGE_TAG="latest"
IMAGE_NAME="$REPO_NAME:$IMAGE_TAG"

echo "Construyendo la imagen Docker de prueba (Mock)..."
docker build -t "$IMAGE_NAME" -f "$DIR/Dockerfile.mock" "$DIR"

echo "Imagen de prueba construida exitosamente"
echo "Imagen disponible como: $IMAGE_NAME"
echo "Puedes usar esta imagen localmente para pruebas"
