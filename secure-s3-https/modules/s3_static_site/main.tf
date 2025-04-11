resource "aws_s3_bucket" "static_site" {
  bucket = var.bucket_name

  tags = {
    Name = "Secure S3 Static Site"
  }
}

resource "aws_s3_bucket_website_configuration" "static_site_web" {
  bucket = aws_s3_bucket.static_site.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket                  = aws_s3_bucket.static_site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "default_index" {
  bucket = aws_s3_bucket.static_site.bucket
  key    = "index.html"
  content = <<-EOT
    <html>
    <head><title>Hello World</title></head>
    <body>
      <h1>Hello, world! \M/</h1>
      <p>This site is deployed.</p>
    </body>
    </html>
  EOT
  content_type = "text/html"
}
