# ==============================================================================
# AWS IAM (IDENTITY AND ACCESS MANAGEMENT): ROLES & POLICIES
# ==============================================================================
# Security Principle: Least Privilege
# Every AWS component should have ONLY the exact permissions it needs to do its job.
#
# ECS uses TWO distinct IAM roles:
# 1. Task Execution Role: Used by the underlying AWS ECS agent BEFORE the app starts
#    (to pull the Docker image from ECR, create CloudWatch logs, and fetch DB secrets).
# 2. Task Role: Used by the RUNNING Python application container to make AWS API calls.
# ==============================================================================

# 1. ECS Task Execution Role
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

  # Trust policy allowing the ECS service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS managed policy for standard ECS execution (ECR pull, CloudWatch logging)
resource "aws_iam_role_policy_attachment" "ecs_execution_standard" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom Least-Privilege Policy: Allows ECS Execution Role to decrypt DB password from Secrets Manager
resource "aws_iam_policy" "secrets_access" {
  name        = "${var.project_name}-secrets-policy"
  description = "Allows ECS Task Execution Role to read DB credentials from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_secrets" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# 2. ECS Task Role (Permissions for the application code itself)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}
