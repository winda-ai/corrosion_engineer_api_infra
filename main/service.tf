# ============================================================
# Target Group for ALB
# ============================================================
resource "aws_lb_target_group" "this" {
  name        = "${local.name_prefix_short}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-299"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tg"
  })
}

# ============================================================
# ALB Listener Rules (Choose ONE routing strategy)
# ============================================================

# Subdomain-Based Routing (optional, more isolation)
resource "aws_lb_listener_rule" "subdomain_based" {
  listener_arn = local.https_listener_arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    host_header {
      values = [local.subdomain_fqdn]
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-subdomain-rule"
  })
}

# ============================================================
# Route53 Record (only for subdomain routing)
# ============================================================
resource "aws_route53_record" "service" {
  zone_id = local.route53_zone_id
  name    = local.subdomain_fqdn
  type    = "A"

  # Latency-based routing for multi-region
  set_identifier = var.region
  latency_routing_policy {
    region = var.region
  }

  alias {
    name                   = local.alb_dns_name
    zone_id                = local.alb_zone_id
    evaluate_target_health = true
  }
}

# ============================================================
# IAM Roles
# ============================================================

# Task Execution Role (pull images, write logs)
resource "aws_iam_role" "task_execution" {
  name               = "${local.name_prefix}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow pulling from GHCR (if using private registry)
resource "aws_iam_role_policy" "github_pull" {
  name = "${local.name_prefix}-github-pull"
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
          "arn:aws:secretsmanager:${var.region}:*:secret:github_token_ecs*",
          "arn:aws:kms:${var.region}:*:key/*"
        ]
      }
    ]
  })
}

# Task Role (application runtime permissions)
resource "aws_iam_role" "task" {
  name               = "${local.name_prefix}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = local.common_tags
}

# Add application-specific permissions here
resource "aws_iam_role_policy" "task_policy" {
  name = "${local.name_prefix}-task-policy"
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

# ============================================================
# CloudWatch Log Group
# ============================================================
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 30
  tags              = merge(local.common_tags, { Name = "${local.name_prefix}-logs" })
}

# ============================================================
# ECS Task Definition
# ============================================================
resource "aws_ecs_task_definition" "app" {
  family                   = local.name_prefix
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.container_image
      essential = true

      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }

      environment = concat([
        { name = "ASPNETCORE_ENVIRONMENT", value = var.environment },
        { name = "PORT", value = tostring(var.container_port) }
      ], var.extra_env_vars)

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      # Use GitHub token secret for private registry
      repositoryCredentials = {
        credentialsParameter = "arn:aws:secretsmanager:${var.region}:304035490047:secret:github_token_ecs"
      }
    }
  ])

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-task" })
}

# ============================================================
# ECS Service
# ============================================================
resource "aws_ecs_service" "app" {
  name                    = "${local.name_prefix}-service"
  cluster                 = local.ecs_cluster_id
  task_definition         = aws_ecs_task_definition.app.arn
  desired_count           = var.desired_count
  enable_ecs_managed_tags = true
  enable_execute_command  = true
  force_new_deployment    = true

  # Use capacity provider strategy (Fargate Spot with Fargate fallback)
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
    base              = 0
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 0
    base              = 0
  }

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [local.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  lifecycle {
    ignore_changes = [desired_count] # Allow autoscaling to manage
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-service"
  })
}

# ============================================================
# Autoscaling
# ============================================================

# Autoscaling Target
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${local.ecs_cluster_name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# CPU-based Autoscaling
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${local.name_prefix}-cpu-scaling"
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

# ============================================================
# Scheduled Scaling (optional hibernation)
# ============================================================

# Scale down at night
resource "aws_appautoscaling_scheduled_action" "scale_down" {
  count              = var.enable_hibernation_schedule ? 1 : 0
  name               = "${local.name_prefix}-scale-down"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  schedule           = var.hibernation_start_cron

  scalable_target_action {
    min_capacity = var.hibernation_min_capacity
    max_capacity = var.hibernation_min_capacity
  }
}

# Scale up in morning
resource "aws_appautoscaling_scheduled_action" "scale_up" {
  count              = var.enable_hibernation_schedule ? 1 : 0
  name               = "${local.name_prefix}-scale-up"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  schedule           = var.hibernation_end_cron

  scalable_target_action {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }
}
