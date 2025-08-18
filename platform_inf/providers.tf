variable "region" { type = string }
provider "aws" { region = var.region }

# CloudFront requires ACM in us-east-1
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

