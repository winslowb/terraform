variable "domain_name" {
  type        = string
  description = "The FQDN for the site (e.g. site.example.com)"
}

variable "zone_name" {
  type        = string
  description = "Parent Route 53 zone name (e.g. example.com.)"
}

variable "cloudfront_domain_name" {
  type        = string
  description = "The CloudFront distribution domain name"
}

variable "cloudfront_zone_id" {
  type        = string
  description = "The CloudFront hosted zone ID"
}
