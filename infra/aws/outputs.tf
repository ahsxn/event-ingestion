output "vpc_id" {
  description = "Portfolio VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "availability_zone" {
  description = "Availability Zone used by the portfolio deployment"
  value       = aws_subnet.public.availability_zone
}

output "ecs_host_security_group_id" {
  description = "Security group used by the ECS EC2 host"
  value       = aws_security_group.ecs_host.id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_host_instance_id" {
  description = "EC2 instance hosting ECS workloads"
  value       = aws_instance.ecs_host.id
}

output "ecs_host_public_ip" {
  description = "Static public IP of the ECS host"
  value       = aws_eip.ecs_host.public_ip
}

output "worker_repository_url" {
  description = "ECR repository URL for the worker image"
  value       = aws_ecr_repository.worker.repository_url
}

output "events_stream_name" {
  description = "Kinesis stream consumed by the worker"
  value       = aws_kinesis_stream.events.name
}

output "metrics_table_name" {
  description = "DynamoDB metrics table"
  value       = aws_dynamodb_table.metrics.name
}

output "processed_events_table_name" {
  description = "DynamoDB processed-events table"
  value       = aws_dynamodb_table.processed_events.name
}

output "worker_service_name" {
  description = "ECS worker service name"
  value       = aws_ecs_service.worker.name
}

output "events_api_url" {
  description = "Public event ingestion endpoint"
  value       = "${aws_apigatewayv2_api.ingest.api_endpoint}/events"
}

output "dashboard_repository_url" {
  description = "ECR repository URL for the dashboard image"
  value       = aws_ecr_repository.dashboard.repository_url
}

output "dashboard_app_key_secret_arn" {
  description = "Secrets Manager ARN containing the Laravel APP_KEY"
  value       = aws_secretsmanager_secret.dashboard_app_key.arn
}

output "dashboard_service_name" {
  description = "ECS dashboard service name"
  value       = aws_ecs_service.dashboard.name
}

output "dashboard_url" {
  description = "Public dashboard URL"
  value       = "http://${aws_eip.ecs_host.public_ip}"
}
