aws_region              = "us-east-1"
environment             = "dev"
name_prefix             = "east1-dev"
container_image         = "ghcr.io/winda-ai/corrosion_engineer_api:latest"
subdomain               = "api.corrosion-engineer.dev"
use_fargate             = true
fargate_spot_percentage = 100
hybrid_fargate          = false
vpc_id                 = "vpc-0d242b65292890599"
public_subnet_ids      = [
  "subnet-090a1e3b7a5556b19",
  "subnet-08e99ae1270a6c74c",
]
private_subnet_ids     = [
  "subnet-096207037c01ea3d6",
  "subnet-0cf58335ca63c03ad",
]
ecs_cluster_name       = "winda-dev-us-east-1-ecs-cluster"
