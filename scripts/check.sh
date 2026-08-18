#!/bin/bash
set -u

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../infra/config.sh"

BACKEND_BUCKET="${S3_BACKEND_BUCKET:-taller-backend-storage}"
FRONTEND_BUCKET="${S3_FRONTEND_BUCKET:-taller-frontend-static}"
POSTGRES_CONTAINER="itba-fp-postgres"
LOCALSTACK_CONTAINER="itba-fp-localstack"
BACKEND_URL="${BACKEND_URL:-http://localhost:8000}"
ALB_URL="${ALB_URL:-http://localhost}"

FAILED=0

ok() {
    echo "OK: $1"
}

warning() {
    echo "ADVERTENCIA: $1"
}

error() {
    echo "ERROR: $1"
    FAILED=1
}

check_command() {
    command -v "$1" >/dev/null 2>&1 || error "No se encontró el comando requerido: $1"
}

check_container_running() {
    local CONTAINER=$1
    local LABEL=$2

    if docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q '^true$'; then
        ok "$LABEL está en ejecución."
    else
        error "$LABEL no está en ejecución. Inicia el entorno con: docker compose up -d"
    fi
}

check_http_endpoint() {
    local URL=$1
    local LABEL=$2
    local EXPECTED=$3
    local RESPONSE

    RESPONSE=$(curl --silent --show-error --max-time 10 "$URL" 2>/dev/null || true)
    if printf '%s' "$RESPONSE" | grep -q "$EXPECTED"; then
        ok "$LABEL responde correctamente ($URL)."
    else
        error "$LABEL no respondió como se esperaba ($URL)."
    fi
}

echo "INICIO: Verificando la salud del entorno local..."

for COMMAND in docker curl aws; do
    check_command "$COMMAND"
done

if [ "$FAILED" -ne 0 ]; then
    echo "ERROR: Faltan herramientas para continuar con el diagnóstico."
    exit 1
fi

check_container_running "$POSTGRES_CONTAINER" "PostgreSQL"
check_container_running "$LOCALSTACK_CONTAINER" "LocalStack"
check_container_running "itba-fp-alb-mock" "Proxy Caddy (ALB mock)"

if docker exec "$POSTGRES_CONTAINER" pg_isready \
    -U "${POSTGRES_USER:-postgres}" \
    -d "${POSTGRES_DB:-workshop_db}" >/dev/null 2>&1; then
    ok "PostgreSQL acepta conexiones."
else
    error "PostgreSQL no acepta conexiones."
fi

if curl --silent --show-error --fail --max-time 10 \
    "http://localhost:4566/_localstack/health" >/dev/null 2>&1; then
    ok "LocalStack responde en http://localhost:4566."
else
    error "LocalStack no responde en http://localhost:4566."
fi

if aws secretsmanager describe-secret \
    --secret-id "$DB_SECRET_NAME" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" >/dev/null 2>&1; then
    ok "Secreto de base de datos disponible: $DB_SECRET_NAME"
else
    error "No se encontró el secreto de base de datos: $DB_SECRET_NAME"
fi

check_http_endpoint "$BACKEND_URL/" "Backend directo" '"status": "ok"'
check_http_endpoint "$ALB_URL/" "ALB mock" '"status": "ok"'

if aws s3api head-bucket \
    --bucket "$BACKEND_BUCKET" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" >/dev/null 2>&1; then
    ok "Bucket S3 de backend disponible: $BACKEND_BUCKET"
else
    error "No se pudo acceder al bucket S3 de backend: $BACKEND_BUCKET"
fi

if aws s3api head-bucket \
    --bucket "$FRONTEND_BUCKET" \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" >/dev/null 2>&1; then
    ok "Bucket S3 de frontend disponible: $FRONTEND_BUCKET"
else
    error "No se pudo acceder al bucket S3 de frontend: $FRONTEND_BUCKET"
fi

if aws s3api head-object \
    --bucket "$FRONTEND_BUCKET" \
    --key index.html \
    --region "$REGION" \
    --endpoint-url "$ENDPOINT" >/dev/null 2>&1; then
    ok "Frontend publicado: s3://$FRONTEND_BUCKET/index.html"
else
    warning "No se encontró index.html en el bucket frontend. Ejecuta deploy_frontend.sh."
fi

echo "========================================="
if [ "$FAILED" -eq 0 ]; then
    echo "OK: Todas las comprobaciones críticas finalizaron correctamente."
    exit 0
else
    echo "ERROR: Una o más comprobaciones críticas fallaron."
    exit 1
fi
