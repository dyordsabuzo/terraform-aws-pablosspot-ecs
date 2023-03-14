resource "aws_ecs_cluster" "cluster" {
  name = var.cluster_name
}

resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.cluster.name
  launch_type     = var.launch_type.type
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = var.desired_count

  dynamic "load_balancer" {
    for_each = var.endpoint_details != null ? [1] : []

    content {
      container_name   = local.main_container_name
      container_port   = local.main_container_port
      target_group_arn = aws_lb_target_group.target.0.arn
    }
  }

  dynamic "network_configuration" {
    for_each = var.network_mode == "awsvpc" ? [1] : []
    content {
      subnets          = data.aws_subnets.subnets.ids
      security_groups  = [aws_security_group.secgrp.id]
      assign_public_ip = true
    }
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

  inline_policy {
    name = "ecs-task-permissions"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ecr:*",
            "logs:*",
            "ssm:*",
            "kms:Decrypt",
            "secretsmanager:GetSecretValue"

          ]
          Effect   = "Allow"
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_cloudwatch_log_group" "log" {
  name              = "/${var.cluster_name}/${var.service_name}"
  retention_in_days = 14
}

resource "aws_default_vpc" "default" {
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_security_group" "secgrp" {
  name        = "${var.service_name}-ecs-secgrp"
  description = "${var.service_name} ecs security group"
  vpc_id      = var.vpc_id == null ? aws_default_vpc.default.id : var.vpc_id

  ingress {
    from_port = local.main_container_port
    to_port   = local.main_container_port
    protocol  = "tcp"
    cidr_blocks = [var.vpc_id == null ? aws_default_vpc.default.cidr_block
      : data.aws_vpc.vpc[0].cidr_block
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.service_name}-ecs-secgrp"
  }
}

resource "aws_lb_target_group" "target" {
  count       = var.endpoint_details != null ? 1 : 0
  name        = format("%s-%s", var.service_name, terraform.workspace)
  port        = local.main_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id == null ? aws_default_vpc.default.id : var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    interval            = 10
    unhealthy_threshold = 6
    matcher             = "200,301-399"
  }
}

resource "aws_lb_listener_rule" "rule" {
  count        = var.endpoint_details != null ? 1 : 0
  listener_arn = var.endpoint_details.lb_listener_arn
  priority     = 10

  condition {
    host_header {
      values = [var.endpoint_details.domain_url]
    }
  }

  dynamic "action" {
    for_each = var.authenticate_oidc_details != null ? [1] : []

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
    target_group_arn = aws_lb_target_group.target.0.arn
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
        http_header_name = condition.key
        values           = ["*"]
      }
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target.0.arn
  }
}
