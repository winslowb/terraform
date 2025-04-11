output "bucket_name" {
  value = aws_s3_bucket.static_site.bucket
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.static_site.bucket_regional_domain_name
}
