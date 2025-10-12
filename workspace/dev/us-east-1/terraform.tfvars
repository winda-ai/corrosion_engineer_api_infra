# ============================================================
# Core Configuration
# ============================================================
environment = "dev"
region      = "us-east-1"
name_prefix = "corrosion-engineer"

# ============================================================
# Central Infrastructure Reference
# ============================================================
terraform_state_bucket   = "winda-terraform-artifacts"
route53_zone_name        = "winda.ai"
enable_subdomain_routing = true
listener_rule_priority   = 100

# ============================================================
# Container Configuration
# ============================================================
container_image   = "ghcr.io/winda-ai/corrosion_engineer_api:latest"
container_port    = 8080
health_check_path = "/Health"

task_cpu    = 512  # 0.5 vCPU
task_memory = 1024 # 1 GB

# ============================================================
# Scaling Configuration
# ============================================================
desired_count          = 1
min_capacity           = 1
max_capacity           = 3
cpu_target_utilization = 80

# ============================================================
# Cost Optimization (optional)
# ============================================================
enable_hibernation_schedule = false
# hibernation_start_cron    = "cron(0 22 * * ? *)"  # 10 PM UTC
# hibernation_end_cron      = "cron(0 6 * * ? *)"   # 6 AM UTC
# hibernation_min_capacity  = 0

# ============================================================
# Additional Environment Variables (optional)
# ============================================================
extra_env_vars = []
# extra_env_vars = [
#   { name = "LOG_LEVEL", value = "INFO" },
#   { name = "FEATURE_FLAG", value = "enabled" }
# ]
