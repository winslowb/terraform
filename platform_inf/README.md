# Platform Infrastructure (Terraform)

This folder provisions the “platform” for the Chet app as a fully serverless stack on AWS. It hosts a static web app on CloudFront + S3, exposes backend APIs via API Gateway + Lambda, handles authentication with Cognito, stores data in S3 and DynamoDB (all KMS‑encrypted), manages secrets with Secrets Manager, and runs daily backups via EventBridge. A monthly cost budget with email alerts is also configured.

## What It Builds
- CloudFront + ACM + Route53: HTTPS CDN for the SPA at `https://<app_subdomain>.<root_domain>` using a DNS‑validated certificate in `us-east-1`, with an Origin Access Control to the S3 app bucket.
- S3 buckets:
  - `app` bucket: hosts the frontend (served only through CloudFront via OAC).
  - `data` bucket: stores user data/snapshots with versioning and KMS SSE; lifecycle moves noncurrent versions to Glacier Deep Archive after 30 days.
  - `backups` bucket: holds daily backups copied from `data`.
- KMS: a customer‑managed, rotating CMK used by S3 and DynamoDB.
- API Gateway (HTTP API): public API with these routes wired to Lambda:
  - `POST /auth/ephemeral` → `rt` Lambda: creates ephemeral OpenAI Realtime tokens.
  - `POST /ai/{proxy+}` → `ai` Lambda: AI endpoints (task/note generation, tagging, summarization).
  - `POST /sync/{proxy+}` → `sync` Lambda: presigned URLs (upload/download) and simple object listing for client sync.
- Lambda functions (Python 3.12; code in `lambda_sources/handlers.py`, packaged via `archive_file`):
  - `chet-auth-ephemeral` (`rt_handler`) – OpenAI Realtime session token minting.
  - `chet-ai-router` (`ai_handler`) – Structured Outputs and summaries via OpenAI.
  - `chet-sync` (`sync_handler`) – S3 presign/list utilities (uses KMS for SSE).
  - `chet-daily-backup` (`backup_handler`) – copies all versions from `data` → `backups` daily.
- Cognito: User Pool + Web Client (OAuth code flow) and an Identity Pool with an authenticated role that can call the API and access the `data` bucket.
- DynamoDB: two KMS‑encrypted tables for app metadata and saved prompts (`<project>-meta`, `<project>-prompts`).
- IAM: least‑privilege role/policy for the Lambdas (logs, Secrets Manager reads, KMS, S3 data/backups, DynamoDB tables).
- EventBridge: a daily rule (UTC hour configurable) invoking the backup Lambda.
- Budgets: a monthly cost budget with ACTUAL and FORECASTED email alerts.

## Key Files
- `providers.tf`: AWS providers (primary region + `us-east-1` alias for ACM/CloudFront).
- `variables.tf`: inputs for project name, root domain, app subdomain, OpenAI/Google creds, backup hour, and tags.
- `locals.tf`: derived names (buckets, tables, Lambda names, FQDN, secret paths).
- `s3.tf`: app/data/backup buckets, versioning, SSE‑KMS, lifecycle.
- `cloudfront.tf`: certificate, distribution with OAC, Route53 alias record.
- `apigw.tf`: HTTP API, integrations, routes, stage, and Lambda invoke permissions.
- `lambda.tf`: package and deploy the four Lambdas; env vars for tables/buckets/secrets.
- `cognito.tf`: user pool, client, identity pool, and authenticated role/policy.
- `dynamodb.tf`: `meta` and `prompts` tables with SSE‑KMS.
- `kms.tf`: CMK and alias used by S3/DynamoDB and presigned uploads.
- `secrets.tf`: Secrets Manager secrets/versions for OpenAI and Google OAuth.
- `eventbridge.tf`: daily backup trigger to `backup` Lambda.
- `budget.tf`: monthly spend budget and email alerts.
- `outputs.tf`: handy outputs (app URL, API endpoint, Cognito IDs, CloudFront domain).

## Prerequisites
- An AWS account and credentials configured for Terraform.
- A public Route53 hosted zone for your `root_domain` (e.g., `example.com`).
- Ownership/control of the subdomain in Route53 (`app_subdomain.root_domain`) for DNS validation and alias record.

## Required Inputs
Provide via `terraform.tfvars` or `-var` flags:
- `region`: AWS region for the stack (CloudFront cert is handled in `us-east-1` automatically).
- `root_domain`: Base domain hosted in Route53 (e.g., `example.com`).
- `app_subdomain`: Subdomain for the app (e.g., `chet`).
- `openai_api_key`: Your OpenAI API key (stored into Secrets Manager).
- `google_client_id`, `google_client_secret`: Google OAuth credentials used by the web client.
- `budget_alert_email`: Email to receive AWS Budget alerts.

Optional:
- `backup_hour_utc` (default 7): UTC hour for the daily backup rule.
- `tags`: Map of tags applied to all resources.

## Deploy
From this folder:
1) Initialize providers
- `terraform init`

2) Review the plan (fill inputs in `terraform.tfvars` or pass with `-var`):
- `terraform plan`

3) Apply
- `terraform apply`

After apply, check outputs for:
- `app_url`: canonical HTTPS URL for the app.
- `api_endpoint`: base URL of the HTTP API.
- Cognito IDs: user pool, client, and identity pool.
- `cloudfront_domain`: CloudFront distribution domain (useful before DNS propagates).

DNS note: ACM is DNS‑validated and the `A` alias record is created automatically. Allow time for certificate issuance and CloudFront propagation.

## Security Notes
- All storage is KMS‑encrypted (S3 buckets and DynamoDB tables). Buckets have versioning; `data` transitions noncurrent versions to Deep Archive at 30 days.
- The app S3 bucket is not public; CloudFront uses OAC and a bucket policy to restrict reads to the distribution.
- Lambda role policy is least‑privilege for logs, Secrets Manager, KMS, S3 data/backup, and the two DynamoDB tables.
- API handlers set CORS `access-control-allow-origin: *`. Tighten if needed for your domain.

## Lambda Endpoints (Summary)
- `POST /auth/ephemeral`: returns short‑lived OpenAI Realtime client_secret value.
- `POST /ai/generate_tasks|generate_note|auto_tags|summarize`: AI utilities using OpenAI with structured outputs.
- `POST /sync/upload_url|download_url|list`: presigned S3 operations and simple listings against the `data` bucket.

## Maintenance
- To update Lambda code, edit `lambda_sources/handlers.py`; Terraform’s `archive_file` data sources recalculate the zip and `source_code_hash`, so a normal `apply` will deploy changes.
- Rotate secrets by updating variables and applying; Secrets Manager keeps versions.
- Adjust the budget threshold, lifecycle policies, or backup schedule via the respective `.tf` files.

## Cleanup
- `terraform destroy` removes all resources. Buckets use `force_destroy = true` to simplify teardown, but take care not to store anything you intend to keep without backups.

---

Troubleshooting tips:
- Certificate issuance requires the Route53 DNS records to exist and propagate; CloudFront won’t become fully active until validation completes.
- If the `app_url` returns 403, ensure the CloudFront OAC bucket policy resource and distribution ID match and that the SPA files exist in the `app` bucket.
- API 403/500 often indicate missing permissions or env vars; check CloudWatch Logs for each Lambda.
