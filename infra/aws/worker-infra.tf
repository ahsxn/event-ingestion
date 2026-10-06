resource "aws_ecr_repository" "worker" {
  name = "event-ingestion-worker"

  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "event-ingestion-worker"
  }
}

resource "aws_kinesis_stream" "events" {
  name = "event-ingestion-events"

  shard_count = 1

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Name = "event-ingestion-events"
  }
}

resource "aws_dynamodb_table" "metrics" {
  name         = "event-ingestion-metrics"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "metric"
  range_key = "dimension"

  attribute {
    name = "metric"
    type = "S"
  }

  attribute {
    name = "dimension"
    type = "S"
  }

  tags = {
    Name = "event-ingestion-metrics"
  }
}

resource "aws_dynamodb_table" "processed_events" {
  name         = "event-ingestion-processed-events"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  tags = {
    Name = "event-ingestion-processed-events"
  }
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/event-ingest-worker"
  retention_in_days = 7

  tags = {
    Name = "event-ingest-worker"
  }
}
