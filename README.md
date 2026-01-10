## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.28.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.28.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.task_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.task_execution_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb_listener_rule.rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.rule_exclusion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_security_group.secgrp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.all_traffic_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.all_traffic_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.tls_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.tls_ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_iam_policy_document.ecs_task_assume_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.task_execution_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_subnets.subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_authenticate_oidc_details"></a> [authenticate\_oidc\_details](#input\_authenticate\_oidc\_details) | OIDC Authentication details | <pre>object({<br/>    client_id     = string<br/>    client_secret = string<br/>    oidc_endpoint = string<br/>  })</pre> | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | ECS cluster name | `string` | n/a | yes |
| <a name="input_container_definitions"></a> [container\_definitions](#input\_container\_definitions) | JSON encoded list of container definition assigned to ecs task | `string` | n/a | yes |
| <a name="input_container_healthcheck"></a> [container\_healthcheck](#input\_container\_healthcheck) | Health check settings | <pre>object({<br/>    protocol            = string<br/>    interval            = number<br/>    healthy_threshold   = number<br/>    unhealthy_threshold = number<br/>    matcher             = string<br/>  })</pre> | <pre>{<br/>  "healthy_threshold": 3,<br/>  "interval": 5,<br/>  "matcher": "200-299,301-399",<br/>  "protocol": "HTTP",<br/>  "unhealthy_threshold": 5<br/>}</pre> | no |
| <a name="input_deployment_circuit_breaker"></a> [deployment\_circuit\_breaker](#input\_deployment\_circuit\_breaker) | Deployment circuit breaker | <pre>object({<br/>    enabled  = bool<br/>    rollback = bool<br/>  })</pre> | `null` | no |
| <a name="input_deployment_metrics"></a> [deployment\_metrics](#input\_deployment\_metrics) | Minimum and maximum healthy percent during deployment | <pre>object({<br/>    min_percent = optional(number)<br/>    max_percent = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | ECS service desired container count | `number` | `3` | no |
| <a name="input_egress_cidr_ipv4_list"></a> [egress\_cidr\_ipv4\_list](#input\_egress\_cidr\_ipv4\_list) | List of IPV4 CIDR blocks where egress is allowed | `list(string)` | `[]` | no |
| <a name="input_egress_cidr_ipv6_list"></a> [egress\_cidr\_ipv6\_list](#input\_egress\_cidr\_ipv6\_list) | List of IPV6 CIDR blocks where egress is allowed | `list(string)` | `[]` | no |
| <a name="input_enable_container_insights"></a> [enable\_container\_insights](#input\_enable\_container\_insights) | Flag to indicate if container insights is enabled or not | `bool` | `false` | no |
| <a name="input_endpoint_details"></a> [endpoint\_details](#input\_endpoint\_details) | Endpoint details | <pre>object({<br/>    lb_listener_arn = string<br/>    domain_url      = string<br/>    authenticate    = bool<br/>  })</pre> | n/a | yes |
| <a name="input_launch_type"></a> [launch\_type](#input\_launch\_type) | ECS launch type | <pre>object({<br/>    type   = string<br/>    cpu    = number<br/>    memory = number<br/>  })</pre> | <pre>{<br/>  "cpu": null,<br/>  "memory": null,<br/>  "type": "EC2"<br/>}</pre> | no |
| <a name="input_lb_authentication_exclusion"></a> [lb\_authentication\_exclusion](#input\_lb\_authentication\_exclusion) | Load balancer rule elements to be excluded from OIDC authentication | <pre>object({<br/>    path_pattern   = list(string)<br/>    request_method = list(string)<br/>    header_names   = list(string)<br/>  })</pre> | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Cloudwatch log retention in days | `number` | `10` | no |
| <a name="input_network_mode"></a> [network\_mode](#input\_network\_mode) | ECS network mode | `string` | `"awsvpc"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to create resources in | `string` | `"ap-southeast-2"` | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | ECS service name | `string` | n/a | yes |
| <a name="input_task_family"></a> [task\_family](#input\_task\_family) | ECS task family | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC id | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_definitions"></a> [container\_definitions](#output\_container\_definitions) | JSON encoded version of the container definitions |
