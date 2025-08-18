variable "project" {
  type    = string
  default = "chet"
}

variable "root_domain" {
  type        = string
  description = "Hosted zone domain, e.g., ebwinslow.com"
}

variable "app_subdomain" {
  type    = string
  default = "chet"
}

variable "google_client_id" {
  type    = string
  default = ""
}

variable "google_client_secret" {
  type    = string
  default = ""
}

variable "openai_api_key" {
  type      = string
  sensitive = true
}

variable "backup_hour_utc" {
  type    = number
  default = 7
}

variable "tags" {
  type = map(string)
  default = {
    app = "chet"
    env = "prod"
  }
}
