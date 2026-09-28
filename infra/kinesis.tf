resource "aws_kinesis_stream" "events" {
  name        = "commerce-stream-events"
  shard_count = 1
}
