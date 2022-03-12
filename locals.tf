locals {
  container_definition = jsondecode(var.container_definition)
  first_container      = local.container_definition[0]
  container_name       = local.first_container.name
  host_port            = local.first_container.portMappings[0].hostPort
}
