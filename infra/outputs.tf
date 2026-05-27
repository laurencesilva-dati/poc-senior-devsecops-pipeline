output "sonarqube_url" {
  description = "URL do SonarQube"
  value       = "http://${aws_instance.sonarqube.public_ip}:9000"
}

output "grafana_url" {
  description = "URL do Grafana (instancia dedicada)"
  value       = "http://${aws_instance.grafana.public_ip}:3000"
}

output "app_staging_url" {
  description = "URL da aplicação staging"
  value       = "http://${aws_instance.app_staging.public_ip}:3000"
}

output "app_prod_url" {
  description = "URL da aplicação prod"
  value       = "http://${aws_instance.app_prod.public_ip}:3000"
}

output "rds_staging_endpoint" {
  description = "Endpoint do RDS staging"
  value       = aws_db_instance.staging.address
}

output "rds_prod_endpoint" {
  description = "Endpoint do RDS prod"
  value       = aws_db_instance.prod.address
}

output "sonarqube_instance_id" {
  description = "ID da instância EC2 do SonarQube"
  value       = aws_instance.sonarqube.id
}
