output "cluster_name" {
  value = aws_ecs_cluster.cluster.name
}

output "container_definitions" {
  value = local.container_definitions
}

output "target_group_arn" {
  value = aws_lb_target_group.target.arn
}
