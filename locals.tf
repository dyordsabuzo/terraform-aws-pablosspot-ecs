locals {
  container_definition = jsondecode(var.container_definition)
  first_container      = local.container_definition[0]
  main_container_name  = local.first_container.name
  main_container_port  = local.first_container.portMappings[0].containerPort

  enhanced_container_definition = [
    for definition in local.container_definition :
    merge(definition, lookup(definition, "logConfiguration", null) == null ? {
      logDriver = "awslogs"

      options = {
        awslogs-region        = var.region
        awslogs-stream-prefix = definition.name
        awslogs-group         = aws_cloudwatch_log_group.log.name
      }
    } : null)
  ]
}
