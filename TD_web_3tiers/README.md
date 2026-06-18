# TD AWS — Application web 3-tiers avec Terraform

Déploiement d'une application d'inscription (signup) sur AWS selon une architecture
**3-tiers** (présentation / application / données), entièrement décrite en
**Infrastructure as Code** avec Terraform.

L'infrastructure réutilise un **VPC** et une **instance RDS PostgreSQL** déjà
existants (compte sandbox partagé entre étudiants) : Terraform les lit via des
*data sources* et **ne les crée pas**.

---

## 1. Architecture

```
                 Internet
                    │  HTTP :80
                    ▼
        ┌───────────────────────┐
        │   ALB PUBLIC          │  (internet-facing)
        │   td-alb-public       │
        └───────────┬───────────┘
                    │  :80
                    ▼
        ┌───────────────────────┐   Tier PRÉSENTATION
        │   EC2 WEB  (Flask)    │   Formulaire HTML d'inscription
        │   subnet privé "web"  │   web/web.py
        └───────────┬───────────┘
                    │  POST /api/signup  :80
                    ▼
        ┌───────────────────────┐
        │   ALB INTERNE         │  (internal = true, jamais exposé)
        │   td-alb-internal     │
        └───────────┬───────────┘
                    │  :80
                    ▼
        ┌───────────────────────┐   Tier APPLICATION
        │   EC2 APP  (Flask)    │   API REST + bcrypt + psycopg2
        │   subnet privé "app"  │   app/app.py
        └───────────┬───────────┘
                    │  PostgreSQL :5432
                    ▼
        ┌───────────────────────┐   Tier DONNÉES
        │   RDS PostgreSQL      │   instance existante (data source)
        │   td-ipssi-rds-v2     │   table : users_esso
        └───────────────────────┘
```

### Flux d'une inscription

1. L'utilisateur ouvre le formulaire servi par le **tier web** (via l'ALB public).
2. À la soumission, le tier web envoie un `POST /api/signup` (JSON) au **tier app**
   en passant par l'**ALB interne**.
3. Le tier app **valide** l'email, **hache** le mot de passe avec **bcrypt**, puis
   fait un `INSERT` **paramétré** (anti-injection SQL) dans **RDS**.
4. Réponses : `201` créé · `409` email déjà utilisé · `400` données invalides ·
   `500` erreur serveur.

### Sécurité — chaîne de Security Groups (moindre privilège)

Chaque tier n'accepte du trafic **que** du tier juste en amont :

| Security Group        | Entrée autorisée (port)        | Depuis                |
|-----------------------|--------------------------------|-----------------------|
| `td-alb-public-sg`    | 80                             | `0.0.0.0/0` (Internet)|
| `td-web-sg`           | 80                             | `td-alb-public-sg`    |
| `td-alb-internal-sg`  | 80                             | `td-web-sg`           |
| `td-app-sg`           | 80                             | `td-alb-internal-sg`  |
| `td-rds-sg`           | 5432                           | `td-app-sg`           |

Le mot de passe applicatif n'est **jamais stocké en clair** : seul le hash bcrypt
(`$2b$12$…`, 60 caractères) est enregistré en base.

---

## 2. Structure du projet

```
td-aws/
├── providers.tf          # Provider AWS (~> 5.0), région eu-west-3
├── variables.tf          # Variables (VPC/RDS existants, CIDRs, credentials)
├── terraform.tfvars      # Valeurs réelles (PAS le mot de passe — voir §4)
├── network.tf            # Subnets, NAT Gateway, tables de routage (VPC existant)
├── security.tf           # Les 5 Security Groups (chaîne moindre privilège)
├── data.tf               # Data source RDS existant
├── web_tier.tf           # ALB public + EC2 web + target group
├── app_tier.tf           # ALB interne + EC2 app + target group + AMI
├── outputs.tf            # site_url, rds_endpoint, internal_alb_dns
├── schema.sql            # Schéma de la table users_esso (référence)
├── web/
│   ├── web.py            # Frontend Flask (formulaire HTML)
│   └── user_data.sh.tpl  # Bootstrap EC2 web (cloud-init)
└── app/
    ├── app.py            # API REST Flask (bcrypt + psycopg2)
    └── user_data.sh.tpl  # Bootstrap EC2 app (cloud-init)
```

---

## 3. Prérequis

- **Terraform** ≥ 1.6
- **AWS CLI** v2 configuré (`aws configure`) avec accès au compte
- Un **VPC existant** (ici `vpc-0ebcdb39f7a526ef9`)
- Une **instance RDS PostgreSQL existante** (ici `td-ipssi-rds-v2`, base `mydb`)
- (Optionnel, pour les tests DB) **Docker** — pour lancer un client `psql`
  sans rien installer

---

## 4. Configuration

