data "archive_file" "rt_zip" {
  type        = "zip"
  source_file = "lambda_sources/handlers.py"
  output_path = "build/${local.lambda_rt}.zip"
}

data "archive_file" "ai_zip" {
  type        = "zip"
  source_file = "lambda_sources/handlers.py"
  output_path = "build/${local.lambda_ai}.zip"
}

data "archive_file" "sync_zip" {
  type        = "zip"
  source_file = "lambda_sources/handlers.py"
  output_path = "build/${local.lambda_sync}.zip"
}

data "archive_file" "backup_zip" {
  type        = "zip"
  source_file = "lambda_sources/handlers.py"
  output_path = "build/${local.lambda_backup}.zip"
}

resource "aws_lambda_function" "rt" {
  function_name    = local.lambda_rt
  role             = aws_iam_role.lambda.arn
  handler          = "handlers.rt_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.rt_zip.output_path
  source_code_hash = data.archive_file.rt_zip.output_base64sha256
  timeout          = 15
  memory_size      = 256

  environment {
    variables = {
      OPENAI_SECRET_NAME = local.secret_openai
    }
  }

  tags = var.tags
}

resource "aws_lambda_function" "ai" {
  function_name    = local.lambda_ai
  role             = aws_iam_role.lambda.arn
  handler          = "handlers.ai_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.ai_zip.output_path
  source_code_hash = data.archive_file.ai_zip.output_base64sha256
  timeout          = 30
  memory_size      = 512

  environment {
    variables = {
      OPENAI_SECRET_NAME = local.secret_openai
      META_TABLE         = aws_dynamodb_table.meta.name
      PROMPTS_TABLE      = aws_dynamodb_table.prompts.name
      DATA_BUCKET        = aws_s3_bucket.data.bucket
    }
  }

  tags = var.tags
}

resource "aws_lambda_function" "sync" {
  function_name    = local.lambda_sync
  role             = aws_iam_role.lambda.arn
  handler          = "handlers.sync_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.sync_zip.output_path
  source_code_hash = data.archive_file.sync_zip.output_base64sha256
  timeout          = 30
  memory_size      = 512

  environment {
    variables = {
      DATA_BUCKET = aws_s3_bucket.data.bucket
      KMS_KEY_ID  = aws_kms_key.app.key_id
    }
  }

  tags = var.tags
}

resource "aws_lambda_function" "backup" {
  function_name    = local.lambda_backup
  role             = aws_iam_role.lambda.arn
  handler          = "handlers.backup_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.backup_zip.output_path
  source_code_hash = data.archive_file.backup_zip.output_base64sha256
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      DATA_BUCKET   = aws_s3_bucket.data.bucket
      BACKUP_BUCKET = aws_s3_bucket.backup.bucket
    }
  }

  tags = var.tags
}
