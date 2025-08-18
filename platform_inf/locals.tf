
locals {
  app_fqdn      = "${var.app_subdomain}.${var.root_domain}"
  app_bucket    = "${data.aws_caller_identity.me.account_id}-${var.project}-app"
  data_bucket   = "${data.aws_caller_identity.me.account_id}-${var.project}-data"
  backup_bucket = "${data.aws_caller_identity.me.account_id}-${var.project}-backups"

  secret_openai = "${var.project}/openai/api_key"
  secret_google = "${var.project}/google/oauth"

  ddb_meta    = "${var.project}-meta"
  ddb_prompts = "${var.project}-prompts"

  lambda_rt     = "${var.project}-auth-ephemeral"
  lambda_ai     = "${var.project}-ai-router"
  lambda_sync   = "${var.project}-sync"
  lambda_backup = "${var.project}-daily-backup"

  http_api_name = "${var.project}-http-api"
}
