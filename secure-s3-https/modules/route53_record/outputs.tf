# Not strictly needed, but nice to have if you want to output the record name
output "record_name" {
  value = aws_route53_record.cdn_alias.name
}
