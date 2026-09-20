# ==============================================================================
# AWS SECRETS MANAGER: ENTERPRISE SECRETS MANAGEMENT
# ==============================================================================
# Rule #1 of Cloud Security: NEVER commit database passwords into Git or source code!
#
# How this works:
# 1. Terraform generates a cryptographically random 24-character password.
# 2. It creates an AWS Secrets Manager secret object encrypted with KMS.
# 3. When the ECS Fargate container starts, AWS ECS fetches the secret and injects
#    it into the container memory as the environment variable 'DB_PASSWORD'.
# ==============================================================================

# Generates a random 24-character secure password
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Creates the Secret Container in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-db-secret-${random_password.db_password.result != "" ? "prod" : ""}"
  description             = "Production Database credentials managed by Terraform"
  recovery_window_in_days = 0 # Immediate deletion on destroy for clean lab teardown

  tags = {
    Name = "${var.project_name}-db-secret"
  }
}

# Stores the database username, password, host, and port as a JSON string inside the secret
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    dbname   = var.db_name
    port     = 5432
  })
}
