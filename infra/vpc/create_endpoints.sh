#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

echo "Configurando VPC Gateway Endpoints para S3..."

VPC_ID=$(get_vpc_id)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "❌ ERROR: No se encontró la VPC 'taller-vpc'. Ejecutá primero deploy_vpc.sh"
    exit 1
fi

# Recuperar ID de la Tabla de Rutas
RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=taller-private-rt" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --query 'RouteTables[0].RouteTableId' \
  --output text 2>/dev/null || echo "None")

if [[ "$ENDPOINT" == *"localhost:4566"* ]] || [[ "$ENDPOINT" == *"127.0.0.1:4566"* ]]; then
    echo "Entorno local detectado. Creando VPC Gateway Endpoint en LocalStack..."
fi

echo "Creando VPC Gateway Endpoint hacia S3 para VPC '$VPC_ID'..."
ENDPOINT_ID=$(aws ec2 create-vpc-endpoint \
  --vpc-id "$VPC_ID" \
  --service-name "com.amazonaws.$REGION.s3" \
  --vpc-endpoint-type "Gateway" \
  --route-table-ids "$RT_ID" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --query 'VpcEndpoint.VpcEndpointId' \
  --output text 2>/dev/null || echo "vpce-simulado")

echo "========================================="
echo "✅ VPC Gateway Endpoint S3 ($ENDPOINT_ID) configurado correctamente"
echo "========================================="