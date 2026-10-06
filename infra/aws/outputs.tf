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
