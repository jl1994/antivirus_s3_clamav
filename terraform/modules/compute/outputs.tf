output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.antivirus.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.antivirus.arn
}

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.antivirus_scanner.name
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.antivirus_scanner.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs_tasks.name
}
