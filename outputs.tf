output "bastion_ip" {
  description = "IP publique du bastion — point d'entrée SSH"
  value       = aws_instance.bastion.public_ip
}

output "sonde_public_ip" {
  description = "IP publique de la sonde Suricata"
  value       = aws_instance.sonde.public_ip
}

output "sonde_private_ip" {
  description = "IP privée de la sonde (pour le ping ICMP depuis le bastion)"
  value       = aws_instance.sonde.private_ip
}

# Outputs egress/nat désactivés — NAT Gateway impossible (5/5 EIPs prises)
