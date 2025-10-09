variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Prefix to use for naming AWS resources (replaces using environment as the name root)"
  type        = string
  default     = "ce"
}
variable "ecs_cluster_name" {
  description = "Name of the existing ECS Cluster to deploy the service into"
  type        = string
  default     = "central"
}

variable "vpc_id" {
  description = "ID of the existing VPC to deploy resources into"
  type        = string
  default     = "vpc-0bb1c79de3EXAMPLE"
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs in the VPC for ALB"
  type        = list(string)
  default     = ["subnet-0bb1c79de3EXAMPLE", "subnet-0bb1c79de3EXAMPLE"]
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs in the VPC for ECS tasks"
  type        = list(string)
  default     = ["subnet-0bb1c79de3EXAMPLE", "subnet-0bb1c79de3EXAMPLE"]
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

variable "zone_id" {
  description = "Existing public Route53 Hosted Zone ID (record will always be created)"
  type        = string
  default     = "Z045078216NP3O5K1Q0OY"
}

variable "subdomain" {
  description = "Subdomain to create (e.g., api)"
  type        = string
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

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

locals {
  common_tags = merge({
    Application = "corrosion-engineer-api"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Prefix      = var.name_prefix
  }, var.tags)
}