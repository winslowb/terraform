resource "aws_cognito_user_pool" "pool" {
  name = "${var.project}-user-pool"

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  auto_verified_attributes = ["email"]

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_client" "client" {
  name                                 = "${var.project}-web-client"
  user_pool_id                         = aws_cognito_user_pool.pool.id
  generate_secret                      = true
  explicit_auth_flows                  = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = ["https://${local.app_fqdn}/auth/callback"]
  logout_urls                          = ["https://${local.app_fqdn}/auth/signout"]
  prevent_user_existence_errors        = "ENABLED"
}

resource "aws_cognito_identity_pool" "idp" {
  identity_pool_name               = "${var.project}-identity-pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.client.id
    provider_name           = "cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.pool.id}"
    server_side_token_check = true
  }
}

resource "aws_iam_role" "cognito_auth" {
  name = "${var.project}-cognito-auth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = "cognito-identity.amazonaws.com" },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = { StringEquals = { "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.idp.id } }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cognito_auth_inline" {
  role = aws_iam_role.cognito_auth.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["execute-api:Invoke"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
        Resource = [
          aws_s3_bucket.data.arn,
          "${aws_s3_bucket.data.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_cognito_identity_pool_roles_attachment" "attach" {
  identity_pool_id = aws_cognito_identity_pool.idp.id
  roles = {
    authenticated = aws_iam_role.cognito_auth.arn
  }
}
