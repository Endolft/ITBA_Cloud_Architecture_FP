#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/../config.sh"

FRONTEND_BUCKET="${S3_FRONTEND_BUCKET:-taller-frontend-static}"
DISTRIBUTION_COMMENT="CloudFront distribution for $FRONTEND_BUCKET"
OAC_NAME="${FRONTEND_BUCKET}-oac"

echo "Configurando Amazon CloudFront para '$FRONTEND_BUCKET'..."

if [[ "$ENDPOINT" == *"localhost:4566"* ]] || [[ "$ENDPOINT" == *"127.0.0.1:4566"* ]]; then
    echo "CloudFront se omite en el entorno local; LocalStack utiliza el acceso directo a S3."
    exit 0
fi

BUCKET_DOMAIN="$FRONTEND_BUCKET.s3.$REGION.amazonaws.com"

# Reutilizar el Origin Access Control si ya existe.
OAC_ID=$(aws cloudfront list-origin-access-controls \
  --query "OriginAccessControlList.Items[?Name=='$OAC_NAME'].Id | [0]" \
  --output text 2>/dev/null || echo "None")

if [ -z "$OAC_ID" ] || [ "$OAC_ID" == "None" ]; then
    OAC_ID=$(aws cloudfront create-origin-access-control \
      --origin-access-control-config "Name=$OAC_NAME,Description=Access control for $FRONTEND_BUCKET,SigningProtocol=sigv4,SigningBehavior=always,OriginAccessControlOriginType=s3" \
      --query 'OriginAccessControl.Id' \
      --output text)
    echo "Origin Access Control creado: $OAC_ID"
fi

DISTRIBUTION_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='$DISTRIBUTION_COMMENT'].Id | [0]" \
  --output text 2>/dev/null || echo "None")

if [ -z "$DISTRIBUTION_ID" ] || [ "$DISTRIBUTION_ID" == "None" ]; then
    CONFIG_FILE=$(mktemp)
    trap 'rm -f "$CONFIG_FILE"' EXIT

    cat > "$CONFIG_FILE" <<EOF
{
  "CallerReference": "$FRONTEND_BUCKET",
  "Comment": "$DISTRIBUTION_COMMENT",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-$FRONTEND_BUCKET",
        "DomainName": "$BUCKET_DOMAIN",
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        },
        "OriginAccessControlId": "$OAC_ID"
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-$FRONTEND_BUCKET",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {"Forward": "none"}
    },
    "Compress": true,
    "MinTTL": 0
  },
  "PriceClass": "PriceClass_100"
}
EOF

    DISTRIBUTION_ID=$(aws cloudfront create-distribution \
      --distribution-config "file://$CONFIG_FILE" \
      --query 'Distribution.Id' \
      --output text)
    echo "OK: Distribución CloudFront creada: $DISTRIBUTION_ID"
else
    echo "La distribución CloudFront ya existe: $DISTRIBUTION_ID"
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text --region "$REGION")
DISTRIBUTION_ARN="arn:aws:cloudfront::$ACCOUNT_ID:distribution/$DISTRIBUTION_ID"

# Permitir que únicamente esta distribución lea los objetos del bucket.
BUCKET_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipalReadOnly",
      "Effect": "Allow",
      "Principal": {"Service": "cloudfront.amazonaws.com"},
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$FRONTEND_BUCKET/*",
      "Condition": {
        "StringEquals": {"AWS:SourceArn": "$DISTRIBUTION_ARN"}
      }
    }
  ]
}
EOF
)

aws s3api put-bucket-policy \
  --bucket "$FRONTEND_BUCKET" \
  --policy "$BUCKET_POLICY" \
  --region "$REGION"

DISTRIBUTION_DOMAIN=$(aws cloudfront get-distribution \
  --id "$DISTRIBUTION_ID" \
  --query 'Distribution.DomainName' \
  --output text)

echo "OK: CloudFront configurado correctamente"
echo "URL: https://$DISTRIBUTION_DOMAIN"