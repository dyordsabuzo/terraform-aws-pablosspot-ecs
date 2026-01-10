# firewall resources
resource "aws_security_group" "secgrp" {
  name        = "${var.service_name}-ecs-secgrp"
  description = "${var.service_name} ecs security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.service_name}-ecs-secgrp"
  }
}

resource "aws_vpc_security_group_ingress_rule" "tls_ipv4" {
  security_group_id = aws_security_group.secgrp.id
  cidr_ipv4         = data.aws_vpc.vpc.cidr_block
  from_port         = local.main_container_port
  to_port           = local.main_container_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "tls_ipv6" {
  security_group_id = aws_security_group.secgrp.id
  cidr_ipv6         = data.aws_vpc.vpc.cidr_block
  from_port         = local.main_container_port
  to_port           = local.main_container_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all_traffic_ipv4" {
  for_each          = toset(var.egress_cidr_ipv4_list)
  security_group_id = aws_security_group.secgrp.id
  cidr_ipv4         = each.value
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "all_traffic_ipv6" {
  for_each          = toset(var.egress_cidr_ipv6_list)
  security_group_id = aws_security_group.secgrp.id
  cidr_ipv6         = each.value
  ip_protocol       = "-1"
}

resource "aws_ecs_cluster" "cluster" {
  name = var.cluster_name

  dynamic "setting" {
    for_each = var.enable_container_insights ? [1] : []
    content {
      name  = "containerInsights"
      value = "enabled"
    }
  }
}

resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.cluster.name
  launch_type     = var.launch_type.type
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = var.desired_count

  load_balancer {
    container_name   = local.main_container_name
    container_port   = local.main_container_port
    target_group_arn = aws_lb_target_group.target.arn
  }

  dynamic "network_configuration" {
    for_each = var.network_mode == "awsvpc" ? [1] : []
    content {
      subnets          = data.aws_subnets.subnets.ids
      security_groups  = [aws_security_group.secgrp.id]
      assign_public_ip = true
    }
  }

  dynamic "deployment_circuit_breaker" {
    for_each = var.deployment_circuit_breaker == null ? [] : [1]
    content {
      enable   = var.deployment_circuit_breaker.enabled
      rollback = var.deployment_circuit_breaker.rollback
    }
  }

  deployment_minimum_healthy_percent = try(var.deployment_metrics.min_percent, 100)
  deployment_maximum_percent         = try(var.deployment_metrics.max_percent, 200)

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_ecs_task_definition" "task" {
  family                   = var.task_family
  network_mode             = var.network_mode
  requires_compatibilities = [var.launch_type.type]
  execution_role_arn       = aws_iam_role.task_role.arn
  container_definitions    = local.container_definitions
  cpu                      = var.launch_type.cpu
  memory                   = var.launch_type.memory
}

resource "aws_iam_role" "task_role" {
  name               = "ecs-task-${var.task_family}-${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_policy.json
}

resource "aws_iam_role_policy" "task_policy" {
  name   = "ecs-task-permissions-${var.task_family}-${terraform.workspace}"
  role   = aws_iam_role.task_role.id
  policy = data.aws_iam_policy_document.task_execution_permissions.json
}

resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "log" {
  name              = "/${var.cluster_name}/${var.service_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lb_target_group" "target" {
  name        = "${var.service_name}-${terraform.workspace}-tg"
  vpc_id      = var.vpc_id
  port        = local.main_container_port
  protocol    = "HTTP"
  target_type = "ip"

  dynamic "health_check" {
    for_each = { var.container_healthcheck.path = var.container_healthcheck }
    content {
      path                = each.value.path
      protocol            = each.value.protocol
      interval            = each.value.interval
      healthy_threshold   = each.value.healthy_threshold
      unhealthy_threshold = each.value.unhealthy_threshold
      matcher             = each.value.matcher
    }
  }
}

resource "aws_lb_listener_rule" "rule" {
  listener_arn = var.endpoint_details.lb_listener_arn
  priority     = 10

  condition {
    host_header {
      values = [var.endpoint_details.domain_url]
    }
  }

  dynamic "action" {
    for_each = var.endpoint_details.authenticate ? [1] : []

    content {
      type = "authenticate-oidc"

      authenticate_oidc {
        authorization_endpoint     = format("%s/oauth2/v1/authorize", var.authenticate_oidc_details.oidc_endpoint)
        token_endpoint             = format("%s/oauth2/v1/token", var.authenticate_oidc_details.oidc_endpoint)
        user_info_endpoint         = format("%s/oauth2/v1/userinfo", var.authenticate_oidc_details.oidc_endpoint)
        issuer                     = var.authenticate_oidc_details.oidc_endpoint
        session_cookie_name        = format("TOKEN-OIDC-%s", var.authenticate_oidc_details.client_id)
        session_timeout            = 120
        scope                      = "openid profile"
        on_unauthenticated_request = "authenticate"
        client_id                  = var.authenticate_oidc_details.client_id
        client_secret              = var.authenticate_oidc_details.client_secret
      }
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target.arn
  }
}

resource "aws_lb_listener_rule" "rule_exclusion" {
  count        = var.lb_authentication_exclusion != null ? 1 : 0
  listener_arn = var.endpoint_details.lb_listener_arn
  priority     = 1

  condition {
    host_header {
      values = [var.endpoint_details.domain_url]
    }
  }

  dynamic "condition" {
    for_each = length(var.lb_authentication_exclusion.path_pattern) > 0 ? [1] : []
    content {
      path_pattern {
        values = var.lb_authentication_exclusion.path_pattern
      }
    }
  }

  dynamic "condition" {
    for_each = length(var.lb_authentication_exclusion.request_method) > 0 ? [1] : []
    content {
      http_request_method {
        values = var.lb_authentication_exclusion.request_method
      }
    }
  }

  dynamic "condition" {
    for_each = var.lb_authentication_exclusion.header_names
    content {
      http_header {
        http_header_name = condition.value
        values           = ["*"]
      }
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target.arn
  }
}
