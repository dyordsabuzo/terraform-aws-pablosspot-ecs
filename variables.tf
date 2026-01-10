variable "region" {
  description = "AWS region to create resources in"
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  type        = string
  description = "ECS cluster name"
}

variable "service_name" {
  type        = string
  description = "ECS service name"
}

variable "task_family" {
  type        = string
  description = "ECS task family"
}

variable "container_definitions" {
  type        = string
  description = "JSON encoded list of container definition assigned to ecs task"
}

variable "vpc_id" {
  type        = string
  description = "VPC id"
}

variable "network_mode" {
  type        = string
  description = "ECS network mode"
  default     = "awsvpc"
}

variable "launch_type" {
  description = "ECS launch type"
  type = object({
    type   = string
    cpu    = number
    memory = number
  })
  default = {
    type   = "EC2"
    cpu    = null
    memory = null
  }
}

variable "endpoint_details" {
  type = object({
    lb_listener_arn = string
    domain_url      = string
    authenticate    = bool
  })
  description = "Endpoint details"
}

variable "desired_count" {
  type        = number
  description = "ECS service desired container count"
  default     = 1
}

variable "authenticate_oidc_details" {
  type = object({
    client_id     = string
    client_secret = string
    oidc_endpoint = string
  })
  description = "OIDC Authentication details"
  default     = null
}

variable "lb_authentication_exclusion" {
  type = object({
    path_pattern   = list(string)
    request_method = list(string)
    header_names   = list(string)
  })
  description = "Load balancer rule elements to be excluded from OIDC authentication"
  default     = null
}
