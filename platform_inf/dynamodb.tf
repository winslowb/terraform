resource "aws_dynamodb_table" "meta" {
  name         = local.ddb_meta
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.app.arn
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "prompts" {
  name         = local.ddb_prompts
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "owner"
  range_key    = "name"

  attribute {
    name = "owner"
    type = "S"
  }

  attribute {
    name = "name"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.app.arn
  }

  tags = var.tags
}
