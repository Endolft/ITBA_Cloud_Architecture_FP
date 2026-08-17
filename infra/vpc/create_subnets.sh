#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

# 1. Obtener el ID de la VPC creada anteriormente
VPC_ID=$(get_vpc_id)

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
    SUBNET_ID=$(get_subnet_id "$NAME")

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