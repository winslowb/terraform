resource "aws_acm_certificate" "app" {
  provider          = aws.use1
  domain_name       = local.app_fqdn
  validation_method = "DNS"
  tags              = var.tags
}

data "aws_route53_zone" "root" {
  name         = "${var.root_domain}."
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.root.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "app" {
  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${local.app_bucket}-oac"
  description                       = "OAC for SPA bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "app" {
  enabled             = true
  price_class         = "PriceClass_100"
  default_root_object = "index.html"
  aliases             = [local.app_fqdn]

  origin {
    origin_id                = "s3-app"
    domain_name              = aws_s3_bucket.app.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-app"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.app.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = var.tags
}

resource "aws_s3_bucket_policy" "app" {
  bucket = aws_s3_bucket.app.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowCloudFrontOACRead",
      Effect    = "Allow",
      Principal = { Service = "cloudfront.amazonaws.com" },
      Action    = ["s3:GetObject"],
      Resource  = ["${aws_s3_bucket.app.arn}/*"],
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.app.arn
        }
      }
    }]
  })
}

resource "aws_route53_record" "app_alias_a" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.app_fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.app.domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}
