///////////////////////////////////////////////
// Networking: VPC, Subnets, Routing, SGs
///////////////////////////////////////////////

# Fetch available AZs (limit to 2 for cost) 
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${var.name_prefix}-vpc" })
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${var.name_prefix}-igw" })
}

# Public Subnets
resource "aws_subnet" "public" {
  for_each                = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = local.azs[tonumber(each.key)]
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Name = "${var.name_prefix}-public-${each.key}", Tier = "public" })
}

# Private Subnets
resource "aws_subnet" "private" {
  for_each          = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = local.azs[tonumber(each.key)]
  tags              = merge(local.common_tags, { Name = "${var.name_prefix}-private-${each.key}", Tier = "private" })
}

# Elastic IP for NAT
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${var.name_prefix}-nat-eip" })
}

# NAT Gateway in first public subnet
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id
  tags          = merge(local.common_tags, { Name = "${var.name_prefix}-nat" })
  depends_on    = [aws_internet_gateway.igw]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(local.common_tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${var.name_prefix}-private-rt" })
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

///////////////////////////////////////////////
// Security Groups
///////////////////////////////////////////////

# ALB Security Group (allow HTTP/HTTPS from anywhere)
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "HTTP from internet"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTPS from internet"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-alb-sg" })
}

# ECS Tasks Security Group (allow inbound only from ALB)
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.name_prefix}-ecs-tasks-sg"
  description = "ECS tasks security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-ecs-tasks-sg" })
}

///////////////////////////////////////////////
// IAM Roles & Policies
///////////////////////////////////////////////

# Task execution role (pull image, write logs)
resource "aws_iam_role" "task_execution" {
  name               = "${var.name_prefix}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume.json
  tags               = local.common_tags
}

# Allow ECS to pull private images from GHCR using github_token secret
resource "aws_iam_role_policy" "task_execution_github_pull" {
  name = "${var.name_prefix}-ecs-ghcr-pull"
  role = aws_iam_role.task_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = [
          "arn:aws:secretsmanager:us-east-1:304035490047:secret:github_token_ecs*",
          "arn:aws:kms:us-east-1:*:key/*"
        ]
      }
    ]
  })
}

data "aws_iam_policy_document" "task_execution_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Attach AWS managed policies for ECS task execution
resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role (application specific least privilege - minimal placeholder)
resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume.json
  tags               = local.common_tags
}

# Optional inline policy example (adjust as needed)
resource "aws_iam_role_policy" "task_inline" {
  name = "${var.name_prefix}-task-inline"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

///////////////////////////////////////////////
// CloudWatch Log Group
///////////////////////////////////////////////

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name_prefix}/corrosion-engineer-api"
  retention_in_days = 30
  tags              = merge(local.common_tags, { Name = "${var.name_prefix}-app-log-group" })
}

///////////////////////////////////////////////
// ECS Cluster & Task Definition
///////////////////////////////////////////////

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-corrosion-engineer-api-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = merge(local.common_tags, { Name = "${var.name_prefix}-ecs-cluster" })
}

# Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-corrosion-engineer-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"  # 0.5 vCPU
  memory                   = "1024" # 1GB
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = concat([
        { name = "ASPNETCORE_ENVIRONMENT", value = var.environment },
        { name = "PORT", value = tostring(var.container_port) }
      ], var.extra_env_vars)
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
      repositoryCredentials = {
        credentialsParameter = "arn:aws:secretsmanager:us-east-1:304035490047:secret:github_token_ecs"
      }
    }
  ])

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-task-def" })
}

///////////////////////////////////////////////
// Application Load Balancer & Target Group
///////////////////////////////////////////////

resource "aws_lb" "app" {
  name               = "${var.name_prefix}-ce-api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for s in aws_subnet.public : s.id]
  idle_timeout       = 60
  tags               = merge(local.common_tags, { Name = "${var.name_prefix}-alb" })
}

