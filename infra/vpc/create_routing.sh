#!/bin/bash

set -e

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"

REGION="us-east-1"
ENDPOINT="http://localhost:4566"
VPC_NAME="taller-vpc"
IGW_NAME="taller-igw"
RT_NAME="taller-public-rt"

echo "Configurando la capa de enrutamiento pública..."

# 1. Obtener ID de la VPC
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --region $REGION \
  --endpoint-url $ENDPOINT \
  --query 'Vpcs[0].VpcId' \
  --output text 2>/dev/null || echo "None")

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "ERROR: No existe la VPC '$VPC_NAME'. Ejecutá primero create_vpc.sh"
    exit 1
fi

# 2. Buscar o crear el Internet Gateway (IGW)
IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters "Name=tag:Name,Values=$IGW_NAME" \
  --region $REGION \
  --endpoint-url $ENDPOINT \
  --query 'InternetGateways[0].InternetGatewayId' \
  --output text 2>/dev/null || echo "None")

if [ "$IGW_ID" == "None" ] || [ -z "$IGW_ID" ]; then
    echo "Creando Internet Gateway '$IGW_NAME'..."
    IGW_ID=$(aws ec2 create-internet-gateway \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'InternetGateway.InternetGatewayId' \
      --output text)

    aws ec2 create-tags \
      --resources $IGW_ID \
      --tags Key=Name,Value=$IGW_NAME \
      --region $REGION \
      --endpoint-url $ENDPOINT

    aws ec2 attach-internet-gateway \
      --vpc-id $VPC_ID \
      --internet-gateway-id $IGW_ID \
      --region $REGION \
      --endpoint-url $ENDPOINT
    echo "IGW creado e instalado en la VPC: $IGW_ID"
else
    echo "IGW ya existe con ID: $IGW_ID"
fi

# 3. Buscar o crear la Tabla de Rutas Pública
RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=$RT_NAME" \
  --region $REGION \
  --endpoint-url $ENDPOINT \
  --query 'RouteTables[0].RouteTableId' \
  --output text 2>/dev/null || echo "None")

if [ "$RT_ID" == "None" ] || [ -z "$RT_ID" ]; then
    echo "Creando Tabla de Rutas '$RT_NAME'..."
    RT_ID=$(aws ec2 create-route-table \
      --vpc-id $VPC_ID \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'RouteTable.RouteTableId' \
      --output text)

    aws ec2 create-tags \
      --resources $RT_ID \
      --tags Key=Name,Value=$RT_NAME \
      --region $REGION \
      --endpoint-url $ENDPOINT

    # Apuntar todo el tráfico 0.0.0.0/0 (Internet) hacia el Internet Gateway
    aws ec2 create-route \
      --route-table-id $RT_ID \
      --destination-cidr-block 0.0.0.0/0 \
      --gateway-id $IGW_ID \
      --region $REGION \
      --endpoint-url $ENDPOINT > /dev/null

    echo "✅ Tabla de rutas pública configurada con salida a Internet (0.0.0.0/0 -> IGW)"
else
    echo "Tabla de Rutas ya existe con ID: $RT_ID"
fi

# 4. Asociar únicamente las Subredes Públicas a esta Tabla de Rutas
associate_subnet() {
    local SUBNET_NAME=$1
    SUBNET_ID=$(aws ec2 describe-subnets \
      --filters "Name=tag:Name,Values=$SUBNET_NAME" \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'Subnets[0].SubnetId' \
      --output text 2>/dev/null || echo "None")

    if [ "$SUBNET_ID" != "None" ] && [ -n "$SUBNET_ID" ]; then
        ASSOC_ID=$(aws ec2 describe-route-tables \
          --route-table-ids $RT_ID \
          --region $REGION \
          --endpoint-url $ENDPOINT \
          --query "RouteTables[0].Associations[?SubnetId=='$SUBNET_ID'].RouteTableAssociationId" \
          --output text 2>/dev/null || echo "None")

        if [ "$ASSOC_ID" == "None" ] || [ -z "$ASSOC_ID" ]; then
            aws ec2 associate-route-table \
              --subnet-id $SUBNET_ID \
              --route-table-id $RT_ID \
              --region $REGION \
              --endpoint-url $ENDPOINT > /dev/null
            echo "Subred pública '$SUBNET_NAME' asociada a la Tabla de Rutas"
        else
            echo "Subred '$SUBNET_NAME' ya estaba asociada a la Tabla de Rutas."
        fi
    fi
}

associate_subnet "taller-public-subnet-1"
associate_subnet "taller-public-subnet-2"

echo "Enrutamiento público configurado"