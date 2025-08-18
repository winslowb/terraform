
resource "aws_kms_key" "app" {
  description             = "${var.project} CMK"
  deletion_window_in_days = 7
  multi_region            = true
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "app" {
  name          = "alias/${var.project}-kms"
  target_key_id = aws_kms_key.app.key_id
}
