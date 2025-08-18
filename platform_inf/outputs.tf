
output "cloudfront_domain" { value = aws_cloudfront_distribution.app.domain_name }
output "app_url" { value = "https://${local.app_fqdn}" }
output "api_endpoint" { value = aws_apigatewayv2_api.http.api_endpoint }
output "cognito_user_pool_id" { value = aws_cognito_user_pool.pool.id }
output "cognito_client_id" { value = aws_cognito_user_pool_client.client.id }
output "identity_pool_id" { value = aws_cognito_identity_pool.idp.id }
