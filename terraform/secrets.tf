# Generate cryptographically secure random password for RDS
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store database credentials securely in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-db-secret-${random_password.db_password.result != "" ? "prod" : ""}"
  description             = "Production Database credentials managed by Terraform"
  recovery_window_in_days = 0 # Immediate deletion on destroy for lab/testing

  tags = {
    Name = "${var.project_name}-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    dbname   = var.db_name
    port     = 5432
  })
}
