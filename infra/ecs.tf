resource "aws_ecs_cluster" "worker" {
  name = "event-ingestion"
}

resource "aws_iam_role" "worker_task" {
  name = "event-ingestion-worker-task"

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

resource "aws_iam_role_policy" "worker_task" {
  name = "event-ingestion-worker"
  role = aws_iam_role.worker_task.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "kinesis:ListShards",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords"
        ]

        Resource = aws_kinesis_stream.events.arn
      },
      {
        Effect = "Allow"

        Action = [
          "dynamodb:TransactWriteItems"
        ]

        Resource = [
          aws_dynamodb_table.metrics.arn,
          aws_dynamodb_table.processed_events.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "worker_execution" {
  name = "event-ingestion-worker-execution"

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

resource "aws_iam_role_policy" "worker_execution" {
  name = "ecr-pull"
  role = aws_iam_role.worker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]

        Resource = aws_ecr_repository.worker.arn
      }
    ]
  })
}

resource "aws_ecs_task_definition" "worker" {
  family = "event-ingestion-worker"

  requires_compatibilities = [
    "FARGATE"
  ]

  network_mode = "awsvpc"

  cpu    = "256"
  memory = "512"

  task_role_arn      = aws_iam_role.worker_task.arn
  execution_role_arn = aws_iam_role.worker_execution.arn

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = "${aws_ecr_repository.worker.repository_url}:dev"
      essential = true

      stopTimeout = 30

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.worker.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "worker"
        }
      }

      environment = [
        {
          name  = "AWS_ENDPOINT_URL"
          value = "http://floci:4566"
        },
        {
          name  = "AWS_REGION"
          value = "us-east-1"
        },
        {
          name  = "AWS_ACCESS_KEY_ID"
          value = "test"
        },
        {
          name  = "AWS_SECRET_ACCESS_KEY"
          value = "test"
        },
        {
          name  = "KINESIS_STREAM_NAME"
          value = aws_kinesis_stream.events.name
        },
        {
          name  = "METRICS_TABLE_NAME"
          value = aws_dynamodb_table.metrics.name
        },
        {
          name  = "PROCESSED_EVENTS_TABLE_NAME"
          value = aws_dynamodb_table.processed_events.name
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "worker" {
  name    = "event-ingestion-worker"
  cluster = aws_ecs_cluster.worker.id

  task_definition = aws_ecs_task_definition.worker.arn

  desired_count = 1
  launch_type   = "FARGATE"

  depends_on = [
    aws_iam_role_policy.worker_task,
    aws_iam_role_policy.worker_execution
  ]
}

resource "aws_iam_role_policy" "worker_execution_logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.worker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "${aws_cloudwatch_log_group.worker.arn}:*"
      }
    ]
  })
}
