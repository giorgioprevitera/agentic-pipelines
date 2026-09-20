output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "curl http://<this>/health"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.ecs.name
}
