# Subnet group placing RDS in isolated private database subnets
resource "aws_db_subnet_group" "rds" {
  name        = "${var.project_name}-db-subnet-group"
  subnet_ids  = aws_subnet.private_db[*].id
  description = "Subnet group for private PostgreSQL database"

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Managed RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier             = "${var.project_name}-postgres"
  engine                 = "postgres"
  engine_version         = "16.9"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  max_allocated_storage  = 50
  storage_type           = "gp3"
  storage_encrypted      = true
  publicly_accessible    = false

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "Mon:04:00-Mon:05:00"
  auto_minor_version_upgrade = true
  skip_final_snapshot       = true
  deletion_protection       = false

  tags = {
    Name = "${var.project_name}-postgres"
  }
}
