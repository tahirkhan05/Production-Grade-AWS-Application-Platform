# ==============================================================================
# AWS APPLICATION LOAD BALANCER (ALB)
# ==============================================================================
# What does a Load Balancer do?
# 1. Single Entry Point: Provides one stable public DNS address (URL) for the entire app.
# 2. Traffic Distribution: Spreads incoming user traffic evenly across all backend containers.
# 3. Health Checks: Periodically checks /health. If a container crashes, ALB stops sending
#    traffic to it instantly, routing requests only to healthy containers.
# 4. Zero-Downtime Deployments: During updates, routes traffic to new containers only after
#    they have passed health checks.
# ==============================================================================

# Public Application Load Balancer sitting in our Public Subnets across Multi-AZ
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false # Public-facing on the internet
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group: The collection of backend targets (ECS Fargate task IPs) receiving traffic
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # 'ip' target type is required for AWS ECS Fargate tasks

  # Automated Health Check Configuration:
  # - path = "/health": Sends HTTP GET /health to the container
  # - matcher = "200": Requires HTTP status code 200 OK
  # - interval = 15: Check every 15 seconds
  # - timeout = 5: Fail if response takes longer than 5 seconds
  # - healthy_threshold = 2: Requires 2 consecutive successes to mark a container healthy
  # - unhealthy_threshold = 3: Marks container dead after 3 consecutive failures
  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = var.app_port
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# ALB HTTP Listener: Listens on Port 80 and forwards requests to our Target Group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
