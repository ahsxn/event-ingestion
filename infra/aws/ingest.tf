resource "aws_iam_role" "ingest" {
  name = "event-ingestion-ingest"

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

resource "aws_iam_role_policy_attachment" "ingest_logs" {
  role = aws_iam_role.ingest.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "ingest" {
  name = "event-ingestion-ingest"
  role = aws_iam_role.ingest.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "kinesis:PutRecord",
        ]

        Resource = aws_kinesis_stream.events.arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "ingest" {
  name              = "/aws/lambda/event-ingest"
  retention_in_days = 7

  tags = {
    Name = "event-ingest"
  }
}

resource "aws_lambda_function" "ingest" {
  function_name = "event-ingest"

  role    = aws_iam_role.ingest.arn
  handler = "bootstrap"
  runtime = "provided.al2023"

  architectures = ["x86_64"]

  filename = "${path.module}/../../build/ingest/function.zip"

  source_code_hash = filebase64sha256(
    "${path.module}/../../build/ingest/function.zip"
  )

  memory_size = 128
  timeout     = 10

  environment {
    variables = {
      KINESIS_STREAM_NAME = aws_kinesis_stream.events.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.ingest,
    aws_iam_role_policy_attachment.ingest_logs,
    aws_iam_role_policy.ingest,
  ]

  tags = {
    Name = "event-ingest"
  }
}

resource "aws_apigatewayv2_api" "ingest" {
  name          = "event-ingestion"
  protocol_type = "HTTP"

  tags = {
    Name = "event-ingestion"
  }
}

resource "aws_apigatewayv2_integration" "ingest" {
  api_id = aws_apigatewayv2_api.ingest.id

  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.ingest.invoke_arn
  integration_method = "POST"

  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "events" {
  api_id = aws_apigatewayv2_api.ingest.id

  route_key = "POST /events"

  target = "integrations/${aws_apigatewayv2_integration.ingest.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.ingest.id

  name        = "$default"
  auto_deploy = true

  tags = {
    Name = "event-ingestion-default"
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id = "AllowAPIGatewayInvoke"

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.ingest.execution_arn}/*/*"
}
