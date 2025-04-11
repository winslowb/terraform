data "aws_route53_zone" "selected" {
  name         = var.zone_name
  private_zone = false
}

resource "aws_route53_record" "cdn_alias" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}
