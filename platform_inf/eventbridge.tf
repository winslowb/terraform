
resource "aws_cloudwatch_event_rule" "daily" {
  name                = "${var.project}-daily-backup"
  schedule_expression = "cron(0 ${var.backup_hour_utc} * * ? *)"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "daily_to_lambda" {
  rule = aws_cloudwatch_event_rule.daily.name
  arn  = aws_lambda_function.backup.arn
}

resource "aws_lambda_permission" "events_invoke_backup" {
  statement_id  = "AllowEventsInvokeBackup"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily.arn
}
