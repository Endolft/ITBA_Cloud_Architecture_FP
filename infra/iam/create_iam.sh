#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

EXECUTION_ROLE_NAME="taller-ecs-execution-role"
TASK_ROLE_NAME="taller-ecs-task-role"
BACKEND_BUCKET="${S3_BACKEND_BUCKET:-taller-backend-storage}"

echo "[Paso 2] Configurando Roles y Políticas de IAM..."

# Documento de política de confianza (Trust Policy) para ECS
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
)


# 1. TASK EXECUTION ROLE (Agente de ECS -> Infraestructura)
echo "Verificando Execution Role '$EXECUTION_ROLE_NAME'..."
if aws iam get-role --role-name "$EXECUTION_ROLE_NAME" --region "$REGION" --endpoint-url "$ENDPOINT" >/dev/null 2>&1; then
    echo "El rol '$EXECUTION_ROLE_NAME' ya existe."
else
    echo "Creando '$EXECUTION_ROLE_NAME'..."
    aws iam create-role \
      --role-name "$EXECUTION_ROLE_NAME" \
      --assume-role-policy-document "$TRUST_POLICY" \
      --region "$REGION" \
      --endpoint-url "$ENDPOINT" > /dev/null
    echo "✅ Rol creado."
fi

# Adjuntar política administrada estándar de ECS Execution
aws iam attach-role-policy \
  --role-name "$EXECUTION_ROLE_NAME" \
  --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" >/dev/null 2>&1 || true

# Permitir lectura de Secrets Manager en el Execution Role
EXECUTION_SECRETS_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

aws iam put-role-policy \
  --role-name "$EXECUTION_ROLE_NAME" \
  --policy-name "ECSExecutionSecretsAccess" \
  --policy-document "$EXECUTION_SECRETS_POLICY" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" > /dev/null


# 2. TASK ROLE (Código Backend -> Aplicación)
echo "Verificando Task Role '$TASK_ROLE_NAME'..."
if aws iam get-role --role-name "$TASK_ROLE_NAME" --region "$REGION" --endpoint-url "$ENDPOINT" >/dev/null 2>&1; then
    echo "El rol '$TASK_ROLE_NAME' ya existe."
else
    echo "Creando '$TASK_ROLE_NAME'..."
    aws iam create-role \
      --role-name "$TASK_ROLE_NAME" \
      --assume-role-policy-document "$TRUST_POLICY" \
      --region "$REGION" \
      --endpoint-url "$ENDPOINT" > /dev/null
    echo "✅ Rol creado."
fi

# Política de acceso exclusivo a S3 para la aplicación
TASK_S3_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::$BACKEND_BUCKET",
        "arn:aws:s3:::$BACKEND_BUCKET/*"
      ]
    }
  ]
}
EOF
)

aws iam put-role-policy \
  --role-name "$TASK_ROLE_NAME" \
  --policy-name "ECSTaskS3Access" \
  --policy-document "$TASK_S3_POLICY" \
  --region "$REGION" \
  --endpoint-url "$ENDPOINT" > /dev/null

echo "========================================="
echo "✅ Roles de IAM configurados exitosamente"
echo "========================================="