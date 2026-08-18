#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "========================================="
echo "🚀 Iniciando Despliegue Completo de Infraestructura"
echo "========================================="

# 1. Capa de Red y Seguridad (VPC, Subnets, SGs)
echo -e "[1/11] Desplegando Red (VPC)..."
"$DIR/../infra/vpc/deploy_vpc.sh"

# 3. Bóveda de Secretos (Secrets Manager)
echo -e "[2/11] Desplegando Secretos..."
"$DIR/../infra/secrets/create_secrets.sh"

# 4. Base de Datos (RDS PostgreSQL)
echo -e "[3/11] Desplegando Base de Datos (RDS)..."
"$DIR/../infra/rds/create_rds.sh"

# 5. Registro de Imágenes (ECR)
echo -e "[4/11] Desplegando ECR..."
"$DIR/../infra/ecr/create_ecr.sh"

# 6. Recursos Base de Almacenamiento (S3 y CloudWatch Logs)
echo -e "[5/11] Desplegando S3 Buckets y Log Groups..."
"$DIR/../infra/s3/create_s3.sh"

# 7. Permisos e Identidades (IAM Roles para ECS)
echo -e "[6/11] Desplegando Roles de IAM..."
"$DIR/../infra/iam/create_iam.sh"

# 8. Balanceador de Carga (ALB)
echo -e "[7/11] Desplegando ALB..."
"$DIR/../infra/alb/create_alb.sh"

# 9. Capa de Cómputo (ECS)
echo -e "[8/11] Desplegando ECS (Backend App)..."
"$DIR/../infra/ecs/create_ecs.sh"

# 10. Auto Scaling del servicio ECS
echo -e "[9/11] Configurando Auto Scaling de ECS..."
"$DIR/../infra/ecs/configure_autoscaling.sh"

# 10. Despliegue de Frontend e Integración CORS
echo -e "[10/11] Desplegando Frontend Mock a S3 y aplicando CORS..."
"$DIR/../infra/s3/deploy_frontend.sh"

# 11. CDN para el Frontend estático (omitida en LocalStack)
echo -e "[11/11] Desplegando CloudFront para el Frontend..."
"$DIR/../infra/s3/create_cloudfront.sh"

echo ""
echo "========================================="
echo "Infraestructura desplegada exitosamente!"
echo "========================================="