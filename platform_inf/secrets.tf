resource "aws_secretsmanager_secret" "openai" {
  name = local.secret_openai
  recovery_window_in_days = 0
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "openai_v" {
  secret_id     = aws_secretsmanager_secret.openai.id
  secret_string = jsonencode({ api_key = var.openai_api_key })
}

resource "aws_secretsmanager_secret" "google" {
  name = local.secret_google
  recovery_window_in_days = 0
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "google_v" {
  secret_id = aws_secretsmanager_secret.google.id
  secret_string = jsonencode({
    client_id     = var.google_client_id
    client_secret = var.google_client_secret
    redirect_uri  = "https://${local.app_fqdn}/auth/google/callback"
  })
}