resource "aws_lb_target_group" "app" {
  name        = "${var.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id
  health_check {
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
  tags = merge(local.common_tags, { Name = "${var.name_prefix}-tg" })
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# HTTPS Listener (optional)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.this.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

///////////////////////////////////////////////
// ECS Service with Autoscaling
///////////////////////////////////////////////

# Fargate Spot Capacity Provider
resource "aws_ecs_capacity_provider" "fargate_spot" {
  count = var.use_fargate_spot ? 1 : 0
  name  = "${var.name_prefix}-fargate-spot"

  auto_scaling_group_provider {
    auto_scaling_group_arn = ""
  }
}

# Cluster Capacity Providers (Spot + On-Demand)
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = var.use_fargate_spot ? ["FARGATE_SPOT", "FARGATE"] : ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"
    weight            = var.use_fargate_spot ? var.fargate_spot_percentage : 100
    base              = 0
  }

  dynamic "default_capacity_provider_strategy" {
    for_each = var.use_fargate_spot && var.fargate_spot_percentage < 100 ? [1] : []
    content {
      capacity_provider = "FARGATE"
      weight            = 100 - var.fargate_spot_percentage
      base              = 0
    }
  }
}

resource "aws_ecs_service" "app" {
  name                   = "${var.name_prefix}-corrosion-engineer-api-service"
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.app.arn
  desired_count          = var.desired_count
  enable_execute_command = true

  # Use capacity provider strategy instead of launch_type
  dynamic "capacity_provider_strategy" {
    for_each = var.use_fargate_spot ? [1] : []
    content {
      capacity_provider = "FARGATE_SPOT"
      weight            = var.fargate_spot_percentage
      base              = 0
    }
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.use_fargate_spot && var.fargate_spot_percentage < 100 ? [1] : []
    content {
      capacity_provider = "FARGATE"
      weight            = 100 - var.fargate_spot_percentage
      base              = 0
    }
  }

  # Fallback to on-demand if spot disabled
  launch_type = var.use_fargate_spot ? null : "FARGATE"

  network_configuration {
    subnets          = [for s in aws_subnet.private : s.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  lifecycle {
    ignore_changes = [desired_count] # managed by autoscaling
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  depends_on = [aws_lb_listener.http, aws_ecs_cluster_capacity_providers.this]

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-ecs-service" })
}

# Application Autoscaling target
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# CPU Utilization Policy
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name_prefix}-cpu-scale-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_utilization
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

# Scheduled Scaling for Hibernation (optional cost savings)
resource "aws_appautoscaling_scheduled_action" "scale_down" {
  count              = var.enable_hibernation_schedule ? 1 : 0
  name               = "${var.name_prefix}-scale-down-night"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  schedule           = var.hibernation_start_cron

  scalable_target_action {
    min_capacity = var.hibernation_min_capacity
    max_capacity = var.hibernation_min_capacity
  }
}

resource "aws_appautoscaling_scheduled_action" "scale_up" {
  count              = var.enable_hibernation_schedule ? 1 : 0
  name               = "${var.name_prefix}-scale-up-morning"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  schedule           = var.hibernation_end_cron

  scalable_target_action {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }
}

///////////////////////////////////////////////
// Route53 DNS Record (always provisioned)
///////////////////////////////////////////////

data "aws_route53_zone" "selected" {
  zone_id      = var.zone_id
  private_zone = false
}

locals {
  fqdn = "${var.subdomain}.${chomp(trimsuffix(data.aws_route53_zone.selected.name, "."))}"
}

resource "aws_route53_record" "alb" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = local.fqdn
  type    = "A"
  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}

///////////////////////////////////////////////
// ACM Certificate
///////////////////////////////////////////////


resource "aws_acm_certificate" "this" {
  domain_name       = local.fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn = aws_acm_certificate.this.arn
  timeouts {
    create = "10m"
  }
}

resource "time_sleep" "wait_30_seconds_for_certification_validation" {
  depends_on      = [aws_acm_certificate.this]
  create_duration = "30s"
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.selected.zone_id
} 