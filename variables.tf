variable "student_id" {
  description = "Numéro d'étudiant (0-99) — rend noms et CIDRs uniques"
  type        = number
}

variable "my_ip" {
  description = "Votre IP publique en /32 (curl https://checkip.amazonaws.com)"
  type        = string
}

variable "key_name" {
  description = "Nom de la paire de clés EC2 dans eu-west-3"
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC existant dans lequel déployer les ressources"
  type        = string
}

variable "subnet_public_id" {
  description = "ID du sous-réseau public en eu-west-3a (pour bastion, NAT, sonde)"
  type        = string
}
