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

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks (must span at least 2 AZs)"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks (must span at least 2 AZs)"
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "container_image" {
  description = "Fully qualified container image for the ASP.NET Core app (e.g., ghcr.io/org/repo:tag)"
  type        = string
}

variable "container_port" {
  description = "Application container port"
  type        = number
  default     = 80
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
  default     = "api"
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