# ==============================================================================
# AWS SECURITY GROUPS (VIRTUAL FIREWALLS)
# ==============================================================================
# Security Groups act as stateful firewalls controlling inbound (ingress) and
# outbound (egress) network traffic at the resource level.
#
# Best Practice: "Defense-in-Depth" & "Least Privilege"
# Instead of opening ports to all IP addresses, we chain security groups together!
# Internet -> ALB SG (port 80) -> ECS SG (port 8000) -> RDS SG (port 5432)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Application Load Balancer Security Group
# ------------------------------------------------------------------------------
# - INGRESS: Allows public HTTP traffic (Port 80) from anywhere in the world (0.0.0.0/0).
# - EGRESS: Allows outbound traffic to forward user requests to our ECS containers.
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for internet-facing Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic to private app tier"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ------------------------------------------------------------------------------
# 2. ECS Fargate Application Security Group
# ------------------------------------------------------------------------------
# - INGRESS: Allows Port 8000 STRICTLY from the ALB Security Group (security_groups = [aws_security_group.alb.id]).
#   Even if a computer inside the VPC tries to connect on port 8000, it is rejected unless
#   it comes from the ALB!
# - EGRESS: Allows outbound traffic (to pull images from ECR, reach Secrets Manager, and talk to RDS).
# ------------------------------------------------------------------------------
resource "aws_security_group" "ecs_app" {
  name        = "${var.project_name}-ecs-app-sg"
  description = "Security group for ECS tasks - only accepts traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow traffic from ALB on app port"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound (ECR pulls, AWS APIs, DB connection)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-app-sg"
  }
}

# ------------------------------------------------------------------------------
# 3. RDS PostgreSQL Database Security Group
# ------------------------------------------------------------------------------
# - INGRESS: Allows PostgreSQL Port 5432 STRICTLY from the ECS App Security Group.
#   Nobody on the internet, and no other service in the cloud, can talk to PostgreSQL!
# - EGRESS: Databases don't need to initiate outbound connections, so this is minimal.
# ------------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS PostgreSQL - only accepts traffic from ECS App SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow PostgreSQL access strictly from ECS App SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_app.id]
  }

  egress {
    description = "No outbound rules required for DB"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}
