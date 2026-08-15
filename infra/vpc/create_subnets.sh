#!/bin/bash

set -e

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"

REGION="us-east-1"
ENDPOINT="http://localhost:4566"
VPC_NAME="taller-vpc"

# 1. Obtener el ID de la VPC creada anteriormente
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --region $REGION \
  --endpoint-url $ENDPOINT \
  --query 'Vpcs[0].VpcId' \
  --output text 2>/dev/null || echo "None")

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo " ERROR: No existe la VPC '$VPC_NAME'. Ejecutá primero create_vpc.sh"
    exit 1
fi

# Función auxiliar para crear subredes de forma idempotente
create_subnet() {
    local CIDR=$1
    local AZ=$2
    local NAME=$3
    
    # Buscar si existe por Tag
    SUBNET_ID=$(aws ec2 describe-subnets \
      --filters "Name=tag:Name,Values=$NAME" \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'Subnets[0].SubnetId' \
      --output text 2>/dev/null || echo "None")

    if [ "$SUBNET_ID" == "None" ] || [ -z "$SUBNET_ID" ]; then
        echo "Creando $NAME en $AZ ($CIDR)..."
        SUBNET_ID=$(aws ec2 create-subnet \
          --vpc-id $VPC_ID \
          --cidr-block $CIDR \
          --availability-zone $AZ \
          --region $REGION \
          --endpoint-url $ENDPOINT \
          --query 'Subnet.SubnetId' \
          --output text)

        aws ec2 create-tags \
          --resources $SUBNET_ID \
          --tags Key=Name,Value=$NAME \
          --region $REGION \
          --endpoint-url $ENDPOINT
        echo "$NAME creada: $SUBNET_ID"
    else
        echo "$NAME ya existe con ID: $SUBNET_ID"
    fi
}

# 2. Crear las Subredes repartidas en 2 AZs
create_subnet "10.0.1.0/24" "us-east-1a" "taller-public-subnet-1"
create_subnet "10.0.2.0/24" "us-east-1b" "taller-public-subnet-2"
create_subnet "10.0.10.0/24" "us-east-1a" "taller-private-subnet-1"
create_subnet "10.0.20.0/24" "us-east-1b" "taller-private-subnet-2"

echo "✅ Segmentación de red Multi-AZ completada."