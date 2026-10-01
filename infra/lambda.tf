resource "aws_iam_role" "ingest" {
  name = "event-ingest"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ingest_kinesis" {
  name = "kinesis-put-record"
  role = aws_iam_role.ingest.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "kinesis:PutRecord"
        ]

        Resource = aws_kinesis_stream.events.arn
      }
    ]
  })
}

resource "aws_lambda_function" "ingest" {
  function_name = "event-ingest"

  role    = aws_iam_role.ingest.arn
  runtime = "provided.al2023"
  handler = "bootstrap"

  filename = "${path.module}/../build/ingest/function.zip"

  source_code_hash = filebase64sha256(
    "${path.module}/../build/ingest/function.zip"
  )

  timeout = 5

  environment {
    variables = {
      KINESIS_STREAM_NAME = aws_kinesis_stream.events.name
    }
  }

  depends_on = [
    aws_iam_role_policy.ingest_kinesis
  ]
}
