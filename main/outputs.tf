output "vpc_id" {
  description = "ID of the created VPC"
  value       = data.aws_vpc.main.id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.app.arn
}

output "service_name" {
  description = "ECS Service name"
  value       = aws_ecs_service.app.name
}

output "task_definition_arn" {
  description = "ECS Task Definition ARN"
  value       = aws_ecs_task_definition.app.arn
}

output "route53_record_fqdn" {
  description = "Fully qualified domain name of the Route53 record"
  value       = aws_route53_record.alb.fqdn
}
