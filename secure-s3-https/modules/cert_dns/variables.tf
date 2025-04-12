variable "domain_name" {
  type        = string
  description = "The FQDN to generate a cert for (e.g. site.doit.com)"
}

variable "zone_name" {
  type        = string
  description = "The parent Route 53 zone (must end in a dot, e.g. doit.com.)"
}
