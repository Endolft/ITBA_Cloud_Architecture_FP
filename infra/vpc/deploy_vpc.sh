#!/bin/bash

set -e

# Obtener la ruta absoluta del directorio donde reside este script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "INICIANDO DESPLIEGUE COMPLETO DE REDES (VPC)"

# 1. Crear VPC
echo "--- PASO 1/5: Creación de VPC base --- "
"$DIR/create_vpc.sh"

# 2. Crear Subredes Multi-AZ
echo "--- PASO 2/5: Segmentación de Subredes Multi-AZ --- "
"$DIR/create_subnets.sh"

# 3. Configurar Internet Gateway y Tablas de Rutas
echo "--- PASO 3/5: Configuración de Enrutamiento Público --- "
"$DIR/create_routing.sh"

echo "--- PASO 4/5: Configuración de Security Groups ---"
"$DIR/create_security_groups.sh"

echo "--- PASO 5/5: Configuración de VPC Gateway Endpoints ---"
"$DIR/create_endpoints.sh"

echo "========================"
echo "Red desplagada con exito"
echo "========================"