resource "aws_apigatewayv2_api" "http" {
  name          = local.http_api_name
  protocol_type = "HTTP"
  tags          = var.tags
}

resource "aws_apigatewayv2_integration" "rt" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.rt.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 10000
}

resource "aws_apigatewayv2_integration" "ai" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ai.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 10000
}

resource "aws_apigatewayv2_integration" "sync" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.sync.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 10000
}

resource "aws_apigatewayv2_route" "rt" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /auth/ephemeral"
  target    = "integrations/${aws_apigatewayv2_integration.rt.id}"
}

resource "aws_apigatewayv2_route" "ai" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /ai/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.ai.id}"
}

resource "aws_apigatewayv2_route" "sync" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /sync/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.sync.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "prod"
  auto_deploy = true
}

resource "aws_lambda_permission" "rt" {
  statement_id  = "AllowInvokeRt"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rt.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "ai" {
  statement_id  = "AllowInvokeAi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "sync" {
  statement_id  = "AllowInvokeSync"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sync.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
