output "service_name" {
  description = "ECS Service name"
  value       = aws_ecs_service.app.name
}

output "service_id" {
  description = "ECS Service ID"
  value       = aws_ecs_service.app.id
}

output "task_definition_arn" {
  description = "ECS Task Definition ARN"
  value       = aws_ecs_task_definition.app.arn
}

output "target_group_arn" {
  description = "ALB Target Group ARN"
  value       = aws_lb_target_group.this.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.app.name
}

output "service_url" {
  description = "Service URL (depends on routing strategy)"
  value       = var.enable_subdomain_routing ? "https://${local.subdomain_fqdn}" : "https://${local.global_domain}${trimsuffix(var.api_path_prefix, "/*")}"
}

output "routing_strategy" {
  description = "Current routing strategy in use"
  value       = var.enable_subdomain_routing ? "subdomain-based" : "path-based"
}
