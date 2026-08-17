#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "========================================="
echo "🚀 Iniciando Despliegue Completo de Infraestructura"
echo "========================================="

# 1. Capa de Red y Seguridad (VPC, Subnets, SGs)
echo ""
echo "🔹 [1/4] Desplegando Red (VPC)..."
"$DIR/../infra/vpc/deploy_vpc.sh"

# 2. Registro de Imágenes (ECR)
echo ""
echo "🔹 [2/4] Desplegando ECR..."
"$DIR/../infra/ecr/create_ecr.sh"

# 3. Balanceador de Carga (ALB)
echo ""
echo "🔹 [3/4] Desplegando ALB (Caddy Mock)..."
"$DIR/../infra/alb/create_alb.sh"

# 4. Capa de Cómputo (ECS)
echo ""
echo "🔹 [4/4] Desplegando ECS (Backend App)..."
"$DIR/../infra/ecs/create_ecs.sh"

echo ""
echo "========================================="
echo "🎉 ¡Infraestructura desplegada exitosamente!"
echo "👉 Podés probar el entorno con: curl http://localhost"
echo "========================================="