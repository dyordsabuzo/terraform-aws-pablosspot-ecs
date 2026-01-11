# terraform-aws-pablosspot-ecs

Terraform module to deploy an ECS Task & Service and supporting resources into an existing VPC.

This module provisions:
- An ECS cluster (optional) and an ECS service
- An ECS task definition derived from supplied `container_definitions`
- CloudWatch Log Group for container logs
- An ALB Target Group and Listener Rules (with optional OIDC `authenticate-oidc` action)
- IAM roles and policies for task execution and autoscaling
- Application Auto Scaling resources and CloudWatch alarms
- Security group and ingress/egress rules

Files of interest:
- `main.tf` — primary resources (ECS service, task, ALB rules, autoscaling)
- `locals.tf` — container definition processing and local values
- `variables.tf` — module inputs and defaults
- `data.tf` — VPC/subnet and IAM policy documents
- `outputs.tf` — module outputs

---

## Table of contents

- [Quick start](#quick-start)
- [Inputs (summary)](#inputs-summary)
- [Outputs](#outputs)
- [How it works (implementation notes)](#how-it-works-implementation-notes)
  - [Container definitions & locals](#container-definitions--locals)
  - [Networking & security](#networking--security)
  - [Load balancer and OIDC auth](#load-balancer-and-oidc-auth)
  - [Autoscaling & alarms](#autoscaling--alarms)
- [Example container definitions](#example-container-definitions)
- [Notes & gotchas](#notes--gotchas)
- [Examples & testing](#examples--testing)
- [Contributing](#contributing)

---

## Quick start

Call the module from your Terraform configuration and provide the required inputs:

```hcl
module "ecs_service" {
  source = "./path/to/terraform-aws-pablosspot-ecs"

  cluster = { name = "my-cluster", create = false }
  vpc_id  = "vpc-0123456789abcdef0"

  service_name         = "my-service"
  task_family          = "my-service-task"
  container_definitions = jsonencode([
    {
      name           = "web"
      image          = "nginx:stable"
      container_port = "80"
      essential      = true
    }
  ])

  endpoint_details = {
    lb_listener_arn = "arn:aws:elasticloadbalancing:region:acct:listener/app/..."
    domain_url      = "example.com"
    authenticate    = false
  }
}
```

Replace `source` with the path to this module or a published module location.

![Terraform documentation](./terraform-docs.md)

---

## Inputs (summary)

See `variables.tf` for complete types and defaults. Important inputs include:

- `cluster` (object, required)
  - `name` — ECS cluster name
  - `create` — optional bool, whether to create the cluster
  - `enable_container_insights` — optional bool
- `service_name` (string, required) — ECS service name
- `task_family` (string, required) — ECS task family
- `container_definitions` (string, required) — JSON encoded list of container definitions (this module decodes and normalizes)
- `endpoint_details` (object, required)
  - `lb_listener_arn` — ALB listener ARN (existing)
  - `domain_url` — host header value used for listener rule matching
  - `authenticate` — bool to enable OIDC authentication action
- `vpc_id` (string, required) — VPC id
- `launch_type` (object) — `{ type, cpu, memory }`
- `network_mode` (string) — default `"awsvpc"`
- `container_healthcheck` (object) — target group health check config
- `container_capacity` (object) — `{ min, max }` for autoscaling
- `desired_count` (number) — service desired count (lifecycle ignores changes)
- `egress_cidr_ipv4_list` / `egress_cidr_ipv6_list` — egress CIDRs
- `autoscaling_metric_alarms` — list of alarm definitions for scaling
- `authenticate_oidc_details` (object|null) — OIDC client details (required if `authenticate=true`)
- `lb_authentication_exclusion` (object|null) — exclusions for auth (paths/methods/headers)

---

## Outputs

- `container_definitions` — JSON encoded container definitions after module preprocessing (used by the ECS task definition).

---

## How it works (implementation notes)

### Container definitions & locals

- The module expects `container_definitions` as a JSON string and decodes it via `jsondecode` into `local.container_defn_object`.
- For each container definition the module:
  - Adds `portMappings` if missing using `container_port`.
  - Adds an `awslogs` `logConfiguration` (unless provided) with log group `/${var.cluster.name}/${var.service_name}` and stream prefix equal to the container `name`.
  - Normalizes `secrets` and similar maps to ECS-compatible structures (e.g., uses `valueFrom`).
- The first container in the list (`local.first_container`) is considered the "main" container; its `name` and `container_port` are used for the service load balancer mapping and target group port.

See `locals.tf` for processing logic.

### Networking & security

- Creates `aws_security_group.secgrp`:
  - Ingress rules for the main container port from the VPC CIDR (IPv4 and IPv6).
  - Egress rules created for each CIDR in `egress_cidr_ipv4_list` and `egress_cidr_ipv6_list`.
- Uses `data.aws_subnets` filtered by `vpc-id` and tag `role = "private"`. Adjust tagging or the data source if your subnets use different tags.

### Load balancer and OIDC auth

- `aws_lb_target_group.target` — HTTP, `target_type = "ip"`, configured on `local.main_container_port`. Health checks configured from `container_healthcheck`.
- `aws_lb_listener_rule.rule` — matches `HostHeader` of `endpoint_details.domain_url`.  
  - If `endpoint_details.authenticate` is true, inserts an `authenticate-oidc` action using `authenticate_oidc_details` to build endpoints and then forwards to the target group.
- `aws_lb_listener_rule.rule_exclusion` — optional higher-priority rule to forward specified paths/methods/headers and bypass authentication.

### Autoscaling & alarms

- `aws_iam_role.ecs_auto_scale_role` — role for Application Auto Scaling.
- `aws_appautoscaling_target.target` — configures scalable `ecs:service:DesiredCount` with min/max from `container_capacity`.
- `aws_appautoscaling_policy.up` & `.down` — step-scaling policies using the provided `scaling_adjustment`.
- `aws_cloudwatch_metric_alarm.alarm` — creates alarms from `autoscaling_metric_alarms` and attaches them to the appropriate scale policy.

Lifecycle notes:
- `aws_ecs_service.service` includes `lifecycle { ignore_changes = [desired_count] }` — manual desired count changes are preserved.

---

## Example container definitions

A minimal example (module will augment missing fields):

```json
[
  {
    "name": "web",
    "image": "nginx:stable",
    "container_port": "80",
    "essential": true,
    "environment": {
      "ENV": "production"
    }
  }
]
```

When using HCL, provide this via `jsonencode(...)` to `container_definitions`.

Notes:
- If you provide `portMappings`, `logConfiguration`, `secrets` or other full ECS fields, the module will preserve them and not overwrite them.
- If `portMappings` is omitted, include `container_port` so the module can create a port mapping.

---

## Notes & gotchas

- Subnet selection: the module queries subnets tagged `role = "private"`; change that if your environment differs.
- ALB listener: the module requires an existing ALB listener ARN (`lb_listener_arn`).
- OIDC authentication: if `endpoint_details.authenticate = true`, set `authenticate_oidc_details` with `client_id`, `client_secret` and `oidc_endpoint`. The module appends `/oauth2/v1/authorize`, `/oauth2/v1/token`, `/oauth2/v1/userinfo` to build endpoints.
- IAM permissions: `data.aws_iam_policy_document.task_execution_permissions` contains broad ARNs for required services (ECR, Logs, SSM, SecretsManager, KMS). Restrict as needed for your security posture.
- Public IP assignment: when `network_mode == "awsvpc"`, the module sets `assign_public_ip = true`. Change if you need private-only tasks.
- `tfsec` suppressions: the code includes inline suppression comments for a couple of `tfsec` checks — review against your policies.

---

## Examples & testing

An `examples/` directory with a basic usage example is included in the repository. That example shows a small `main.tf` and a `terraform.tfvars` file with placeholders. Use those as a starting point and replace the placeholder values with your environment's values.

---

## Contributing

Contributions are welcome. Suggested steps:
1. Open an issue describing the change or improvement.
2. Create a branch and a focused PR with tests or examples if applicable.
3. Keep commits small and descriptive.
