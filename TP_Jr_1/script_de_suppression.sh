#!/bin/bash
# Nettoyage forcé — trouve et supprime les ressources TD par nom/tag
# Utilisé quand .td_ids est absent (run incomplet)

REGION="eu-west-3"
SUBNET_ID="subnet-091906d7538d1e165"

# ── 1. Terminer les instances td-bastion et td-cible ──────────
echo "=== Instances EC2 ==="
IDS=$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Name,Values=td-bastion-wendyam_junior,td-cible-wendyam_junior" \
            "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].InstanceId" --output text)

if [ -n "$IDS" ] && [ "$IDS" != "None" ]; then
  echo "Terminaison : $IDS"
  aws ec2 terminate-instances --region "$REGION" --instance-ids $IDS > /dev/null
  aws ec2 wait instance-terminated --region "$REGION" --instance-ids $IDS
  echo "Instances terminées"
else
  echo "Aucune instance td-* trouvée"
fi

# ── 2. Rétablir la NACL par défaut sur le sous-réseau ─────────
echo ""
echo "=== NACL ==="
NACL_TD=$(aws ec2 describe-network-acls --region "$REGION" \
  --filters "Name=tag:Name,Values=td-nacl" \
  --query "NetworkAcls[0].NetworkAclId" --output text 2>/dev/null)

if [ -n "$NACL_TD" ] && [ "$NACL_TD" != "None" ]; then
  # Trouver la NACL par défaut du VPC
  NACL_DEFAULT=$(aws ec2 describe-network-acls --region "$REGION" \
    --filters "Name=default,Values=true" \
    --query "NetworkAcls[0].NetworkAclId" --output text)

  # Trouver TOUTES les associations de td-nacl (peu importe le subnet)
  ASSOCS=$(aws ec2 describe-network-acls --region "$REGION" \
    --network-acl-ids "$NACL_TD" \
    --query "NetworkAcls[0].Associations[].NetworkAclAssociationId" \
    --output text)

  for ASSOC in $ASSOCS; do
    aws ec2 replace-network-acl-association --region "$REGION" \
      --association-id "$ASSOC" --network-acl-id "$NACL_DEFAULT" > /dev/null
    echo "Association $ASSOC → NACL par défaut ($NACL_DEFAULT)"
  done

  aws ec2 delete-network-acl --region "$REGION" --network-acl-id "$NACL_TD"
  echo "td-nacl ($NACL_TD) supprimée"
else
  echo "Aucune td-nacl trouvée"
fi

# ── 3. Supprimer les Security Groups sg-bastion et sg-cible ───
echo ""
echo "=== Security Groups ==="
for SG_NAME in td-cible-sg td-bastion-sg; do
  SG_ID=$(aws ec2 describe-security-groups --region "$REGION" \
    --filters "Name=group-name,Values=${SG_NAME}" \
    --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

  if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    aws ec2 delete-security-group --region "$REGION" --group-id "$SG_ID"
    echo "$SG_NAME ($SG_ID) supprimé"
  else
    echo "$SG_NAME non trouvé"
  fi
done

echo ""
echo "Nettoyage terminé. Tu peux relancer ./td_complet.sh"
