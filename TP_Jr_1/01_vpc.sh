#!/bin/bash
# Partie 1 — Import clé SSH + Explorer le VPC par défaut

set -e

REGION="eu-west-3"
KEY_NAME="wendyam_junior-key"
PUB_KEY_PATH="C:/Users/xyzkj/Claude/aws-cli-v1/Terraform_ansible/Terraform/wendyam_junior-key.pub"
TD_IDS="/c/Users/xyzkj/Claude/aws-cli-v1/TP_Jr_1/.td_ids"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 1 — Import de la clé SSH          ║"
echo "╚══════════════════════════════════════════╝"

EXISTING_KEY=$(aws ec2 describe-key-pairs --region "$REGION" \
  --filters "Name=key-name,Values=${KEY_NAME}" \
  --query "KeyPairs[0].KeyName" --output text 2>/dev/null || echo "None")

if [ "$EXISTING_KEY" == "None" ] || [ -z "$EXISTING_KEY" ]; then
  aws ec2 import-key-pair --region "$REGION" \
    --key-name "$KEY_NAME" \
    --public-key-material "fileb://${PUB_KEY_PATH}"
  echo "Clé '$KEY_NAME' importée dans AWS"
else
  echo "Clé '$KEY_NAME' déjà présente dans AWS"
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 2 — Explorer le VPC par défaut    ║"
echo "╚══════════════════════════════════════════╝"

echo "--- Votre IP publique ---"
curl -s https://checkip.amazonaws.com

echo ""
echo "--- VPC par défaut ---"
aws ec2 describe-vpcs --region "$REGION" \
  --filters Name=isDefault,Values=true \
  --query "Vpcs[].{Id:VpcId,Cidr:CidrBlock}"

echo "--- Sous-réseaux par défaut ---"
aws ec2 describe-subnets --region "$REGION" \
  --filters Name=default-for-az,Values=true \
  --query "Subnets[].{Id:SubnetId,Az:AvailabilityZone,Cidr:CidrBlock}"

# Initialiser le fichier .td_ids
cat > "$TD_IDS" << EOF
REGION="eu-west-3"
VPC_ID="vpc-0ebcdb39f7a526ef9"
SUBNET_ID="subnet-091906d7538d1e165"
VOTRE_IP="82.96.161.255"
KEY_NAME="wendyam_junior-key"
PEM_PATH="C:/Users/xyzkj/Claude/aws-cli-v1/Terraform_ansible/Terraform/wendyam_junior-key"
EOF

echo ""
echo "Etape 1 & 2 terminées. Lance maintenant : ./02_instances.sh"
