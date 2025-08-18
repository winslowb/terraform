
resource "aws_iam_role" "lambda" {
  name = "${var.project}-lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

# Least-privilege: allow exactly what functions need
data "aws_iam_policy_document" "lambda_inline" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.openai.arn, aws_secretsmanager_secret.google.arn]
  }
  statement {
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = [aws_kms_key.app.arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*", aws_s3_bucket.backup.arn, "${aws_s3_bucket.backup.arn}/*"]
  }
  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.meta.arn, aws_dynamodb_table.prompts.arn]
  }
}

resource "aws_iam_role_policy" "lambda_inline" {
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_inline.json
}
