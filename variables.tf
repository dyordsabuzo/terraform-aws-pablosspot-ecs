variable "region" {
  description = "AWS region to create resources in"
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster" {
  type = object({
    name                      = string
    create                    = optional(bool)
    enable_container_insights = optional(bool)
  })
  description = "ECS cluster properties"
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

variable "container_healthcheck" {
  description = "Health check settings"
  type = object({
    path                = string
    protocol            = string
    interval            = number
    healthy_threshold   = number
    unhealthy_threshold = number
    matcher             = string
  })
  default = {
    path                = "/"
    protocol            = "HTTP"
    interval            = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
    matcher             = "200-299,301-399"
  }
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
  default     = 3
}

variable "egress_cidr_ipv4_list" {
  description = "List of IPV4 CIDR blocks where egress is allowed"
  type        = list(string)
  default     = []
}

variable "egress_cidr_ipv6_list" {
  description = "List of IPV6 CIDR blocks where egress is allowed"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Cloudwatch log retention in days"
  type        = number
  default     = 7
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

variable "deployment_circuit_breaker" {
  description = "Deployment circuit breaker"
  type = object({
    enabled  = bool
    rollback = bool
  })
  default = null
}

variable "deployment_metrics" {
  description = "Minimum and maximum healthy percent during deployment"
  type = object({
    min_percent = optional(number)
    max_percent = optional(number)
  })
  default = null
}

variable "container_capacity" {
  description = "Auto scaling container capacity properties"
  type = object({
    min = number
    max = number
  })
  default = {
    min = 1
    max = 4
  }
}

variable "scaling_adjustment" {
  description = "Auto scaling adjustment parameters"
  type = object({
    scale_up = object({
      adjustment_type         = string
      scaling_adjustment      = number
      metric_aggregation_type = string
    })
    scale_down = object({
      adjustment_type         = string
      scaling_adjustment      = number
      metric_aggregation_type = string
    })
  })
  default = {
    scale_up = {
      adjustment_type         = "ChangeInCapacity"
      scaling_adjustment      = 1
      metric_aggregation_type = "Maximum"
    }
    scale_down = {
      adjustment_type         = "ChangeInCapacity"
      scaling_adjustment      = -1
      metric_aggregation_type = "Maximum"
    }
  }
}

variable "autoscaling_metric_alarms" {
  description = "Cloudwatch metric alarms associated with autoscaling"
  type = list(object({
    identifer           = optional(string)
    threshold           = optional(number)
    comparison_operator = optional(string)
    evaluation_periods  = optional(number)
    period              = optional(number)
    metric_name         = optional(string)
    statistic           = optional(string)
    unit                = optional(string)
    metric_is_high      = bool
  }))
  default = [{
    identifer      = "cpu-high"
    metric_name    = "CPUUtilization"
    statistic      = "Average"
    threshold      = 70
    metric_is_high = true
    },
    {
      identifer      = "cpu-low"
      metric_name    = "CPUUtilization"
      statistic      = "Average"
      threshold      = 30
      metric_is_high = false
    },
    {
      identifer      = "memory-high"
      metric_name    = "MemoryUtilization"
      statistic      = "Average"
      threshold      = 70
      metric_is_high = true
    },
    {
      identifer      = "memory-low"
      metric_name    = "MemoryUtilization"
      statistic      = "Average"
      threshold      = 30
      metric_is_high = false
  }]
}
