locals {
  container_definitions = format("[%s]", join(",", [
    for definition in var.container_definitions :
    templatefile("${path.module}/templates/container_definition.tpl", {
      container_name = definition.name,
      image          = definition.image,
      cpu            = definition.cpu,
      memory         = definition.memory,
      essential      = true,
      environment = jsonencode([
        for key, value in definition.environment :
        {
          name  = key
          value = value
        }
      ]),
      secrets = jsonencode([
        for key, value in definition.secrets :
        {
          name      = key
          valueFrom = value
        }
      ]),
      port_mappings = jsonencode([{
        containerPort = definition.container_port
      }]),
      log_configuration = jsonencode({
        logDriver = "awslogs"

        options = {
          awslogs-region        = var.region
          awslogs-stream-prefix = definition.name
          awslogs-group         = aws_cloudwatch_log_group.log.name
        }
      })
    })
  ]))

  first_container     = var.container_definitions[0]
  main_container_name = local.first_container.name
  main_container_port = local.first_container.container_port
}
