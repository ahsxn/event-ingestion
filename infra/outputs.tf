output "events_api_id" {
  value = aws_apigatewayv2_api.events.id
}

output "local_events_url" {
  value = "http://localhost:4566/execute-api/${aws_apigatewayv2_api.events.id}/$default/events"
}
