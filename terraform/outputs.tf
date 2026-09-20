output "alb_dns_name" {
  description = "Public DNS endpoint for the Application Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR Repository URL for Docker image push"
  value       = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  description = "Private RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "secrets_manager_arn" {
  description = "ARN of AWS Secrets Manager secret for Database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "cloudwatch_dashboard_url" {
  description = "URL to access the CloudWatch Operations Dashboard in AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
