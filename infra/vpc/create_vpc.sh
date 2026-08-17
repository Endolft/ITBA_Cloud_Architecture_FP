#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

# 1. Buscar si la VPC ya existe
VPC_ID=$(get_vpc_id)

# 2. Crear si no existe
if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "Creando la VPC..."
    VPC_ID=$(aws ec2 create-vpc \
      --cidr-block 10.0.0.0/16 \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'Vpc.VpcId' \
      --output text)

    if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
        echo "❌ ERROR: No se pudo obtener el ID de la VPC."
        exit 1
    fi
    echo "VPC creada exitosamente con ID: $VPC_ID"
else
    echo "La VPC '$VPC_NAME' ya existe con ID: $VPC_ID."
fi

# 3. Aplicar siempre etiquetas
aws ec2 create-tags \
  --resources $VPC_ID \
  --tags Key=Name,Value=$VPC_NAME \
  --region $REGION \
  --endpoint-url $ENDPOINT

# 4. Consultar y aplicar estado del DNS
DNS_STATE=$(aws ec2 describe-vpc-attribute \
  --vpc-id $VPC_ID \
  --attribute enableDnsHostnames \
  --region $REGION \
  --endpoint-url $ENDPOINT \
  --query 'EnableDnsHostnames.Value' \
  --output text 2>/dev/null || echo "false")

if [ "$DNS_STATE" != "true" ]; then
    echo "Habilitando soporte de DNS..."
    aws ec2 modify-vpc-attribute \
      --vpc-id $VPC_ID \
      --enable-dns-hostnames "{\"Value\":true}" \
      --region $REGION \
      --endpoint-url $ENDPOINT
else
    echo "El soporte de DNS ya estaba activo en la VPC."
fi

echo "✅ Configuración de la VPC '$VPC_NAME' ($VPC_ID) completada."