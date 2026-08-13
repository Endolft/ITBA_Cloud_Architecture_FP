#!/bin/bash

echo "Iniciando el despliegue..."

REGION="us-east-1"
ENDPOINT="http://localhost:4566"

echo "Creando la VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region $REGION \
  --endpoint-url $ENDPOINT \
  --query 'Vpc.VpcId' \
  --output text)

// Enable DNS hostnames
echo "Habilitando soporte de DNS en la VPC..."
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames "{\"Value\":true}" \
  --region $REGION \
  --endpoint-url $ENDPOINT

echo "✅ VPC creada exitosamente con ID: $VPC_ID"