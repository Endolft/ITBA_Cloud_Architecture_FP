#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh" 2>/dev/null || true

echo "Configurando NAT Gateways en la VPC..."

VPC_ID=$(get_vpc_id)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "ERROR: No se encontró la VPC 'taller-vpc'. Ejecuta primero deploy_vpc.sh"
    exit 1
fi

# 2. Recuperar Subred Pública 1 (AZ-1a)
PUB_SUBNET_1=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=taller-public-subnet-1" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --query 'Subnets[0].SubnetId' \
  --output text 2>/dev/null || echo "None")

# 3. Recuperar Tabla de Rutas Privada
PRIV_RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=taller-private-rt" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --query 'RouteTables[0].RouteTableId' \
  --output text 2>/dev/null || echo "None")

# Detección de Entorno Local
if [[ "$ENDPOINT" == *"localhost:4566"* ]] || [[ "$ENDPOINT" == *"127.0.0.1:4566"* ]]; then
    echo "INFO: Entorno Local/LocalStack detectado:"
    echo "   (En local, los contenedores Docker ya tienen salida a Internet a través de la red host,"
    echo "   simularemos la creación del EIP y NAT Gateway para mantener la compatibilidad con AWS)."
    
    NAT_GW_ID="nat-simulado-12345678"
    EIP_ALLOC="eipalloc-simulado-12345"
else
    echo "NUBE: Entorno AWS Real detectado: Asignando Elastic IP y creando NAT Gateway..."
    
    # Asignar Elastic IP (EIP)
    EIP_ALLOC=$(aws ec2 allocate-address \
      --domain vpc \
      --region "$REGION" \
      --query 'AllocationId' \
      --output text)
    echo "OK: Elastic IP Asignada: $EIP_ALLOC"

    # Crear NAT Gateway en la Subred Pública 1
    NAT_GW_ID=$(aws ec2 create-nat-gateway \
      --subnet-id "$PUB_SUBNET_1" \
      --allocation-id "$EIP_ALLOC" \
      --region "$REGION" \
      --query 'NatGateway.NatGatewayId' \
      --output text)
    echo "ESPERA: Esperando a que el NAT Gateway ($NAT_GW_ID) esté disponible..."
    
    aws ec2 wait nat-gateway-available \
      --nat-gateway-ids "$NAT_GW_ID" \
      --region "$REGION"
fi

# 4. Apuntar la ruta 0.0.0.0/0 de la Tabla de Rutas Privada hacia el NAT Gateway
if [ "$PRIV_RT_ID" != "None" ] && [ "$PRIV_RT_ID" != "" ]; then
    echo "Ruteando tráfico privado (0.0.0.0/0) de '$PRIV_RT_ID' hacia NAT Gateway '$NAT_GW_ID'..."
    aws ec2 create-route \
      --route-table-id "$PRIV_RT_ID" \
      --destination-cidr-block "0.0.0.0/0" \
      --nat-gateway-id "$NAT_GW_ID" \
      --region "$REGION" \
      --endpoint-url "$ENDPOINT" 2>/dev/null || echo "INFO: La ruta hacia el NAT Gateway ya existía o fue simulada."
fi

echo "OK: NAT Gateway ($NAT_GW_ID) configurado correctamente"
