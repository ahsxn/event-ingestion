resource "aws_cloudwatch_log_group" "ingest" {
  name = "/aws/lambda/event-ingest"

  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "worker" {
  name = "/ecs/event-ingest-worker"

  retention_in_days = 7
}
