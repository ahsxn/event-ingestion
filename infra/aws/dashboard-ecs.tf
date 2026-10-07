resource "aws_iam_role" "dashboard_execution" {
  name = "event-ingestion-dashboard-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dashboard_execution" {
  role = aws_iam_role.dashboard_execution.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "dashboard_execution_secrets" {
  name = "event-ingestion-dashboard-secrets"
  role = aws_iam_role.dashboard_execution.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue",
        ]

        Resource = aws_secretsmanager_secret.dashboard_app_key.arn
      }
    ]
  })
}

resource "aws_iam_role" "dashboard_task" {
  name = "event-ingestion-dashboard-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "dashboard" {
  name = "event-ingestion-dashboard"
  role = aws_iam_role.dashboard_task.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:Query",
        ]

        Resource = aws_dynamodb_table.metrics.arn
      }
    ]
  })
}

resource "aws_ecs_task_definition" "dashboard" {
  family = "event-ingestion-dashboard"

  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"

  execution_role_arn = aws_iam_role.dashboard_execution.arn
  task_role_arn      = aws_iam_role.dashboard_task.arn

  container_definitions = jsonencode([
    {
      name      = "dashboard"
      image     = "${aws_ecr_repository.dashboard.repository_url}:dev"
      essential = true

      cpu               = 256
      memoryReservation = 256
      memory            = 512

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "APP_ENV"
          value = "production"
        },
        {
          name  = "APP_DEBUG"
          value = "false"
        },
        {
          name  = "APP_URL"
          value = "http://${data.aws_eip.ecs_host.public_ip}"
        },
        {
          name  = "LOG_CHANNEL"
          value = "stderr"
        },
        {
          name  = "LOG_LEVEL"
          value = "info"
        },
        {
          name  = "SESSION_DRIVER"
          value = "file"
        },
        {
          name  = "CACHE_STORE"
          value = "file"
        },
        {
          name  = "QUEUE_CONNECTION"
          value = "sync"
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "EVENT_INGESTION_URL"
          value = "${aws_apigatewayv2_api.ingest.api_endpoint}/events"
        },
      ]

      secrets = [
        {
          name      = "APP_KEY"
          valueFrom = aws_secretsmanager_secret.dashboard_app_key.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dashboard.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "dashboard"
        }
      }
    }
  ])

  tags = {
    Name = "event-ingestion-dashboard"
  }
}

resource "aws_ecs_service" "dashboard" {
  name    = "event-ingestion-dashboard"
  cluster = aws_ecs_cluster.main.id

  task_definition = aws_ecs_task_definition.dashboard.arn
  desired_count   = var.services_enabled ? 1 : 0
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  tags = {
    Name = "event-ingestion-dashboard"
  }
}
