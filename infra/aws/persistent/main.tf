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


variable "github_owner" {
  type        = string
  description = "GitHub repository owner"
}

variable "github_owner_id" {
  type        = string
  description = "Immutable GitHub repository owner ID"
}

variable "github_repository" {
  type        = string
  description = "GitHub repository name"
}

variable "github_repository_id" {
  type        = string
  description = "Immutable GitHub repository ID"
}

variable "github_branch" {
  type        = string
  description = "Branch allowed to deploy to AWS"
  default     = "master"
}

resource "aws_iam_user" "github" {
  name = "event-ingestion-github"
}

resource "aws_iam_role" "github_deploy" {
  name = "event-ingestion-github-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          AWS = aws_iam_user.github.arn
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_user_policy" "github_assume_deploy_role" {
  name = "event-ingestion-github-assume-deploy-role"
  user = aws_iam_user.github.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "sts:AssumeRole",
        ]

        Resource = aws_iam_role.github_deploy.arn
      }
    ]
  })
}

output "github_deploy_role_arn" {
  description = "IAM role used by GitHub Actions deployments"
  value       = aws_iam_role.github_deploy.arn
}
