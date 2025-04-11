output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_zone_id" {
  value = aws_cloudfront_distribution.cdn.hosted_zone_id
}
