#!/bin/bash

set -e

# Obtener la ruta absoluta del directorio donde reside este script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "INICIANDO DESPLIEGUE COMPLETO DE REDES (VPC)"

# 1. Crear VPC
echo "PASO 1/3: Creación de VPC base"
"$DIR/create_vpc.sh"

# 2. Crear Subredes Multi-AZ
echo "PASO 2/3: Segmentación de Subredes Multi-AZ"
"$DIR/create_subnets.sh"

# 3. Configurar Internet Gateway y Tablas de Rutas
echo "PASO 3/3: Configuración de Enrutamiento Público"
"$DIR/create_routing.sh"

echo "========================"
echo "Red desplagada con exito"
echo "========================"