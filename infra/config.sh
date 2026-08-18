CONFIG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

ENV_FILE="$CONFIG_DIR/../.env"
if [ -f "$ENV_FILE" ]; then
    set -o allexport
    source "$ENV_FILE"
    set +o allexport
fi

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"
export DB_SECRET_NAME="taller/db/credentials"
export REGION="us-east-1"
export ENDPOINT="${ENDPOINT:-http://localhost:4566}"

export VPC_NAME="taller-vpc"
export REPO_NAME="taller-backend"

# --- FUNCIONES GLOBALES ---

# Obtiene el ID de la VPC pasándole su nombre (Tag: Name)
get_vpc_id() {
    aws ec2 describe-vpcs \
      --filters "Name=tag:Name,Values=$VPC_NAME" \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'Vpcs[0].VpcId' \
      --output text 2>/dev/null || echo "None"
}

# Obtiene el ID de una Subred pasándole su nombre (Tag: Name)
get_subnet_id() {
    local SUBNET_NAME=$1
    aws ec2 describe-subnets \
      --filters "Name=tag:Name,Values=$SUBNET_NAME" \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'Subnets[0].SubnetId' \
      --output text 2>/dev/null || echo "None"
}

# Obtiene el ID de un Security Group pasándole su nombre (Group Name)
get_sg_id() {
    local SG_NAME=$1
    aws ec2 describe-security-groups \
      --filters "Name=group-name,Values=$SG_NAME" \
      --region $REGION \
      --endpoint-url $ENDPOINT \
      --query 'SecurityGroups[0].GroupId' \
      --output text 2>/dev/null || echo "None"
}