output "cluster_name" {
  value = aws_ecs_cluster.cluster.name
}

output "container_definitions" {
  value = local.container_definitions
}
