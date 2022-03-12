resource "aws_ecs_cluster" "cluster" {
  name = var.cluster_name
}

resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.cluster.name
  launch_type     = "EC2"
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 2

  load_balancer {
    container_name   = local.container_name
    container_port   = local.host_port
    target_group_arn = var.target_group_arn
  }
}

resource "aws_ecs_task_definition" "task" {
  family                   = var.task_family
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.task_role.arn
  container_definitions    = var.container_definition
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
            "ssm:*"
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
