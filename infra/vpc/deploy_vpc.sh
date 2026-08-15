#!/bin/bash

set -e

# Obtener la ruta absoluta del directorio donde reside este script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "INICIANDO DESPLIEGUE COMPLETO DE REDES (VPC)"

# 1. Crear VPC
echo "--- PASO 1/4: Creación de VPC base --- "
"$DIR/create_vpc.sh"

# 2. Crear Subredes Multi-AZ
echo "--- PASO 2/4: Segmentación de Subredes Multi-AZ --- "
"$DIR/create_subnets.sh"

# 3. Configurar Internet Gateway y Tablas de Rutas
echo "--- PASO 3/4: Configuración de Enrutamiento Público --- "
"$DIR/create_routing.sh"

echo "--- PASO 4/4: Configuración de Security Groups ---"
"$DIR/create_security_groups.sh"

echo "========================"
echo "Red desplagada con exito"
echo "========================"