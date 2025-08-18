resource "aws_s3_bucket" "app" {
  bucket        = local.app_bucket
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket" "data" {
  bucket        = local.data_bucket
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket" "backup" {
  bucket        = local.backup_bucket
  force_destroy = true
  tags          = var.tags
}
resource "aws_s3_bucket_versioning" "v_app" {
  bucket = aws_s3_bucket.app.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "v_data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "v_back" {
  bucket = aws_s3_bucket.backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "enc" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.app.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "enc_app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.app.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "enc_backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.app.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "noncurrent-deep-archive-30d"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "DEEP_ARCHIVE"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      expired_object_delete_marker = true
    }
  }
}
