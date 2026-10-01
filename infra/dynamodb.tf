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
}
