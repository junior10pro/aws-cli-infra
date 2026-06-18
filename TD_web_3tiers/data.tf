# ---------------------------------------------------------------
# RDS EXISTANT — lecture seule via data source
# Terraform lit l'endpoint et les métadonnées sans toucher à l'instance
# ---------------------------------------------------------------
data "aws_db_instance" "postgres" {
  db_instance_identifier = var.existing_db_identifier
}

# Note : le sg-rds créé dans security.tf devra être attaché manuellement
# à l'instance RDS existante dans la console AWS (EC2 → Security Groups),
# ou via : aws rds modify-db-instance --db-instance-identifier <id>
#           --vpc-security-group-ids <sg-rds-id> --apply-immediately
