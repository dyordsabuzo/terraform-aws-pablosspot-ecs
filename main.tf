resource "aws_ecs_cluster" "cluster" {
  name = var.cluster_name
}

resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.cluster.name
  launch_type     = var.launch_type.type
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 2

  load_balancer {
    container_name   = local.main_container_name
    container_port   = local.main_container_port
    target_group_arn = var.target_group_arn
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
    ignore_changes = ["tags"]
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
