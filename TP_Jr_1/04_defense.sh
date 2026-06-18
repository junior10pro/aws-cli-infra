#!/bin/bash
# Partie 4 — Défense en profondeur (NACL DENY vs SG ALLOW)

set -e

TD_IDS="/c/Users/xyzkj/Claude/aws-cli-v1/TP_Jr_1/.td_ids"

if [ ! -f "$TD_IDS" ]; then
  echo "ERREUR : Lance d'abord 01_vpc.sh → 02_instances.sh → 03_sg_nacl.sh"
  exit 1
fi
source "$TD_IDS"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ÉTAPE 7 — Défense en profondeur         ║"
echo "╚══════════════════════════════════════════╝"

echo "Ajout règle DENY n°90 sur la NACL (priorité sur ALLOW n°100)..."
aws ec2 create-network-acl-entry --region "$REGION" \
  --network-acl-id "$NACL_ID" --rule-number 90 --protocol 6 \
  --port-range From=22,To=22 --cidr-block "${VOTRE_IP}/32" \
  --rule-action deny --ingress

echo ">>> Règle DENY n°90 active — SSH bloqué même si le SG autorise"
echo ">>> Test : essaie de te connecter en SSH au bastion, ça doit échouer"
echo ""
read -p "Appuie sur Entrée pour supprimer la règle DENY et rétablir l'accès..."

aws ec2 delete-network-acl-entry --region "$REGION" \
  --network-acl-id "$NACL_ID" --rule-number 90 --ingress

echo "Règle DENY supprimée — accès SSH rétabli"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  RÉCAPITULATIF FINAL                     ║"
echo "╚══════════════════════════════════════════╝"
echo "Bastion ID     : $BASTION_ID"
echo "Bastion IP pub : $BASTION_IP"
echo "Cible ID       : $CIBLE_ID"
echo "Cible IP priv  : $CIBLE_IP"
echo "td-bastion-sg  : $SG_BASTION"
echo "td-cible-sg    : $SG_CIBLE"
echo "NACL td-nacl   : $NACL_ID"
echo "NACL défaut    : $NACL_DEFAULT_ID"
echo ""
echo "Connexion SSH au bastion :"
echo "  eval \$(ssh-agent -s)"
echo "  ssh-add $PEM_PATH"
echo "  ssh -A -i $PEM_PATH ec2-user@${BASTION_IP}"
echo ""
echo "Depuis le bastion :"
echo "  ping $CIBLE_IP"
echo "  ssh ec2-user@${CIBLE_IP}"
echo ""
echo "Pour tout nettoyer : ./nettoyage_force.sh"
