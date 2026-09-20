variable "aws_region" {
  type        = string
  description = "AWS region for provisioning resources"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "production"
}

variable "project_name" {
  type        = string
  description = "Project name prefix used for resource tagging and naming"
  default     = "cloud-app-platform"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets (ALB, NAT Gateway)"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private application subnets (ECS Tasks)"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for isolated database subnets (RDS PostgreSQL)"
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "db_name" {
  type        = string
  description = "Name of the default PostgreSQL database"
  default     = "appdb"
}

variable "db_username" {
  type        = string
  description = "Master username for RDS PostgreSQL"
  default     = "dbadmin"
}

variable "db_instance_class" {
  type        = string
  description = "Database instance size class"
  default     = "db.t4g.micro"
}

variable "app_count" {
  type        = number
  description = "Number of ECS task replicas for high availability"
  default     = 2
}

variable "app_port" {
  type        = number
  description = "Container application listening port"
  default     = 8000
}

variable "fargate_cpu" {
  type        = string
  description = "Fargate task CPU units (256 = 0.25 vCPU)"
  default     = "256"
}

variable "fargate_memory" {
  type        = string
  description = "Fargate task Memory in MB"
  default     = "512"
}
