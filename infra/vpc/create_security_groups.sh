#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"


echo "Configurando Security Groups..."

# 1. Obtener ID de la VPC
VPC_ID=$(get_vpc_id)

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "❌ ERROR: No existe la VPC '$VPC_NAME'. Ejecutá primero create_vpc.sh"
    exit 1
fi


# Crea el SG desde cero
create_sg() {
    local SG_NAME=$1
    local SG_DESC=$2

    NEW_SG_ID=$(aws ec2 create-security-group \
      --group-name "$SG_NAME" \
      --description "$SG_DESC" \
      --vpc-id $VPC_ID \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'GroupId' \
      --output text)

    aws ec2 create-tags \
      --resources $NEW_SG_ID \
      --tags Key=Name,Value=$SG_NAME \
      --region $REGION \
      --endpoint-url $ENDPOINT

    echo "$NEW_SG_ID"
}

# Coordinadora (Idempotencia)
ensure_sg() {
    local SG_NAME=$1
    local SG_DESC=$2

    SG_ID=$(get_sg_id "$SG_NAME")

    if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
        SG_ID=$(create_sg "$SG_NAME" "$SG_DESC")
        echo "Security Group '$SG_NAME' creado: $SG_ID" >&2
    else
        echo "Security Group '$SG_NAME' ya existe: $SG_ID" >&2
    fi

    echo "$SG_ID"
}

# 2. Obtener o Crear los 3 Security Groups
ALB_SG_ID=$(ensure_sg "taller-alb-sg" "SG para Load Balancer Publico")
ECS_SG_ID=$(ensure_sg "taller-ecs-sg" "SG para Backend ECS")
RDS_SG_ID=$(ensure_sg "taller-rds-sg" "SG para Base de Datos RDS PostgreSQL")

add_ingress_rule() {
    local SG_ID=$1
    local PORT=$2
    local SOURCE=$3

    if [[ "$SOURCE" == sg-* ]]; then
        aws ec2 authorize-security-group-ingress \
          --group-id $SG_ID \
          --protocol tcp \
          --port $PORT \
          --source-group $SOURCE \
          --region $REGION \
          --endpoint-url $ENDPOINT > /dev/null 2>&1 || true
    else
        aws ec2 authorize-security-group-ingress \
          --group-id $SG_ID \
          --protocol tcp \
          --port $PORT \
          --cidr $SOURCE \
          --region $REGION \
          --endpoint-url $ENDPOINT > /dev/null 2>&1 || true
    fi
}

add_ingress_rule $ALB_SG_ID 80 "0.0.0.0/0"
add_ingress_rule $ECS_SG_ID 8000 $ALB_SG_ID
add_ingress_rule $RDS_SG_ID 5432 $ECS_SG_ID

echo "✅ Grupos de Seguridad configurados exitosamente."