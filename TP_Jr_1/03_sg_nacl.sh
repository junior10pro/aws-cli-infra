#!/bin/bash
# Partie 3 — Security Groups + NACL stateless

set -e

TD_IDS="/c/Users/xyzkj/Claude/aws-cli-v1/TP_Jr_1/.td_ids"

if [ ! -f "$TD_IDS" ]; then
  echo "ERREUR : Lance d'abord ./01_vpc.sh puis ./02_instances.sh"
  exit 1
fi
source "$TD_IDS"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 5 — Security Groups               ║"
echo "╚══════════════════════════════════════════╝"

# td-bastion-sg : SSH depuis mon IP uniquement
SG_BASTION=$(aws ec2 create-security-group --region "$REGION" \
  --group-name "td-bastion-sg" \
  --description "SSH depuis mon IP uniquement" \
  --vpc-id "$VPC_ID" \
  --query "GroupId" --output text)

aws ec2 authorize-security-group-ingress --region "$REGION" \
  --group-id "$SG_BASTION" \
  --protocol tcp --port 22 --cidr "${VOTRE_IP}/32"

aws ec2 modify-instance-attribute --region "$REGION" \
  --instance-id "$BASTION_ID" --groups "$SG_BASTION"

echo "td-bastion-sg ($SG_BASTION) créé et attaché au bastion"

# td-cible-sg : SSH + ICMP depuis bastion uniquement
SG_CIBLE=$(aws ec2 create-security-group --region "$REGION" \
  --group-name "td-cible-sg" \
  --description "SSH et ICMP depuis td-bastion-sg uniquement" \
  --vpc-id "$VPC_ID" \
  --query "GroupId" --output text)

aws ec2 authorize-security-group-ingress --region "$REGION" \
  --group-id "$SG_CIBLE" --protocol tcp --port 22 --source-group "$SG_BASTION"

aws ec2 authorize-security-group-ingress --region "$REGION" \
  --group-id "$SG_CIBLE" --protocol icmp --port -1 --source-group "$SG_BASTION"

aws ec2 modify-instance-attribute --region "$REGION" \
  --instance-id "$CIBLE_ID" --groups "$SG_CIBLE"

echo "td-cible-sg ($SG_CIBLE) créé et attaché à la cible"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 6 — NACL stateless                ║"
echo "╚══════════════════════════════════════════╝"

# Sauvegarder l'association et la NACL par défaut
ASSOC_ID=$(aws ec2 describe-network-acls --region "$REGION" \
  --filters "Name=association.subnet-id,Values=${SUBNET_ID}" \
  --query "NetworkAcls[0].Associations[?SubnetId=='${SUBNET_ID}'].NetworkAclAssociationId" \
  --output text)

NACL_DEFAULT_ID=$(aws ec2 describe-network-acls --region "$REGION" \
  --filters "Name=association.subnet-id,Values=${SUBNET_ID}" \
  --query "NetworkAcls[0].NetworkAclId" --output text)

echo "Association actuelle : $ASSOC_ID"
echo "NACL par défaut      : $NACL_DEFAULT_ID"

# Créer td-nacl
NACL_ID=$(aws ec2 create-network-acl --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=network-acl,Tags=[{Key=Name,Value=td-nacl}]' \
  --query "NetworkAcl.NetworkAclId" --output text)

echo "td-nacl créée : $NACL_ID"

# Associer td-nacl au sous-réseau
aws ec2 replace-network-acl-association --region "$REGION" \
  --association-id "$ASSOC_ID" --network-acl-id "$NACL_ID" > /dev/null

# Règle 100 entrante : SSH depuis mon IP
aws ec2 create-network-acl-entry --region "$REGION" \
  --network-acl-id "$NACL_ID" --rule-number 100 --protocol 6 \
  --port-range From=22,To=22 --cidr-block "${VOTRE_IP}/32" \
  --rule-action allow --ingress

# Règle 100 sortante : ports éphémères (retour SSH stateless)
aws ec2 create-network-acl-entry --region "$REGION" \
  --network-acl-id "$NACL_ID" --rule-number 100 --protocol 6 \
  --port-range From=1024,To=65535 --cidr-block "0.0.0.0/0" \
  --rule-action allow --egress

echo "Règles NACL ajoutées (SSH entrant + ports éphémères sortants)"

# Sauvegarder les IDs
cat >> "$TD_IDS" << EOF
SG_BASTION="$SG_BASTION"
SG_CIBLE="$SG_CIBLE"
NACL_ID="$NACL_ID"
NACL_DEFAULT_ID="$NACL_DEFAULT_ID"
ASSOC_ID="$ASSOC_ID"
EOF

echo ""
echo "Etape 5 & 6 terminées. Lance maintenant : ./04_defense.sh"
