#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

# Usamos la variable del profe o appdb por defecto
DB_NAME="${POSTGRES_DB:-appdb}"
DB_INSTANCE="taller-db-instance"
DB_SUBNET_GROUP="taller-db-subnet-group"

echo "Configurando Amazon RDS (PostgreSQL)..."

# --- DETECCIÓN DE ENTORNO LOCAL ---
if [[ "$ENDPOINT" == *"localhost:4566"* ]] || [[ "$ENDPOINT" == *"127.0.0.1:4566"* ]]; then
    echo "⚠️ Despliegue local detectado."
    echo "💡 La base de datos PostgreSQL ya está siendo provista por Docker (puerto 5432)."
    echo "========================================="
    echo "✅ Módulo RDS (Simulado) procesado correctamente."
    echo "========================================="
    exit 0
fi
# ----------------------------------

echo "Desplegando RDS en AWS real..."

PRIVATE_SUBNET_1=$(get_subnet_id "taller-private-subnet-1")
PRIVATE_SUBNET_2=$(get_subnet_id "taller-private-subnet-2")
RDS_SG=$(get_sg_id "taller-rds-sg")

if [ -z "$PRIVATE_SUBNET_1" ] || [ -z "$RDS_SG" ]; then
    echo "❌ ERROR: Faltan recursos base (Subnets o SG). Ejecutá la red primero."
    exit 1
fi

# Obtener credenciales desde Secrets Manager
echo "🔑 Recuperando credenciales base desde Secrets Manager..."
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$DB_SECRET_NAME" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --query 'SecretString' \
  --output text 2>/dev/null || echo "None")

if [ "$SECRET_JSON" == "None" ] || [ -z "$SECRET_JSON" ]; then
    echo "❌ ERROR: No se encontró el secreto '$DB_SECRET_NAME' en Secrets Manager."
    echo "💡 Por favor, ejecutá el script de creación de secretos primero."
    exit 1
fi

DB_USER=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['username'])")
DB_PASS=$(echo "$SECRET_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])")

echo "🌐 Configurando DB Subnet Group..."
aws rds create-db-subnet-group \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --db-subnet-group-description "Subnet group para RDS en subredes privadas" \
    --subnet-ids "$PRIVATE_SUBNET_1" "$PRIVATE_SUBNET_2" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" \
    > /dev/null 2>&1 || echo "ℹ️ El Subnet Group ya existe."

echo "🗄️ Solicitando creación de instancia RDS PostgreSQL..."
aws rds create-db-instance \
    --db-instance-identifier "$DB_INSTANCE" \
    --db-name "$DB_NAME" \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 16.3 \
    --master-username "$DB_USER" \
    --master-user-password "$DB_PASS" \
    --allocated-storage 20 \
    --storage-encrypted \
    --backup-retention-period 7 \
    --vpc-security-group-ids "$RDS_SG" \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --no-publicly-accessible \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" \
    > /dev/null 2>&1 || echo "ℹ️ La instancia RDS ya existe o se está creando."

# --- ACÁ ESTÁ LA MAGIA DEL WAITER ---
echo "⏳ Esperando a que la base de datos esté disponible... (Esto puede tardar entre 5 y 10 minutos en AWS real)"
aws rds wait db-instance-available \
    --db-instance-identifier "$DB_INSTANCE" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT"

# --- ACÁ EXTRAEMOS EL ENDPOINT REAL ---
echo "🔍 Extrayendo el Endpoint de la base de datos..."
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_INSTANCE" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

# --- ACTUALIZAMOS EL SECRETO PARA CUMPLIR CON EL PROFE ---
echo "📝 Actualizando Secrets Manager con el Endpoint completo..."
NEW_SECRET_STRING="{\"username\":\"$DB_USER\",\"password\":\"$DB_PASS\",\"engine\":\"postgres\",\"host\":\"$RDS_ENDPOINT\",\"port\":5432,\"dbname\":\"$DB_NAME\"}"

aws secretsmanager put-secret-value \
    --secret-id "$DB_SECRET_NAME" \
    --secret-string "$NEW_SECRET_STRING" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" > /dev/null

echo "========================================="
echo "✅ Amazon RDS configurado y listo para recibir conexiones"
echo "👉 Endpoint: $RDS_ENDPOINT"
echo "========================================="