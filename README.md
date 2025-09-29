# Corrosion Engineer API Infrastructure (Terraform)

Infrastructure-as-Code for deploying a stateless ASP.NET Core application to AWS using ECS Fargate behind an Application Load Balancer, with Route53 DNS, autoscaling, and CloudWatch logging.

## Features
- VPC with public & private subnets across 2 AZs
- NAT Gateway for private egress, Internet Gateway for ALB
- ECS Cluster (Fargate) + Service + Task Definition (0.5 vCPU / 1GB)
- Application Load Balancer (HTTP + optional HTTPS)
- Route53 A Alias record for custom subdomain
- Autoscaling (Target tracking on CPU)
- CloudWatch log group w/ retention
- IAM roles (task execution + task role)
- Consistent tagging with prefix and environment

## File Layout
```
main/
  backend.tf        # Remote state backend (configured via CLI/backend.conf)
  provider.tf       # AWS provider config
  versions.tf       # Terraform + provider versions
  variables.tf      # Input variables and common tags
  main.tf           # Core infrastructure resources
  outputs.tf        # Exported values
```

## Prerequisites
- Terraform >= 1.7.0
- Existing AWS account + credentials (e.g., via `aws configure` or env vars)
- Existing public Route53 hosted zone (zone ID)
- Existing ACM certificate in same region for HTTPS (optional)
- Container image published to a registry (e.g., GitHub Container Registry)

## Required Inputs
| Variable      | Description | Example |
|---------------|-------------|---------|
| `zone_id`     | Public Route53 hosted zone ID | `Z0123456789ABC` |
| `container_image` | FQ image ref | `ghcr.io/acme/corrosion-api:1.0.0` |

## Common Optional Inputs
| Variable | Default | Purpose |
|----------|---------|---------|
| `name_prefix` | `ce` | Resource name base |
| `environment` | `dev` | Tagging / env context |
| `subdomain` | `api` | DNS record prefix |
| `enable_https` | `true` | Create HTTPS listener if cert provided |
| `acm_certificate_arn` | `` | ACM cert ARN |
| `cpu_target_utilization` | `80` | Autoscaling target |

See `variables.tf` for full list.

## Example terraform.tfvars
```hcl
name_prefix          = "ce-dev"
environment          = "dev"
zone_id              = "Z0123456789ABC"
subdomain            = "api"
container_image      = "ghcr.io/acme/corrosion-api:1.0.0"
acm_certificate_arn  = "arn:aws:acm:us-east-1:123456789012:certificate/uuid"
log_retention_days   = 30
cpu_target_utilization = 70
min_capacity         = 1
max_capacity         = 3
```

## Usage
```bash
terraform init 
terraform plan -out plan.tfplan
terraform apply "plan.tfplan"
```

To destroy:
```bash
terraform destroy
```

## Outputs
- `alb_dns_name`
- `route53_record_fqdn`
- `cluster_name`
- `service_name`
- `task_definition_arn`
- `vpc_id`

## Updating the Service
Updating just the container image:
1. Update `container_image` variable/tag
2. Run `terraform apply` (new task definition revision will register; service will deploy it)

## HTTPS Notes
- If `enable_https` is true but `acm_certificate_arn` is empty, only HTTP listener is created.
- Certificate must be in the same AWS region as the ALB.

## Scaling
Target tracking on average CPU. Adjust `cpu_target_utilization`, `min_capacity`, and `max_capacity` to tune behavior. Add memory or request-based policies by extending `main.tf`.

## Logging
Container stdout/stderr sent to CloudWatch Logs under `/ecs/<name_prefix>/corrosion-engineer-api` with retention configured via `log_retention_days`.

## Conventions
- All names prefixed with `name_prefix` for easier multi-env deployments in one account.
- `environment` used strictly for tagging and runtime environment variable inside the container.

## Future Enhancements (Ideas)
- Add WAFv2 ACL association
- Add secret management (SSM Parameter Store / Secrets Manager)
- Add CI/CD pipeline example (GitHub Actions)
- Add HTTPS redirect (listener rule) to force TLS

## License
Internal / Proprietary (adjust as appropriate).
