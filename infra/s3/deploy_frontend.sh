#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

FRONTEND_BUCKET="${S3_FRONTEND_BUCKET:-taller-frontend-static}"
BACKEND_BUCKET="${S3_BACKEND_BUCKET:-taller-backend-storage}"
FRONTEND_DIR="$DIR/../frontend_mock"

echo "🎨 [Frontend & CORS] Configurando despliegue estático y política CORS..."

# 1. Configurar CORS en el bucket de fotos (Backend Storage)
echo "Aplicando reglas CORS en S3 Bucket '$BACKEND_BUCKET'..."
CORS_CONFIG=$(cat <<EOF
{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedOrigins": ["*"],
      "ExposeHeaders": ["ETag"]
    }
  ]
}
EOF
)

aws s3api put-bucket-cors \
  --bucket "$BACKEND_BUCKET" \
  --cors-configuration "$CORS_CONFIG" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" > /dev/null

echo "✅ Reglas CORS configuradas exitosamente."

# 2. Crear HTML de prueba si la carpeta de mock está vacía
if [ ! -d "$FRONTEND_DIR" ] || [ -z "$(ls -A "$FRONTEND_DIR" 2>/dev/null)" ]; then
    mkdir -p "$FRONTEND_DIR"
    cat <<HTML > "$FRONTEND_DIR/index.html"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Cloud Architecture - Photo Vault Mock</title>
</head>
<body>
    <h1>Frontend Mock Desplegado 🚀</h1>
</body>
</html>
HTML
fi

# 3. Subir archivos estáticos al S3 de Frontend
echo "Sincronizando '$FRONTEND_DIR' hacia 's3://$FRONTEND_BUCKET'..."
aws s3 sync "$FRONTEND_DIR" "s3://$FRONTEND_BUCKET" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" \
  --delete

# 4. Habilitar la configuración de Static Website Hosting en S3
echo "Habilitando Static Website Hosting en 's3://$FRONTEND_BUCKET'..."
aws s3website "s3://$FRONTEND_BUCKET" \
  --index-document index.html \
  --error-document index.html \
  --endpoint-url "$ENDPOINT" > /dev/null 2>&1 || true

# 5. Generar URL dinámica según el entorno (Codespaces, Local o AWS Real)
if [[ "$ENDPOINT" == *"localhost"* ]] || [[ "$ENDPOINT" == *"127.0.0.1"* ]] || [[ "$ENDPOINT" == *"4566"* ]]; then
    if [ -n "$CODESPACE_NAME" ] && [ -n "$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN" ]; then
        FRONTEND_URL="https://${CODESPACE_NAME}-4566.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}/${FRONTEND_BUCKET}/index.html"
    else
        FRONTEND_URL="http://localhost:4566/${FRONTEND_BUCKET}/index.html"
    fi
else
    FRONTEND_URL="http://${FRONTEND_BUCKET}.s3-website-${REGION}.amazonaws.com"
fi

echo "========================================="
echo "✅ Frontend desplegado y CORS configurado en S3"
echo "Acceso directo al sitio:"
echo "$FRONTEND_URL"
echo "========================================="
