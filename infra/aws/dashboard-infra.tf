resource "aws_ecr_repository" "dashboard" {
  name = "event-ingestion-dashboard"

  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "event-ingestion-dashboard"
  }
}

resource "aws_cloudwatch_log_group" "dashboard" {
  name              = "/ecs/event-ingestion-dashboard"
  retention_in_days = 7

  tags = {
    Name = "event-ingestion-dashboard"
  }
}

resource "aws_secretsmanager_secret" "dashboard_app_key" {
  name = "event-ingestion/dashboard/app-key"

  recovery_window_in_days = 0

  tags = {
    Name = "event-ingestion-dashboard-app-key"
  }
}
