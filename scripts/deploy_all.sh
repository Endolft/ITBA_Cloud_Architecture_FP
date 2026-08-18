#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "========================================="
echo "🚀 Iniciando Despliegue Completo de Infraestructura"
echo "========================================="

# 1. Capa de Red y Seguridad (VPC, Subnets, SGs)
echo -e "[1/8] Desplegando Red (VPC)..."
"$DIR/../infra/vpc/deploy_vpc.sh"

# 2. Bóveda de Secretos (Secrets Manager)
echo -e "[2/8] Desplegando Secretos..."
"$DIR/../infra/secrets/create_secrets.sh"

# 3. Base de Datos (RDS PostgreSQL)
echo -e "[3/8] Desplegando Base de Datos (RDS)..."
"$DIR/../infra/rds/create_rds.sh"

# 4. Registro de Imágenes (ECR)
echo -e "[4/8] Desplegando ECR..."
"$DIR/../infra/ecr/create_ecr.sh"

# 5. Recursos Base de Almacenamiento (S3 y CloudWatch Logs)
echo -e "[5/8] Desplegando S3 Buckets y Log Groups..."
"$DIR/../infra/s3/create_s3.sh"

# 6. Permisos e Identidades (IAM Roles para ECS)
echo -e "[6/8] Desplegando Roles de IAM..."
"$DIR/../infra/iam/create_iam.sh"

# 7. Balanceador de Carga (ALB)
echo -e "[7/8] Desplegando ALB..."
"$DIR/../infra/alb/create_alb.sh"

# 8. Capa de Cómputo (ECS)
echo -e "[8/8] Desplegando ECS (Backend App)..."
"$DIR/../infra/ecs/create_ecs.sh"

echo ""
echo "========================================="
echo "Infraestructura desplegada exitosamente!"
echo "👉 Para probar en local: curl http://localhost"
echo "========================================="