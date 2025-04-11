provider "aws" {
  region = "us-east-1"  # Use your preferred region
  # profile = "default" # uncomment this if you have a proflie named 'default' or change the value to whatever the profile/account you are using
}

resource "aws_s3_bucket_website_configuration" "static_site_web" {
  bucket = aws_s3_bucket.static_site.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket" "static_site" {
  bucket = "my-secure-static-site-1234" # must be globally unique

  tags = {
    Name        = "Secure S3 Static Site"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.static_site.id

  block_public_acls   = true
  block_public_policy = false
  ignore_public_acls  = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_cf_access" {
  bucket = aws_s3_bucket.static_site.id
  policy = data.aws_iam_policy_document.allow_cf_access_policy.json
}

data "aws_iam_policy_document" "allow_cf_access_policy" {
  statement {
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static_site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }

    effect = "Allow"
  }
}

resource "aws_s3_object" "default_index" {
  bucket = aws_s3_bucket.static_site.bucket
  key    = "index.html"
  content = <<-EOT
    <html>
    <head><title>Hello World</title></head>
    <body>
      <h1>Hello, world! \M/</h1>
      <p>Next steps: </p>
      <p> - replace this index.html with your custom content.
    </body>
    </html>
  EOT

  content_type = "text/html"
}

resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "secure-s3-access-control"
  description                       = "OAC for secure static S3 site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_id   = "s3-static-site"

    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-static-site"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }


viewer_certificate {
  acm_certificate_arn            = aws_acm_certificate.site_cert.arn
  ssl_support_method             = "sni-only"
  minimum_protocol_version       = "TLSv1.2_2021"
}

aliases = ["site.ebwinslow.com"]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name        = "Secure S3 CDN"
    Environment = "Dev"
  }
}


resource "aws_acm_certificate" "site_cert" {
  domain_name       = "site.ebwinslow.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "Site TLS Certificate"
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "site_cert_validation" {
  certificate_arn         = aws_acm_certificate.site_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

data "aws_route53_zone" "primary" {
  name         = "ebwinslow.com."
  private_zone = false
}

resource "aws_route53_record" "site_alias" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "site.ebwinslow.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}
