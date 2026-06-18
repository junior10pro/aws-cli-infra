variable "aws_region" {
  default = "eu-west-3"
}

variable "azs" {
  type    = list(string)
  default = ["eu-west-3a", "eu-west-3b"]
}

# ---------------------------------------------------------------
# VPC existant — fournir l'ID, pas le CIDR (on ne crée pas le VPC)
# ---------------------------------------------------------------
variable "existing_vpc_id" {
  description = "ID du VPC existant (ex: vpc-0abc1234def567890)"
  type        = string
}

# ---------------------------------------------------------------
# Subnets à créer dans le VPC existant
# Vérifier qu'ils ne chevauchent pas les subnets déjà présents !
# ---------------------------------------------------------------
variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs des subnets publics (un par AZ)"
  default     = ["172.31.48.0/24", "172.31.49.0/24"]
}

variable "web_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs des subnets privés tier web (un par AZ)"
  default     = ["172.31.64.0/24", "172.31.65.0/24"]
}

variable "app_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs des subnets privés tier app (un par AZ)"
  default     = ["172.31.80.0/24", "172.31.81.0/24"]
}

variable "data_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs des subnets privés tier data (un par AZ)"
  default     = ["172.31.96.0/24", "172.31.97.0/24"]
}

# ---------------------------------------------------------------
# RDS existant — identifiant de l'instance (pas de création)
# ---------------------------------------------------------------
variable "existing_db_identifier" {
  description = "Identifiant de l'instance RDS existante (ex: my-postgres-db)"
  type        = string
}

variable "db_username" {
  description = "Nom d'utilisateur PostgreSQL (doit correspondre à l'instance existante)"
  default     = "appuser"
}

variable "db_password" {
  description = "Mot de passe RDS — passer via TF_VAR_db_password, jamais en clair"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Nom de la base de données (doit correspondre à l'instance existante)"
  default     = "signupdb"
}
