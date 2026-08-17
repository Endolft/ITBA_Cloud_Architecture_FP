#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "========================================="
echo "DESPLEGANDO MÓDULO ECR / IMAGEN DOCKER"
echo "========================================="

"$DIR/create_ecr.sh"
"$DIR/push_mock_image.sh"

echo "✅ Módulo ECR procesado correctamente."