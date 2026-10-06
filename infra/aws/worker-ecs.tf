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

resource "aws_iam_role_policy_attachment" "worker_execution" {
  role = aws_iam_role.worker_execution.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
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

resource "aws_iam_role_policy" "worker" {
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
          "kinesis:GetRecords",
          "kinesis:DescribeStreamSummary",
        ]

        Resource = aws_kinesis_stream.events.arn
      },
      {
        Effect = "Allow"

        Action = [
          "dynamodb:TransactWriteItems",
        ]

        Resource = [
          aws_dynamodb_table.metrics.arn,
          aws_dynamodb_table.processed_events.arn,
        ]
      }
    ]
  })
}

resource "aws_ecs_task_definition" "worker" {
  family = "event-ingestion-worker"

  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"

  execution_role_arn = aws_iam_role.worker_execution.arn
  task_role_arn      = aws_iam_role.worker_task.arn

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = "${aws_ecr_repository.worker.repository_url}:dev"
      essential = true

      cpu               = 128
      memoryReservation = 128
      memory            = 256

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
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
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.worker.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "worker"
        }
      }
    }
  ])

  tags = {
    Name = "event-ingestion-worker"
  }
}

resource "aws_ecs_service" "worker" {
  name    = "event-ingestion-worker"
  cluster = aws_ecs_cluster.main.id

  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = 1
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  tags = {
    Name = "event-ingestion-worker"
  }
}
