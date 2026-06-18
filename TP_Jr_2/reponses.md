# Réponses TD Jour 2 — wendyam_junior

## Partie 1 — Provider et VPC par défaut

**Q1 : Différence entre resource et data source ?**  
Une `resource` est un objet que Terraform **crée, modifie et détruit** (ex: une EC2, un SG).  
Une `data source` **lit** un objet existant sans jamais le gérer ni le supprimer.  
Le VPC par défaut est déclaré en `data source` car on veut s'y rattacher sans risquer de le modifier ou de le supprimer accidentellement.

**Q2 : À quoi sert terraform.tfstate ?**  
C'est la mémoire de Terraform : il y stocke l'état de toutes les ressources qu'il gère (IDs, attributs...).  
Grâce à lui, `plan` calcule les différences entre le code et l'infrastructure réelle, et `destroy` sait exactement quelles ressources supprimer — sans toucher à ce qu'il n'a pas créé.

---

## Partie 2 — Filtrage entrant : Security Group et bastion

**Q1 : Pourquoi Terraform crée le SG avant l'instance sans qu'on le précise ?**  
Terraform construit un **graphe de dépendances** : l'instance référence `aws_security_group.bastion.id`, donc Terraform déduit automatiquement que le SG doit exister en premier.

**Q2 : Que se passerait-il avec ["0.0.0.0/0"] ?**  
Le port SSH (22) serait ouvert à l'**internet entier** : la machine deviendrait immédiatement une cible pour les scanners automatiques et les attaques par force brute. À proscrire absolument.

---

## Partie 3 — Filtrage sortant : sous-réseau privé et NAT Gateway

**Q1 : Quelle adresse renvoie curl depuis l'instance privée ?**  
L'IP publique de la **NAT Gateway** (l'Elastic IP associée). Tout le trafic sortant de l'instance privée est traduit (NAT) derrière cette adresse partagée — l'instance elle-même n'a aucune IP publique.

**Q2 : Pourquoi la NAT Gateway doit être dans le sous-réseau public ?**  
La NAT Gateway a besoin d'une route vers l'**Internet Gateway** pour acheminer le trafic vers Internet. Seul un sous-réseau public dispose de cette route. Dans un sous-réseau privé, elle n'aurait aucune sortie.

---

## Partie 4 — Détection d'intrusion : sonde Suricata

**Q1 : Intérêt de user_data plutôt qu'une installation manuelle ?**  
La **reproductibilité** : chaque instance lancée avec ce code est configurée à l'identique, sans intervention manuelle. C'est le principe de l'infrastructure as code — on peut recréer l'environnement en une commande.

**Q2 : Suricata détecte ou bloque le ping ?**  
Ici Suricata est en mode **IDS (détection)** : il génère des alertes dans `eve.json` mais laisse passer le trafic.  
Un **IPS** (système de prévention) serait placé en coupure dans le flux réseau et pourrait **bloquer** le trafic en temps réel.

---

## Partie 6 — Livrable

**Pourquoi la data source garantit que le VPC par défaut ne sera jamais supprimé ?**  
Une `data source` n'est pas enregistrée dans le `terraform.tfstate` comme une ressource gérée : Terraform ne l'a pas créée, il ne la gère donc pas. La commande `terraform destroy` ne supprime que ce qui figure dans le state — le VPC par défaut n'y figure pas, il reste intact pour tous les étudiants.

---

## Commandes utilisées

```bash
# Initialiser et planifier
terraform init
terraform plan

# Déployer
terraform apply

# Connexion SSH au bastion
eval $(ssh-agent -s)
ssh-add C:/Users/xyzkj/Claude/aws-cli-v1/Terraform_ansible/Terraform/wendyam_junior-key
ssh -A -i C:/Users/xyzkj/Claude/aws-cli-v1/Terraform_ansible/Terraform/wendyam_junior-key ec2-user@<bastion_ip>

# Depuis le bastion → instance privée
ssh ec2-user@<private_ip>

# Vérifier la sortie Internet depuis le privé (renvoie l'IP de la NAT)
curl -s https://checkip.amazonaws.com

# Générer du trafic ICMP vers la sonde
ping -c 5 <sonde_private_ip>

# Lire les alertes Suricata (sur la sonde)
sudo tail -f /var/log/suricata/eve.json | grep TD2

# Détruire toutes les ressources
terraform destroy
```
