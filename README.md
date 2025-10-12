# Corrosion Engineer API Infrastructure

**ECS Fargate deployment that integrates with central infrastructure.**

## What This Does

Deploys the Corrosion Engineer API as an ECS Fargate service that:
- ✅ Uses shared VPC, ALB, and ECS cluster from **central_infra**
- ✅ Automatic HTTPS with wildcard certificate
- ✅ Multi-region support with latency-based DNS routing
- ✅ Autoscaling based on CPU utilization
- ✅ Optional cost-saving hibernation schedule

---

## Quick Start

### 1. Update Configuration

Edit `workspace/dev/us-east-1/terraform.tfvars`:

```hcl
terraform_state_bucket = "your-terraform-state-bucket"  # REQUIRED: Your S3 bucket name
listener_rule_priority = 100                            # REQUIRED: Unique number per service
```

### 2. Deploy

```bash
make init ENV=dev REGION=us-east-1
make apply ENV=dev REGION=us-east-1
```

### 3. Access Your Service

**Path-Based (default):**
```
https://dev.winda.ai/api/corrosion-engineer/your-endpoint
```

**Subdomain-Based (optional):**
```
https://corrosion-engineer.dev.winda.ai/your-endpoint
```

---

## Routing Options

### Option A: Path-Based (Recommended)

**Simpler setup, no DNS configuration needed**

```hcl
# In terraform.tfvars
enable_subdomain_routing = false
api_path_prefix          = "/api/corrosion-engineer/*"
listener_rule_priority   = 100
```

Access: `https://dev.winda.ai/api/corrosion-engineer/*`

✅ No DNS records needed  
✅ Certificate already covers this  
✅ Simpler setup

---

### Option B: Subdomain-Based

**More isolation, requires DNS record**

```hcl
# In terraform.tfvars
enable_subdomain_routing = true
listener_rule_priority   = 100
```

Access: `https://corrosion-engineer.dev.winda.ai/*`

✅ Cleaner URLs  
✅ Better service isolation  
⚠️ Creates additional Route53 record (done automatically)

---

## Multi-Region Deployment

Deploy to additional regions for global availability:

```bash
# Deploy to us-west-2
make apply ENV=dev REGION=us-west-2

# Deploy to eu-west-1
make apply ENV=dev REGION=eu-west-1
```

**Important:** Use the **same** `listener_rule_priority` across all regions.

---

## Configuration Guide

### Listener Priority Management

Each service needs a unique priority number (same across all regions):

| Service | Priority |
|---------|----------|
| corrosion-engineer | 100 |
| corrosion-prediction | 200 |
| auth-service | 300 |

### Scaling Configuration

```hcl
desired_count          = 1   # Initial task count
min_capacity           = 1   # Minimum tasks
max_capacity           = 3   # Maximum tasks
cpu_target_utilization = 80  # Scale when CPU > 80%
```

### Cost Optimization

Enable hibernation to scale down during off-hours:

```hcl
enable_hibernation_schedule = true
hibernation_start_cron      = "cron(0 22 * * ? *)"  # 10 PM UTC
hibernation_end_cron        = "cron(0 6 * * ? *)"   # 6 AM UTC
hibernation_min_capacity    = 0                     # Stop completely
```

### Environment Variables

Add custom environment variables:

```hcl
extra_env_vars = [
  { name = "LOG_LEVEL", value = "DEBUG" },
  { name = "API_KEY", value = "your-api-key" }
]
```

---

## What Gets Created

Per deployment (per region):
- 1 ECS Service (Fargate/Fargate Spot)
- 1 ALB Target Group
- 1 ALB Listener Rule (path or subdomain routing)
- 1 CloudWatch Log Group
- 2 IAM Roles (task execution + task runtime)
- Optional: 1 Route53 record (if subdomain routing enabled)

**Cost:** ~$20-30/month per region (1 task running 24/7)

---

## Commands

```bash
# Initialize
make init ENV=dev REGION=us-east-1

# Deploy
make apply ENV=dev REGION=us-east-1

# View service info
make outputs ENV=dev REGION=us-east-1

# View logs
aws logs tail /ecs/corrosion-engineer-dev-us-east-1 --follow

# Destroy
make destroy ENV=dev REGION=us-east-1
```

---

## Troubleshooting

**Service tasks keep stopping?**
- Check CloudWatch logs: `/ecs/corrosion-engineer-dev-us-east-1`
- Verify health check endpoint returns 200: `/Health`
- Confirm container listens on port 8080

**Can't access service?**
```bash
# Test path-based routing
curl https://dev.winda.ai/api/corrosion-engineer/Health

# Test subdomain routing
curl https://corrosion-engineer.dev.winda.ai/Health

# Check DNS
dig corrosion-engineer.dev.winda.ai
```

**Task execution errors?**
- Verify GitHub token secret exists: `github_token_ecs`
- Check IAM role permissions for pulling from GHCR
- Confirm image exists and tag is correct

**Listener rule conflicts?**
- Ensure `listener_rule_priority` is unique across all services
- Check other services aren't using the same priority
- Priority must be same across all regions for same service

---

## Prerequisites

1. **Central Infrastructure** deployed to the same region
2. **S3 Bucket** for Terraform state (must match central infra)
3. **GitHub Token Secret** in AWS Secrets Manager: `github_token_ecs`
4. **Container Image** pushed to GHCR

---

## Files Structure

```
corrosion_engineer_api_infra/
├── main/
│   ├── data.tf          # References central infrastructure
│   ├── service.tf       # ECS service, ALB rules, autoscaling
│   ├── variables.tf     # Input variables
│   ├── outputs.tf       # Service outputs
│   ├── provider.tf      # AWS provider config
│   └── backend.tf       # S3 backend config
├── workspace/
│   └── dev/
│       └── us-east-1/
│           ├── backend.conf
│           └── terraform.tfvars
└── Makefile
```

---

## Integration with Central Infrastructure

This repository **depends on** the `central_infra` repository outputs:

| Central Output | Used For |
|----------------|----------|
| `vpc_id` | Network placement |
| `private_subnet_ids` | ECS task placement |
| `ecs_cluster_id` | Where to deploy service |
| `ecs_service_security_group_id` | Network access |
| `https_listener_arn` | Add routing rules |
| `alb_dns_name` | DNS alias target |
| `global_domain_name` | URL construction |

**Deploy Order:**
1. Deploy `central_infra` first
2. Then deploy `corrosion_engineer_api_infra`

---

## License

Proprietary - Winda AI
