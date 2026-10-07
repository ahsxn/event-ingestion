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

data "aws_caller_identity" "current" {}

locals {
  github_managed_role_arns = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/event-ingestion-ecs-instance",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/event-ingestion-ingest",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/event-ingestion-worker-execution",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/event-ingestion-worker-task",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/event-ingestion-dashboard-execution",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/event-ingestion-dashboard-task",
  ]

  github_instance_profile_arns = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/event-ingestion-ecs-instance",
  ]
}

resource "aws_iam_role_policy" "github_deploy" {
  name = "event-ingestion-github-deploy"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "TerraformStateBucket"
        Effect = "Allow"

        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]

        Resource = "arn:aws:s3:::event-ingestion-tfstate-523741415941"
      },
      {
        Sid    = "TerraformStateObjects"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]

        Resource = "arn:aws:s3:::event-ingestion-tfstate-523741415941/portfolio/*"
      },
      {
        Sid    = "ProjectServices"
        Effect = "Allow"

        Action = [
          "ec2:*",
          "ecs:*",
          "ecr:*",
          "lambda:*",
          "apigateway:*",
          "dynamodb:*",
          "kinesis:*",
          "logs:*",
          "secretsmanager:*",
        ]

        Resource = "*"

        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "ProtectPersistentElasticIP"
        Effect = "Deny"

        Action = [
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
        ]

        Resource = "*"
      },
      {
        Sid    = "ReadECSOptimizedAMI"
        Effect = "Allow"

        Action = [
          "ssm:GetParameter",
        ]

        Resource = "arn:aws:ssm:${var.aws_region}::parameter/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
      },
      {
        Sid    = "ManageApplicationRoles"
        Effect = "Allow"

        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
        ]

        Resource = local.github_managed_role_arns
      },
      {
        Sid    = "ManageApplicationInstanceProfile"
        Effect = "Allow"

        Action = [
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:UntagInstanceProfile",
        ]

        Resource = concat(
          local.github_managed_role_arns,
          local.github_instance_profile_arns,
        )
      },
      {
        Sid    = "PassApplicationRoles"
        Effect = "Allow"

        Action = [
          "iam:PassRole",
        ]

        Resource = local.github_managed_role_arns

        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "ec2.amazonaws.com",
              "ecs-tasks.amazonaws.com",
              "lambda.amazonaws.com",
            ]
          }
        }
      }
    ]
  })
}
