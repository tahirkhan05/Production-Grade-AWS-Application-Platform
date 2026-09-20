# System Architecture & Technical Specifications

## 1. Executive Summary
This architecture implements a highly available, fault-tolerant, and secure 3-tier cloud application platform deployed on Amazon Web Services (AWS) using Terraform (Infrastructure as Code).

![Architecture Diagram](architecture.png)

---

## 2. Network Topology & Traffic Flow

### A. Public Subnets (Edge Tier)
- **Availability Zones:** Multi-AZ (AZ-a and AZ-b)
- **Components:** Application Load Balancer (ALB), NAT Gateway, Elastic IP.
- **Routing:** Direct route to AWS Internet Gateway (`0.0.0.0/0 -> igw`).
- **Security Group:** Ingress allowed on Port 80 (HTTP) / 443 (HTTPS) from any client (`0.0.0.0/0`).

### B. Private Application Subnets (Compute Tier)
- **Availability Zones:** Multi-AZ (AZ-a and AZ-b)
- **Components:** AWS ECS Fargate Tasks running containerized FastAPI REST services.
- **Routing:** Outbound internet traffic routed through the **NAT Gateway** in Public Subnet 1 (`0.0.0.0/0 -> nat-gw`). No inbound traffic from internet directly.
- **Security Group:** Ingress restricted strictly to Port 8000 from the ALB Security Group.

### C. Isolated Database Subnets (Data Tier)
- **Availability Zones:** Multi-AZ (AZ-a and AZ-b)
- **Components:** Amazon RDS PostgreSQL 16 managed database with encrypted storage (`gp3`).
- **Routing:** Local VPC routing only. **Zero outbound or inbound internet access**.
- **Security Group:** Ingress restricted strictly to Port 5432 from the ECS Application Security Group.

---

## 3. Security & Compliance Controls
1. **Network Isolation:** Compute and database tiers reside in private/isolated subnets without public IPs.
2. **Strict Security Groups:** Layered security groups enforce the principle of least privilege.
3. **Secrets Management:** Database master passwords are cryptographically generated and stored in **AWS Secrets Manager**, dynamically injected into ECS containers at launch.
4. **IAM Least Privilege:** Dedicated ECS Task Execution Role with granular IAM permissions for ECR, CloudWatch, and Secrets Manager.
5. **Non-Root Containers:** Dockerfile configures a dedicated non-root user (`appuser`, UID 1001) for runtime security.
