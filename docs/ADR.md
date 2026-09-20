# Architecture Decision Records (ADRs)

## ADR 001: Container Orchestration - AWS ECS Fargate over EC2
- **Status:** Accepted
- **Context:** The application requires scalable, high-availability compute without operational overhead of OS patching, AMI maintenance, and EC2 capacity planning.
- **Decision:** Use **AWS ECS Fargate** (Serverless containers).
- **Consequences:** Eliminates server administration overhead, provides seamless scaling, native CloudWatch Container Insights, and sub-minute task launches.

## ADR 002: Network Topology - 3-Tier Multi-AZ VPC
- **Status:** Accepted
- **Context:** Enterprise security standards require complete isolation of data and application tiers from the public internet.
- **Decision:** Partition the VPC into Public, Private App, and Isolated Database subnets across 2 Availability Zones.
- **Consequences:** Maximizes resilience against single-datacenter failure while ensuring database has zero direct internet exposure.

## ADR 003: Secrets Management - AWS Secrets Manager
- **Status:** Accepted
- **Context:** Hardcoded credentials or plain environment variables in source code violate security compliance.
- **Decision:** Integrate **AWS Secrets Manager** with Terraform `random_password` generator and dynamic ECS injection.
- **Consequences:** Credentials are encrypted at rest with KMS, never committed to git, and can be rotated without codebase changes.
