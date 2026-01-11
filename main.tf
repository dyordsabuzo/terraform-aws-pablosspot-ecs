# firewall resources
resource "aws_security_group" "secgrp" {
  name        = "${var.service_name}-ecs-secgrp"
  description = "${var.service_name} ecs security group"
  vpc_id      = var.vpc_id

  tags = merge({
    Name = "${var.service_name}-ecs-secgrp"
  }, local.tags)
}

resource "aws_vpc_security_group_ingress_rule" "tls_ipv4" {
  security_group_id = aws_security_group.secgrp.id
  cidr_ipv4         = data.aws_vpc.vpc.cidr_block
  from_port         = local.main_container_port
  to_port           = local.main_container_port
  ip_protocol       = "tcp"
  tags              = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "tls_ipv6" {
  security_group_id = aws_security_group.secgrp.id
  cidr_ipv6         = data.aws_vpc.vpc.cidr_block
  from_port         = local.main_container_port
  to_port           = local.main_container_port
  ip_protocol       = "tcp"
  tags              = local.tags
}

resource "aws_vpc_security_group_egress_rule" "all_traffic_ipv4" {
  for_each          = toset(var.egress_cidr_ipv4_list)
  security_group_id = aws_security_group.secgrp.id
  cidr_ipv4         = each.value
  ip_protocol       = "-1"
  tags              = local.tags
}

resource "aws_vpc_security_group_egress_rule" "all_traffic_ipv6" {
  for_each          = toset(var.egress_cidr_ipv6_list)
  security_group_id = aws_security_group.secgrp.id
  cidr_ipv6         = each.value
  ip_protocol       = "-1"
  tags              = local.tags
}

#tfsec:ignore:aws-ecs-enable-container-insight:exp:2026-02-01
resource "aws_ecs_cluster" "cluster" {
  count = try(var.cluster.create, true) ? 1 : 0
  name  = var.cluster.name

  dynamic "setting" {
    for_each = try(var.cluster.enable_container_insights, false) ? [1] : []
    content {
      name  = "containerInsights"
      value = "enabled"
    }
  }

  tags = local.tags
}

resource "aws_ecs_service" "service" {
  name                 = var.service_name
  cluster              = var.cluster.name
  launch_type          = var.launch_type.type
  task_definition      = aws_ecs_task_definition.task.arn
  desired_count        = var.desired_count
  force_new_deployment = true

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

  depends_on = [aws_iam_role_policy.task_policy]

  # This is added to ignore changes to the desired count from a manual update
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = local.tags
}

resource "aws_ecs_task_definition" "task" {
  family                   = var.task_family
  network_mode             = var.network_mode
  requires_compatibilities = [var.launch_type.type]
  execution_role_arn       = aws_iam_role.task_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions    = local.container_definitions
  cpu                      = var.launch_type.cpu
  memory                   = var.launch_type.memory
  tags                     = local.tags
}

resource "aws_iam_role" "task_role" {
  name               = "ecs-task-${var.task_family}-${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_policy.json
  tags               = local.tags
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

#tfsec:ignore:aws-cloudwatch-log-group-customer-key:exp:2026-02-01
resource "aws_cloudwatch_log_group" "log" {
  name              = "/${var.cluster.name}/${var.service_name}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_lb_target_group" "target" {
  name        = "${var.service_name}-${terraform.workspace}-tg"
  vpc_id      = var.vpc_id
  port        = local.main_container_port
  protocol    = "HTTP"
  target_type = "ip"

  dynamic "health_check" {
    for_each = { (var.container_healthcheck.path) = var.container_healthcheck }
    content {
      path                = health_check.value.path
      protocol            = health_check.value.protocol
      interval            = health_check.value.interval
      healthy_threshold   = health_check.value.healthy_threshold
      unhealthy_threshold = health_check.value.unhealthy_threshold
      matcher             = health_check.value.matcher
    }
  }

  tags = local.tags
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

  tags = local.tags
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

  tags = local.tags
}

# auto scaling
# ECS auto scale role
resource "aws_iam_role" "ecs_auto_scale_role" {
  name               = "${aws_ecs_service.service.name}-auto-scale"
  assume_role_policy = data.aws_iam_policy_document.ecs_auto_scale_role.json
}

resource "aws_appautoscaling_target" "target" {
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  role_arn           = aws_iam_role.ecs_auto_scale_role.arn
  min_capacity       = var.container_capacity.min
  max_capacity       = var.container_capacity.max
}

# Automatically scale capacity up by one
resource "aws_appautoscaling_policy" "up" {
  name               = "${aws_ecs_service.service.name}-scale-up"
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = var.scaling_adjustment.scale_up.adjustment_type
    cooldown                = 60
    metric_aggregation_type = var.scaling_adjustment.scale_up.metric_aggregation_type
    step_adjustment {
      scaling_adjustment          = var.scaling_adjustment.scale_up.scaling_adjustment
      metric_interval_lower_bound = 0
    }
  }
  depends_on = [aws_appautoscaling_target.target]
}

# Automatically scale capacity down by one
resource "aws_appautoscaling_policy" "down" {
  name               = "${aws_ecs_service.service.name}-scale-down"
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster.name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = var.scaling_adjustment.scale_down.adjustment_type
    cooldown                = 60
    metric_aggregation_type = var.scaling_adjustment.scale_down.metric_aggregation_type
    step_adjustment {
      scaling_adjustment          = var.scaling_adjustment.scale_down.scaling_adjustment
      metric_interval_lower_bound = 0
    }
  }
  depends_on = [aws_appautoscaling_target.target]
}

# CloudWatch alarm that triggers scale up policy
resource "aws_cloudwatch_metric_alarm" "alarm" {
  for_each            = { for alarm in var.autoscaling_metric_alarms : alarm.name => alarm }
  alarm_name          = "${aws_ecs_service.service.name}-${each.value.identifier}"
  namespace           = "AWS/ECS"
  comparison_operator = coalesce(each.value.comparison_operator, "GreaterThanOrEqualToThreshold")
  evaluation_periods  = coalesce(each.value.evaluation_periods, 2)
  metric_name         = each.value.metric_name
  period              = coalesce(each.value.period, 60)
  statistic           = coalesce(each.value.statistic, "Average")
  threshold           = coalesce(each.value.threshold, 70)
  alarm_actions       = [each.value.metric_is_high ? aws_appautoscaling_policy.up.arn : aws_appautoscaling_policy.down.arn]

  dimensions = {
    ClusterName = var.cluster.name
    ServiceName = aws_ecs_service.service.name
  }
}
