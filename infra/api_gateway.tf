resource "aws_apigatewayv2_api" "events" {
  name          = "event-ingestion"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "ingest" {
  api_id = aws_apigatewayv2_api.events.id

  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ingest.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "events" {
  api_id = aws_apigatewayv2_api.events.id

  route_key = "POST /events"

  target = "integrations/${aws_apigatewayv2_integration.ingest.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.events.id

  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id = "AllowApiGatewayInvoke"

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.events.execution_arn}/*/*"
}
