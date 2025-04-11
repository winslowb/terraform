variable "bucket_name" {
  type        = string
  description = "S3 bucket name (must be globally unique)"
}

variable "domain_name" {
  type        = string
  description = "Full site domain (e.g., site.doit.com)"
}

variable "zone_name" {
  type        = string
  description = "Route53 zone name (must end in a dot, e.g., doit.com.)"
}
