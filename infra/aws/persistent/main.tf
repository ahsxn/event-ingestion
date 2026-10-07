terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  backend "s3" {}
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-north-1"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_eip" "ecs_host" {
  domain = "vpc"

  tags = {
    Name        = "event-ingestion"
    Project     = "event-ingestion"
    Environment = "portfolio"
    ManagedBy   = "terraform"
  }
}

output "ecs_host_eip_allocation_id" {
  description = "Persistent Elastic IP allocation ID"
  value       = aws_eip.ecs_host.id
}

output "ecs_host_public_ip" {
  description = "Persistent public IP for the ECS host"
  value       = aws_eip.ecs_host.public_ip
}
