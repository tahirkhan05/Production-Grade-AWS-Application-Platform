# ==============================================================================
# AWS NETWORKING: VPC, SUBNETS, ROUTE TABLES, INTERNET & NAT GATEWAYS
# ==============================================================================
# In cloud architecture, networking is the foundation of security and reliability.
#
# 1. VPC (Virtual Private Cloud): Your own private, isolated virtual data center in AWS.
# 2. Availability Zones (AZs): Physically separate, isolated data centers in a region
#    (e.g., us-east-1a and us-east-1b). If one data center experiences a flood or power
#    outage, our app continues running uninterrupted in the other AZ!
# 3. 3-Tier Subnet Strategy:
#    - Public Subnets: Connected directly to the Internet (holds the Load Balancer & NAT).
#    - Private App Subnets: Holds our ECS Fargate containers (NO public IP addresses).
#    - Isolated DB Subnets: Holds our PostgreSQL database (NO internet access at all).
# ==============================================================================

# Data Source: Automatically discovers what AZs are healthy and available in our region
data "aws_availability_zones" "available" {
  state = "available"
}

# The Virtual Private Cloud (VPC)
# CIDR 10.0.0.0/16 provides an IP address range from 10.0.0.0 to 10.0.255.255 (65,536 private IPs)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # Required for AWS services to give domain names to instances
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway (IGW)
# Think of this as the front door router connecting our VPC to the public world-wide web.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ------------------------------------------------------------------------------
# 1. PUBLIC SUBNETS (Multi-AZ: AZ-a & AZ-b)
# ------------------------------------------------------------------------------
# Why? The Application Load Balancer (ALB) must sit in public subnets so users on the
# internet can reach our website.
# - count = 2: Creates one subnet in AZ-1 and another in AZ-2.
# - map_public_ip_on_launch = true: Resources created here receive public IP addresses.
# ------------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index] # e.g. 10.0.1.0/24, 10.0.2.0/24
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

# ------------------------------------------------------------------------------
# 2. PRIVATE APPLICATION SUBNETS (Multi-AZ: AZ-a & AZ-b)
# ------------------------------------------------------------------------------
# Why? Our FastAPI application runs here. For security, these servers have ZERO public IPs.
# Hackers on the internet cannot scan or directly connect to these servers!
# ------------------------------------------------------------------------------
resource "aws_subnet" "private_app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index] # e.g. 10.0.11.0/24, 10.0.12.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-app-subnet-${count.index + 1}"
    Type = "Private-App"
  }
}

# ------------------------------------------------------------------------------
# 3. ISOLATED DATABASE SUBNETS (Multi-AZ: AZ-a & AZ-b)
# ------------------------------------------------------------------------------
# Why? The PostgreSQL database stores sensitive company data.
# These subnets have NO route to the internet gateway AND no route to NAT gateway.
# They are completely sealed and only reachable internally by our application tier.
# ------------------------------------------------------------------------------
resource "aws_subnet" "private_db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_cidrs[count.index] # e.g. 10.0.21.0/24, 10.0.22.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-db-subnet-${count.index + 1}"
    Type = "Isolated-DB"
  }
}

# ------------------------------------------------------------------------------
# NAT GATEWAY (Network Address Translation)
# ------------------------------------------------------------------------------
# How can our private ECS containers download Docker images or talk to AWS APIs
# if they don't have public IPs?
#
# Answer: A NAT Gateway!
# It lives in the Public Subnet with a static public IP (Elastic IP).
# When an ECS container wants to initiate an outbound connection to AWS ECR or CloudWatch,
# the traffic passes through the NAT Gateway. Inbound connections from the internet
# are blocked, but outbound connections are allowed.
# ------------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.project_name}-nat-gw"
  }
}

# ------------------------------------------------------------------------------
# ROUTE TABLES & ASSOCIATIONS
# ------------------------------------------------------------------------------
# Route Tables are the traffic rules for subnets telling packets where to go.

# 1. Public Route Table: Routes 0.0.0.0/0 (all internet traffic) to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 2. Private App Route Table: Routes 0.0.0.0/0 (outbound internet) through the NAT Gateway
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-app-rt"
  }
}

resource "aws_route_table_association" "private_app" {
  count          = 2
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app.id
}

# 3. Isolated DB Route Table: Only allows traffic inside the local VPC (Zero Internet Outbound)
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-db-rt"
  }
}

resource "aws_route_table_association" "private_db" {
  count          = 2
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db.id
}
