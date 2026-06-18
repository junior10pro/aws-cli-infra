output "site_url" {
  description = "URL publique de l'application (formulaire d'inscription)"
  value       = "http://${aws_lb.public.dns_name}"
}

output "rds_endpoint" {
  description = "Endpoint RDS pour appliquer schema.sql (depuis un bastion ou SSM)"
  value       = data.aws_db_instance.postgres.address
}

output "internal_alb_dns" {
  description = "DNS de l'ALB interne (joignable uniquement depuis le VPC)"
  value       = aws_lb.internal.dns_name
}
