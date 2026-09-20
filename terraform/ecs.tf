# ==============================================================================
# AWS ECS FARGATE: SERVERLESS CONTAINER ORCHESTRATION
# ==============================================================================
# What is ECS and Fargate?
# - ECS (Elastic Container Service): AWS's container management service (like Kubernetes,
#   but native to AWS). It handles starting, stopping, health checking, and scaling containers.
# - Fargate (Serverless Compute Engine): Instead of renting and patching physical Linux
#   virtual machines (EC2), Fargate lets you run containers directly without managing servers!
#   AWS provisions the exact CPU and Memory needed on demand.
# ==============================================================================

# 1. CloudWatch Log Group: Centralized logging for all application container logs
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7 # Automatically delete logs after 7 days to save costs

  tags = {
    Name = "${var.project_name}-logs"
  }
}

# 2. ECS Cluster: Logical grouping of services and tasks
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # Enables detailed CloudWatch metrics (CPU, Memory, Network)
  }
}

# 3. ECS Task Definition: The blueprint for running our container
# Defines: How much CPU/RAM to allocate, which Docker image to pull, what environment
# variables to set, and what secrets to fetch from AWS Secrets Manager.
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"       # Each task gets its own private Elastic Network Interface (ENI)
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu   # 256 units = 0.25 vCPU
  memory                   = var.fargate_memory# 512 MB RAM
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true # If this container stops, the entire task is marked stopped
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port
          protocol      = "tcp"
        }
      ]
      # Non-sensitive configuration passed as plain environment variables
      environment = [
        { name = "APP_ENV", value = var.environment },
        { name = "DB_HOST", value = aws_db_instance.postgres.address },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USER", value = var.db_username }
      ]
      # SENSITIVE CREDENTIALS: dynamically injected from AWS Secrets Manager at container launch!
      # Notice how the database password is NEVER in plaintext here or in Git!
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::"
        }
      ]
      # Forward container stdout/stderr logs directly into AWS CloudWatch
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])
}

# 4. ECS Service: The supervisor that keeps our containers running 24/7
# It guarantees that exactly 'desired_count' (2) instances of our task are healthy across AZs.
# If a container crashes, ECS automatically restarts it!
resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private_app[*].id # Placed in private subnets across AZ-a and AZ-b
    security_groups  = [aws_security_group.ecs_app.id]
    assign_public_ip = false                       # Secure: NO public IP
  }

  # Connects the containers directly to our Application Load Balancer
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.app_port
  }

  # Deployment Circuit Breaker:
  # If a new version of our code fails to boot up or pass health checks during a deployment,
  # AWS automatically cancels the rollout and rolls back to the previous stable version!
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_execution_standard
  ]
}

# ------------------------------------------------------------------------------
# AUTO SCALING (Target Tracking on CPU Utilization)
# ------------------------------------------------------------------------------
# Automatically adds more containers when traffic surges, and removes them when traffic drops!
# ------------------------------------------------------------------------------

# Define the scaling boundaries (Min 2 tasks, Max 4 tasks)
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Target Tracking Policy: Maintain average cluster CPU utilization around 70%
# If CPU goes above 70%, add tasks. If CPU drops below 70%, remove extra tasks.
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  name               = "${var.project_name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0 # Target 70% CPU
    scale_in_cooldown  = 60   # Wait 60s before removing a task
    scale_out_cooldown = 60   # Wait 60s before adding another task
  }
}
