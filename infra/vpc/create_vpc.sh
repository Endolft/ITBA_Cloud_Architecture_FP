#!/bin/bash

set -e

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"

REGION="us-east-1"
ENDPOINT="http://localhost:4566"
VPC_NAME="taller-vpc"


VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --region $REGION \
  --endpoint-url $ENDPOINT \
  --query 'Vpcs[0].VpcId' \
  --output text)

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    echo "La VPC '$VPC_NAME' ya existe con ID: $VPC_ID."

echo "Creando la VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region $REGION \
  --endpoint-url $ENDPOINT \
  --query 'Vpc.VpcId' \
  --output text)

  aws ec2 create-tags \
      --resources $VPC_ID \
      --tags Key=Name,Value=$VPC_NAME \
      --region $REGION \
      --endpoint-url $ENDPOINT

if [ -z "$VPC_ID" ]; then
    echo "❌ ERROR: No se pudo obtener el ID de la VPC."
    exit 1
fi

// Enable DNS hostnames
echo "Habilitando soporte de DNS en la VPC..."
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames "{\"Value\":true}" \
  --region $REGION \
  --endpoint-url $ENDPOINT



echo "✅ VPC creada exitosamente con ID: $VPC_ID"