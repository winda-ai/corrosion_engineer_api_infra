# Reference Central Infrastructure outputs
data "terraform_remote_state" "central" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "central-infra/${var.environment}/${var.region}/terraform.tfstate"
    region = var.region
  }
}

# Get Route53 zone for subdomain DNS (if using subdomain routing)
data "aws_route53_zone" "selected" {
  count        = var.enable_subdomain_routing ? 1 : 0
  name         = var.route53_zone_name
  private_zone = false
}

locals {
  # Common tags
  common_tags = merge({
    Application = "corrosion-engineer-api"
    Environment = var.environment
    Repository  = var.repository
    CommitHash  = substr(var.commit_hash, 0, 5)
  }, var.tags)

  # Get all infrastructure from central
  vpc_id                = data.terraform_remote_state.central.outputs.vpc_id
  private_subnet_ids    = data.terraform_remote_state.central.outputs.private_subnet_ids
  ecs_cluster_id        = data.terraform_remote_state.central.outputs.ecs_cluster_id
  ecs_cluster_name      = data.terraform_remote_state.central.outputs.ecs_cluster_name
  ecs_security_group_id = data.terraform_remote_state.central.outputs.ecs_service_security_group_id
  https_listener_arn    = data.terraform_remote_state.central.outputs.https_listener_arn
  alb_dns_name          = data.terraform_remote_state.central.outputs.alb_dns_name
  alb_zone_id           = data.terraform_remote_state.central.outputs.alb_zone_id
  global_domain         = data.terraform_remote_state.central.outputs.global_domain_name
  regional_domain       = data.terraform_remote_state.central.outputs.regional_domain_name
  route53_zone_id       = data.terraform_remote_state.central.outputs.route53_zone_id

  # Service-specific naming
  name_prefix = "${var.name_prefix}-${var.environment}-${var.region}"

  # Subdomain FQDN (if using subdomain routing)
  subdomain_fqdn = var.enable_subdomain_routing ? "corrosion-engineer.${local.global_domain}" : null
}
