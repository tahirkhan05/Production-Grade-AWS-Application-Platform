# ==============================================================================
# AMAZON RDS (RELATIONAL DATABASE SERVICE) - MANAGED POSTGRESQL 16
# ==============================================================================
# Why managed RDS instead of installing Postgres manually on an EC2 server?
# 1. Automated Backups & Point-in-Time Recovery: AWS automatically backs up data daily.
# 2. Automated OS and Database Security Patching.
# 3. High Availability (Multi-AZ): Standby replica in another data center ready to take over.
# 4. Storage Encryption at rest using AWS KMS (AES-256).
# ==============================================================================

# Subnet Group: Places RDS inside our private, isolated database subnets
resource "aws_db_subnet_group" "rds" {
  name        = "${var.project_name}-db-subnet-group"
  subnet_ids  = aws_subnet.private_db[*].id
  description = "Subnet group for private PostgreSQL database"

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# The RDS PostgreSQL Database Instance
resource "aws_db_instance" "postgres" {
  identifier             = "${var.project_name}-postgres"
  engine                 = "postgres"
  engine_version         = "16.9"
  instance_class         = var.db_instance_class # Free-tier / lab friendly (db.t4g.micro)
  allocated_storage      = 20                    # 20 GB initial storage
  max_allocated_storage  = 50                    # Storage auto-scales up to 50 GB if disk fills
  storage_type           = "gp3"                 # General Purpose SSD (high performance)
  storage_encrypted      = true                  # Military-grade AES-256 encryption at rest
  publicly_accessible    = false                 # CRITICAL: NO public IP address!

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result # Cryptographically generated password

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period   = 7                      # Retain daily backups for 7 days
  backup_window             = "03:00-04:00"          # Perform daily backup during low-traffic window (UTC)
  maintenance_window        = "Mon:04:00-Mon:05:00"  # Weekly maintenance window for security patches
  auto_minor_version_upgrade = true
  skip_final_snapshot       = true                   # Allows clean teardown without creating a permanent snapshot
  deletion_protection       = false                  # Set to false for learning lab/portfolio; true in production

  tags = {
    Name = "${var.project_name}-postgres"
  }
}
