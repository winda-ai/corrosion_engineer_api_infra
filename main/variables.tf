# ============================================================
# Core Configuration
# ============================================================
variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "assume_role_arn" {
  description = "IAM role ARN to assume (used by GitHub Actions, leave empty for local development)"
  type        = string
  default     = "arn:aws:iam::304035490047:role/TerraformBackendRole"
}

variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
  default     = "corrosion-engineer"
}

# ============================================================
# Central Infrastructure Reference
# ============================================================
variable "terraform_state_bucket" {
  description = "S3 bucket where central infrastructure state is stored"
  type        = string
}

variable "route53_zone_name" {
  description = "Route53 hosted zone name (e.g., winda.ai)"
  type        = string
  default     = "winda.ai"
}

variable "listener_rule_priority" {
  description = "ALB listener rule priority (must be unique across all services, same across all regions)"
  type        = number
  default     = 100
}

variable "container_image" {
  description = "Fully qualified container image for the ASP.NET Core app (e.g., ghcr.io/org/repo:tag)"
  type        = string
}

variable "container_port" {
  description = "Application container port"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Path for ALB target group health check"
  type        = string
  default     = "/Health"
}

variable "desired_count" {
  description = "Initial desired task count"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Minimum number of tasks for autoscaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks for autoscaling"
  type        = number
  default     = 3
}

variable "cpu_target_utilization" {
  description = "Target CPU utilization percentage for scaling"
  type        = number
  default     = 80
}

# ============================================================
# Container Configuration
# ============================================================
variable "task_cpu" {
  description = "Task CPU units (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Task memory in MB"
  type        = number
  default     = 1024
}

variable "extra_env_vars" {
  description = "Additional environment variables for the ECS container (list of maps with name/value)"
  type        = list(object({ name = string, value = string }))
  default     = []
}

variable "use_fargate_spot" {
  description = "Use Fargate Spot for cost savings (can be interrupted)"
  type        = bool
  default     = true
}

variable "fargate_spot_percentage" {
  description = "Percentage of tasks to run on Spot (0-100). Remainder runs on on-demand Fargate"
  type        = number
  default     = 70
}

variable "enable_hibernation_schedule" {
  description = "Enable scheduled scaling to scale down during off-hours"
  type        = bool
  default     = false
}

variable "hibernation_start_cron" {
  description = "Cron expression for when to scale down (UTC). Example: 'cron(0 22 * * ? *)' = 10 PM UTC daily"
  type        = string
  default     = "cron(0 22 * * ? *)"
}

variable "hibernation_end_cron" {
  description = "Cron expression for when to scale back up (UTC). Example: 'cron(0 6 * * ? *)' = 6 AM UTC daily"
  type        = string
  default     = "cron(0 6 * * ? *)"
}

variable "hibernation_min_capacity" {
  description = "Minimum capacity during hibernation (set to 0 to fully stop)"
  type        = number
  default     = 0
}

# ============================================================
# Git & Tagging
# ============================================================
variable "repository" {
  description = "GitHub repository name"
  type        = string
  default     = "corrosion_engineer_api_infra"
}

variable "commit_hash" {
  description = "Git commit hash"
  type        = string
  default     = "local"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}