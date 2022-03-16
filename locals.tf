locals {
  container_definition = jsondecode(var.container_definition)
  first_container      = local.container_definition[0]
  main_container_name  = local.first_container.name
  main_container_port  = local.first_container.portMappings[0].containerPort
}