`terraform.tfvars` contient les identifiants de l'infra existante :

```hcl
aws_region             = "eu-west-3"
azs                    = ["eu-west-3a", "eu-west-3b"]
existing_vpc_id        = "vpc-0ebcdb39f7a526ef9"
existing_db_identifier = "td-ipssi-rds-v2"
db_name                = "mydb"
db_username            = "adminipssidb"

# CIDRs vérifiés libres dans le VPC partagé
public_subnet_cidrs = ["172.31.120.0/24", "172.31.121.0/24"]
web_subnet_cidrs    = ["172.31.130.0/24", "172.31.131.0/24"]
app_subnet_cidrs    = ["172.31.140.0/24", "172.31.141.0/24"]
data_subnet_cidrs   = ["172.31.150.0/24", "172.31.151.0/24"]
```

> ⚠️ **Le mot de passe RDS n'est JAMAIS écrit dans un fichier.**
> Il est fourni à Terraform via une variable d'environnement :
>
> **PowerShell**
> ```powershell
> $env:TF_VAR_db_password = "VotreMotDePasse"
> ```
> **Bash / Git Bash**
> ```bash
> export TF_VAR_db_password="VotreMotDePasse"
> ```

---

## 5. Déploiement

Toutes les commandes se lancent **depuis le dossier `td-aws/`**.

```bash
cd td-aws

# 1. Définir le mot de passe RDS (voir §4)
export TF_VAR_db_password="VotreMotDePasse"      # Git Bash
# $env:TF_VAR_db_password="VotreMotDePasse"      # PowerShell

# 2. Initialiser les providers
terraform init

# 3. Visualiser le plan
terraform plan

# 4. Appliquer
terraform apply        # ou: terraform apply -auto-approve
```

À la fin, Terraform affiche les **outputs** :

```
site_url         = "http://td-alb-public-XXXXXXXXX.eu-west-3.elb.amazonaws.com"
internal_alb_dns = "internal-td-alb-internal-XXXXXXXXX.eu-west-3.elb.amazonaws.com"
rds_endpoint     = "td-ipssi-rds-v2.clqqieekmedc.eu-west-3.rds.amazonaws.com"
```

> ⏱️ Après l'`apply`, attendre **2 à 3 minutes** : les instances exécutent leur
> script `user_data` (installation de Python/Flask/Gunicorn) puis le health check
> de l'ALB doit passer au vert avant que le site réponde.

### Récupérer l'URL à tout moment

```bash
terraform output site_url
```

---

## 6. Tester l'application

### a) Dans le navigateur

Ouvrir l'`site_url` et remplir le formulaire « Créer un compte ».

### b) En ligne de commande (curl)

```bash
URL=$(terraform output -raw site_url)

# 1. Le formulaire répond (doit renvoyer HTTP 200)
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$URL/"

# 2. Inscription (POST du formulaire)
curl -s -X POST "$URL/signup" \
  --data-urlencode "full_name=Jean Dupont" \
  --data-urlencode "email=jean.dupont@example.com" \
  --data-urlencode "password=MonMotDePasse123"
# -> page avec "Compte créé avec succès"

# 3. Même email à nouveau -> refus (doublon)
curl -s -X POST "$URL/signup" \
  --data-urlencode "full_name=Jean Dupont" \
  --data-urlencode "email=jean.dupont@example.com" \
  --data-urlencode "password=MonMotDePasse123"
# -> "Cet email est déjà utilisé."
```

### c) Vérifier la santé des cibles (target groups)

```bash
# Tier app
TG_APP=$(aws elbv2 describe-target-groups --names td-tg-app \
  --query "TargetGroups[0].TargetGroupArn" --output text)
aws elbv2 describe-target-health --target-group-arn "$TG_APP" \
  --query "TargetHealthDescriptions[*].{ID:Target.Id,State:TargetHealth.State}" --output table

# Tier web
TG_WEB=$(aws elbv2 describe-target-groups --names td-tg-web \
  --query "TargetGroups[0].TargetGroupArn" --output text)
aws elbv2 describe-target-health --target-group-arn "$TG_WEB" \
  --query "TargetHealthDescriptions[*].{ID:Target.Id,State:TargetHealth.State}" --output table
```

L'état attendu est `healthy`.

---

## 7. Se connecter à la base de données

L'instance RDS est dans le VPC mais **publiquement accessible** (`PubliclyAccessible = true`)
et son Security Group autorise le port 5432. On peut donc s'y connecter directement.

### Sans rien installer — via Docker

```bash
export PGPASSWORD="VotreMotDePasse"

docker run --rm -e PGPASSWORD="$PGPASSWORD" postgres:16 \
  psql -h td-ipssi-rds-v2.clqqieekmedc.eu-west-3.rds.amazonaws.com \
       -U adminipssidb -d mydb
```

