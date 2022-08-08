locals {
  container_definitions = jsonencode([
    for definition in var.container_definitions : {
      for key, value in definition :
      key => try(
        # handle value that is a list
        try(toset(value), [
          for k, v in value : {
            name                                     = k
            key == "secrets" ? "valueFrom" : "value" = v
        }]),
      value)
    }
  ])

  first_container     = var.container_definitions[0]
  main_container_name = local.first_container.name
  main_container_port = local.first_container.container_port
}
