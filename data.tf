data "aws_iam_policy_document" "ecs_task_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

#tfsec:ignore:aws-iam-no-policy-wildcards:exp:2026-02-01
data "aws_iam_policy_document" "task_execution_permissions" {
  statement {
    effect = "Allow"
    resources = [
      "arn:aws:ecr:*",
      "arn:aws:logs:*",
      "arn:aws:ssm:*",
      "arn:aws:secretsmanager:*",
      "arn:aws:kms:*",
    ]
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "ssm:GetParameters",
      "secretsmanager:GetSecretValue",
      "kms:Decrypt"
    ]
  }

  # statement {
  #   effect  = "Allow"
  #   actions = [
  #     "s3:Get*",
  #     "s3:Putt*",
  #   ]
  #   resources = [
  #     data.aws_s3_bucket.misc.arn,
  #     "${data.aws_s3_bucket.misc.arn}/*",
  #   ]
  # }
}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    role = "private"
  }
}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

data "aws_iam_policy_document" "ecs_auto_scale_role" {
  version = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["application-autoscaling.amazonaws.com"]
    }
  }
}