### Avec un client psql déjà installé

```bash
export PGPASSWORD="VotreMotDePasse"
psql -h td-ipssi-rds-v2.clqqieekmedc.eu-west-3.rds.amazonaws.com \
     -U adminipssidb -d mydb
```

### Requêtes utiles

```sql
-- Lister nos inscriptions
SELECT id, email, full_name, created_at FROM users_esso ORDER BY id;

-- Vérifier que le mot de passe est bien haché en bcrypt (préfixe $2b$, longueur 60)
SELECT email, left(password_hash, 7) AS prefixe, length(password_hash) AS longueur
FROM users_esso;

-- Voir la structure de la table
\d users_esso
```

> 💡 La table `users_esso` est **créée automatiquement** au démarrage de l'API
> (fonction `init_db()` dans `app/app.py`). Le fichier `schema.sql` sert de
> référence ou de création manuelle si besoin :
> ```bash
> docker run --rm -i -e PGPASSWORD="$PGPASSWORD" postgres:16 \
>   psql -h td-ipssi-rds-v2.clqqieekmedc.eu-west-3.rds.amazonaws.com \
>        -U adminipssidb -d mydb < schema.sql
> ```

---

## 8. Choix techniques & contraintes du compte sandbox

Le compte étant **partagé entre étudiants**, plusieurs adaptations ont été nécessaires :

| Contrainte rencontrée                              | Solution appliquée                                                                 |
|----------------------------------------------------|------------------------------------------------------------------------------------|
| VPC et RDS déjà existants                           | Lecture via *data sources* (`aws_vpc`, `aws_db_instance`), aucune création         |
| CIDRs de subnets en conflit avec l'existant         | Plage dédiée `172.31.120-151.0/24` (vérifiée libre)                                 |
| Limite d'**Elastic IP** atteinte (14/14)            | **1 seule** NAT Gateway (au lieu d'une par AZ) + 1 table de routage privée partagée |
| Limite de **vCPU** atteinte (32)                    | **1 instance** par tier (`count = 1`) au lieu d'une par AZ                          |
| Table `users` partagée sans colonne `password_hash` | Table **dédiée `users_esso`** (avec `password_hash` + `email UNIQUE`)               |
| Pas de droit `rds:ModifyDBInstance`                 | Le SG existant du RDS autorisait déjà l'accès ; pas de modification nécessaire      |

### Revenir à la haute disponibilité multi-AZ

Si les limites du compte se libèrent, remettre une instance par zone de disponibilité :

- `web_tier.tf` : `aws_instance.web` et `aws_lb_target_group_attachment.web` → `count = length(var.azs)`
- `app_tier.tf` : `aws_instance.app` et `aws_lb_target_group_attachment.app` → `count = length(var.azs)`

Il faudra aussi (idéalement) repasser à **une NAT Gateway par AZ** avec une table de
routage privée par zone, ce qui nécessite des Elastic IP disponibles.

---

## 9. Détruire l'infrastructure

```bash
cd td-aws
export TF_VAR_db_password="VotreMotDePasse"   # requis même pour détruire
terraform destroy
```

> Le VPC et l'instance RDS étant des *data sources*, ils **ne sont pas détruits** :
> Terraform ne supprime que ce qu'il a créé (subnets, NAT, ALB, EC2, SG…).
> La table `users_esso` reste dans la base ; la supprimer manuellement si besoin :
> ```sql
> DROP TABLE IF EXISTS users_esso;
> ```

---

## 10. Dépannage (problèmes rencontrés et résolus)

| Symptôme                                   | Cause                                                                 | Correctif                                                            |
|--------------------------------------------|-----------------------------------------------------------------------|---------------------------------------------------------------------|
| `No configuration files`                   | Commande lancée hors du dossier                                       | `cd td-aws`                                                          |
| Nom de SG refusé                           | Un nom de SG ne peut pas commencer par `sg-`                          | Préfixe `td-…-sg`                                                    |
| Description de règle SG refusée            | Apostrophes/accents interdits dans les descriptions                  | Texte ASCII uniquement                                              |
| `AddressLimitExceeded` (EIP)               | Quota Elastic IP atteint                                              | 1 seule NAT Gateway                                                 |
| `VcpuLimitExceeded`                        | Quota vCPU (32) atteint                                               | `count = 1` par tier                                                |
| Cibles `unhealthy`, `502/504`             | `user_data` cassé : un commentaire contenait `${app_py}` → tout le code Python était injecté comme commandes bash | Suppression des commentaires contenant les variables de template   |
| `500` à l'inscription                      | Table partagée `users` sans colonne `password_hash`                  | Table dédiée `users_esso` (schéma correct)                          |

---

**Auteur :** Esso Atangana — TD Cloud AWS / Terraform
