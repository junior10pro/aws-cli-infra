#!/bin/bash
# Partie 2 — Lancer les instances EC2 (bastion + cible)

set -e

TD_IDS="/c/Users/xyzkj/Claude/aws-cli-v1/TP_Jr_1/.td_ids"

if [ ! -f "$TD_IDS" ]; then
  echo "ERREUR : Lance d'abord ./01_vpc.sh"
  exit 1
fi
source "$TD_IDS"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 3 — Nettoyage instances orphelines║"
echo "╚══════════════════════════════════════════╝"

OLD_IDS=$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Name,Values=td-bastion-wendyam_junior,td-cible-wendyam_junior" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].InstanceId" --output text)

if [ -n "$OLD_IDS" ] && [ "$OLD_IDS" != "None" ]; then
  echo "Instances orphelines détectées : $OLD_IDS"
  aws ec2 terminate-instances --region "$REGION" --instance-ids $OLD_IDS > /dev/null
  aws ec2 wait instance-terminated --region "$REGION" --instance-ids $OLD_IDS
  echo "Instances orphelines supprimées"
else
  echo "Aucune instance orpheline trouvée"
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 4 — Lancer les instances EC2      ║"
echo "╚══════════════════════════════════════════╝"

AMI_ID=$(aws ec2 describe-images --region "$REGION" \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" \
  --output text)

echo "AMI : $AMI_ID"

# Bastion — avec IP publique
BASTION_ID=$(aws ec2 run-instances --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --key-name "$KEY_NAME" \
  --subnet-id "$SUBNET_ID" \
  --associate-public-ip-address \
  --count 1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=td-bastion-wendyam_junior}]' \
  --query "Instances[0].InstanceId" --output text)

echo "td-bastion : $BASTION_ID"

# Cible — sans IP publique
CIBLE_ID=$(aws ec2 run-instances --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --key-name "$KEY_NAME" \
  --subnet-id "$SUBNET_ID" \
  --no-associate-public-ip-address \
  --count 1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=td-cible-wendyam_junior}]' \
  --query "Instances[0].InstanceId" --output text)

echo "td-cible   : $CIBLE_ID"

echo "Attente démarrage instances..."
aws ec2 wait instance-running --region "$REGION" --instance-ids "$BASTION_ID" "$CIBLE_ID"

BASTION_IP=$(aws ec2 describe-instances --region "$REGION" \
  --instance-ids "$BASTION_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

CIBLE_IP=$(aws ec2 describe-instances --region "$REGION" \
  --instance-ids "$CIBLE_ID" \
  --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)

echo "IP publique bastion : $BASTION_IP"
echo "IP privée cible     : $CIBLE_IP"

# Sauvegarder les IDs
cat >> "$TD_IDS" << EOF
BASTION_ID="$BASTION_ID"
CIBLE_ID="$CIBLE_ID"
BASTION_IP="$BASTION_IP"
CIBLE_IP="$CIBLE_IP"
EOF

echo ""
echo "Connecte-toi au bastion pour tester :"
echo "  eval \$(ssh-agent -s)"
echo "  ssh-add $PEM_PATH"
echo "  ssh -A -i $PEM_PATH ec2-user@${BASTION_IP}"
echo ""
echo "Etape 3 & 4 terminées. Lance maintenant : ./03_sg_nacl.sh"
