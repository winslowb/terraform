variable "bucket_regional_domain_name" {
  type        = string
  description = "S3 regional domain name"
}

variable "index_document" {
  type        = string
  default     = "index.html"
  description = "Default root document for CloudFront"
}

variable "domain_aliases" {
  type        = list(string)
  description = "Custom domain aliases for the distribution"
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS"
}
