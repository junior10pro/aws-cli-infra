#!/bin/bash
# TD Jour 1 — Script complet
# VPC, EC2, Security Groups, NACL, Défense en profondeur

set -e  # Arrête le script en cas d'erreur

# ─── VARIABLES ────────────────────────────────────────────────
VPC_ID="vpc-0ebcdb39f7a526ef9"
SUBNET_ID="subnet-091906d7538d1e165"
VOTRE_IP="82.96.161.255"
REGION="eu-west-3"
KEY_NAME="wendyam_junior-key"
PUB_KEY_PATH="C:/Users/xyzkj/Claude/aws-cli-v1/Terraform_ansible/Terraform/wendyam_junior-key.pub"
PEM_PATH="C:/Users/xyzkj/Claude/aws-cli-v1/Terraform_ansible/Terraform/wendyam_junior-key"

# ══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 1 — Import de la clé SSH          ║"
echo "╚══════════════════════════════════════════╝"

# Importer la clé si elle n'existe pas déjà
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

# ══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 2 — Explorer le VPC par défaut    ║"
echo "╚══════════════════════════════════════════╝"

echo "--- VPC par défaut ---"
aws ec2 describe-vpcs --region "$REGION" \
  --filters Name=isDefault,Values=true \
  --query "Vpcs[].{Id:VpcId,Cidr:CidrBlock}"

echo "--- Sous-réseaux par défaut ---"
aws ec2 describe-subnets --region "$REGION" \
  --filters Name=default-for-az,Values=true \
  --query "Subnets[].{Id:SubnetId,Az:AvailabilityZone,Cidr:CidrBlock}"

# ══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 2b — Nettoyage instances orphelines║"
echo "╚══════════════════════════════════════════╝"

# Terminer les éventuelles instances td-bastion/td-cible encore actives
OLD_IDS=$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Name,Values=td-bastion,td-cible" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].InstanceId" --output text)

if [ -n "$OLD_IDS" ] && [ "$OLD_IDS" != "None" ]; then
  echo "Instances orphelines détectées : $OLD_IDS"
  aws ec2 terminate-instances --region "$REGION" --instance-ids $OLD_IDS > /dev/null
  echo "Attente de la terminaison..."
  aws ec2 wait instance-terminated --region "$REGION" --instance-ids $OLD_IDS
  echo "Instances orphelines supprimées"
else
  echo "Aucune instance orpheline trouvée"
fi

# ══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 3 — Lancer les instances EC2      ║"
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

# ══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 4 — Security Groups               ║"
echo "╚══════════════════════════════════════════╝"

# td-bastion-sg
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

echo "sg-bastion ($SG_BASTION) créé et attaché au bastion"

# td-cible-sg
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

echo "sg-cible ($SG_CIBLE) créé et attaché à la cible"

# ══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 5 — NACL stateless                ║"
echo "╚══════════════════════════════════════════╝"

# Sauvegarder l'association NACL actuelle
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

# Associer au sous-réseau
aws ec2 replace-network-acl-association --region "$REGION" \
  --association-id "$ASSOC_ID" --network-acl-id "$NACL_ID" > /dev/null

# Règle entrante SSH
aws ec2 create-network-acl-entry --region "$REGION" \
  --network-acl-id "$NACL_ID" --rule-number 100 --protocol 6 \
  --port-range From=22,To=22 --cidr-block "${VOTRE_IP}/32" \
  --rule-action allow --ingress

# Règle sortante ports éphémères (trafic retour SSH)
aws ec2 create-network-acl-entry --region "$REGION" \
  --network-acl-id "$NACL_ID" --rule-number 100 --protocol 6 \
  --port-range From=1024,To=65535 --cidr-block "0.0.0.0/0" \
  --rule-action allow --egress

echo "Règles NACL ajoutées (SSH entrant + ports éphémères sortants)"

# ══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 6 — Défense en profondeur         ║"
echo "╚══════════════════════════════════════════╝"

# Ajouter règle DENY n°90 (priorité > allow n°100)
aws ec2 create-network-acl-entry --region "$REGION" \
  --network-acl-id "$NACL_ID" --rule-number 90 --protocol 6 \
  --port-range From=22,To=22 --cidr-block "${VOTRE_IP}/32" \
  --rule-action deny --ingress

echo "Règle DENY n°90 ajoutée — SSH bloqué malgré le SG qui autorise"
echo "Suppression de la règle DENY pour rétablir l'accès..."

aws ec2 delete-network-acl-entry --region "$REGION" \
  --network-acl-id "$NACL_ID" --rule-number 90 --ingress

echo "Règle DENY supprimée — accès rétabli"

# ══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  RÉCAPITULATIF                           ║"
echo "╚══════════════════════════════════════════╝"
echo "Bastion ID     : $BASTION_ID"
echo "Bastion IP pub : $BASTION_IP"
echo "Cible ID       : $CIBLE_ID"
echo "Cible IP priv  : $CIBLE_IP"
echo "sg-bastion     : $SG_BASTION"
echo "sg-cible       : $SG_CIBLE"
echo "NACL td-nacl   : $NACL_ID"
echo "NACL défaut    : $NACL_DEFAULT_ID"
echo "Assoc ID       : $ASSOC_ID"
echo ""
echo "Connecte-toi au bastion :"
echo "  ssh -i $PEM_PATH ec2-user@${BASTION_IP}"
echo "Depuis le bastion, ping/SSH la cible :"
echo "  ping $CIBLE_IP"
echo "  ssh ec2-user@${CIBLE_IP}"
echo ""
echo "Pour nettoyer : ./nettoyage.sh"

# Sauvegarder les IDs pour le nettoyage
cat > /c/Users/xyzkj/Claude/aws-cli-v1/TP_Jr_1/.td_ids << EOF
BASTION_ID="$BASTION_ID"
CIBLE_ID="$CIBLE_ID"
SG_BASTION="$SG_BASTION"
SG_CIBLE="$SG_CIBLE"
NACL_ID="$NACL_ID"
NACL_DEFAULT_ID="$NACL_DEFAULT_ID"
ASSOC_ID="$ASSOC_ID"
EOF

echo "IDs sauvegardés dans .td_ids"
