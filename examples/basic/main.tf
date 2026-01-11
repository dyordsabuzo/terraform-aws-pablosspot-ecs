# terraform-aws-pablosspot-ecs/examples/basic/main.tf

terraform {
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

#########################
# Example variables
#
# Please provide real values in a sibling `terraform.tfvars` file
# or via environment variables. Example terraform.tfvars content:
#
# vpc_id            = "vpc-0123456789abcdef0"
# lb_listener_arn   = "arn:aws:elasticloadbalancing:region:acct:listener/app/..."
# domain_url        = "example.com"
# authenticate_oidc = false
#
#########################

variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "vpc_id" {
  description = "VPC id where the ECS service and target group should be created"
  type        = string
}

variable "lb_listener_arn" {
  description = "ALB listener ARN to attach listener rules to"
  type        = string
}

variable "domain_url" {
  description = "Domain/host value used when matching the listener HostHeader condition"
  type        = string
  default     = "example.com"
}

variable "authenticate_oidc" {
  description = "Enable ALB authenticate-oidc action on the listener rule"
  type        = bool
  default     = false
}

# Optional OIDC details (required if authenticate_oidc = true)
variable "authenticate_oidc_details" {
  type = object({
    client_id     = string
    client_secret = string
    oidc_endpoint = string
  })
  default = null
}

#########################
# Example: minimal container definition
#
# The module will add an awslogs logConfiguration and portMappings
# if they are not supplied. `container_port` is used when portMappings
# is absent.
#########################

locals {
  example_container_definitions = jsonencode([
    {
      name           = "example-app"
      image          = "nginx:stable"
      container_port = "80"
      essential      = true
      environment = {
        ENV = "production"
      }
    }
  ])
}

module "ecs_service" {
  source = "../../"

  # cluster object: set create = false if the cluster already exists
  cluster = {
    name   = "example-cluster"
    create = false
  }

  vpc_id                = var.vpc_id
  service_name          = "example-service"
  task_family           = "example-service-task"
  container_definitions = local.example_container_definitions

  # Endpoint details: must reference an existing ALB listener ARN
  endpoint_details = {
    lb_listener_arn = var.lb_listener_arn
    domain_url      = var.domain_url
    authenticate    = var.authenticate_oidc
  }

  # Pass OIDC details only if authenticate_oidc is true
  authenticate_oidc_details = var.authenticate_oidc ? var.authenticate_oidc_details : null

  # Example: use defaults for most other options. Uncomment and adapt as needed:
  # launch_type = { type = "FARGATE", cpu = 256, memory = 512 }
  # desired_count = 2
  # container_capacity = { min = 1, max = 3 }
  # container_healthcheck = {
  #   path = "/health"
  #   protocol = "HTTP"
  #   interval = 10
  #   healthy_threshold = 2
  #   unhealthy_threshold = 3
  #   matcher = "200-299"
  # }
}

output "processed_container_definitions" {
  description = "Container definitions after module preprocessing (JSON)"
  value       = module.ecs_service.container_definitions
}
