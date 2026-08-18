#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "========================================="
echo "🚀 Iniciando Despliegue Completo de Infraestructura"
echo "========================================="

# 1. Capa de Red y Seguridad (VPC, Subnets, SGs)
echo -e "[1/10] Desplegando Red (VPC)..."
"$DIR/../infra/vpc/deploy_vpc.sh"

# 2. VPC Endpoints (Acceso Privado a S3)
echo -e "[2/10] Configurando VPC Gateway Endpoints (S3)..."
"$DIR/../infra/vpc/create_endpoints.sh"

# 3. Bóveda de Secretos (Secrets Manager)
echo -e "[3/10] Desplegando Secretos..."
"$DIR/../infra/secrets/create_secrets.sh"

# 4. Base de Datos (RDS PostgreSQL)
echo -e "[4/10] Desplegando Base de Datos (RDS)..."
"$DIR/../infra/rds/create_rds.sh"

# 5. Registro de Imágenes (ECR)
echo -e "[5/10] Desplegando ECR..."
"$DIR/../infra/ecr/create_ecr.sh"

# 6. Recursos Base de Almacenamiento (S3 y CloudWatch Logs)
echo -e "[6/10] Desplegando S3 Buckets y Log Groups..."
"$DIR/../infra/s3/create_s3.sh"

# 7. Permisos e Identidades (IAM Roles para ECS)
echo -e "[7/10] Desplegando Roles de IAM..."
"$DIR/../infra/iam/create_iam.sh"

# 8. Balanceador de Carga (ALB)
echo -e "[8/10] Desplegando ALB..."
"$DIR/../infra/alb/create_alb.sh"

# 9. Capa de Cómputo (ECS)
echo -e "[9/10] Desplegando ECS (Backend App)..."
"$DIR/../infra/ecs/create_ecs.sh"

# 10. Despliegue de Frontend e Integración CORS
echo -e "[10/10] Desplegando Frontend Mock a S3 y aplicando CORS..."
"$DIR/../infra/s3/deploy_frontend.sh"

echo ""
echo "========================================="
echo "Infraestructura desplegada exitosamente!"
echo "👉 Para probar en local: curl http://localhost"
echo "========================================="