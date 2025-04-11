module "s3_static_site" {
  source      = "./modules/s3_static_site"
  bucket_name = var.bucket_name
}

module "cert_dns" {
  source      = "./modules/cert_dns"
  domain_name = var.domain_name
  zone_name   = var.zone_name
}

module "cloudfront_cdn" {
  source                      = "./modules/cloudfront_cdn"
  bucket_regional_domain_name = module.s3_static_site.bucket_regional_domain_name
  certificate_arn             = module.cert_dns.certificate_arn
  index_document              = "index.html"
  domain_aliases              = [var.domain_name]
}

module "route53_record" {
  source                 = "./modules/route53_record"
  domain_name            = var.domain_name
  zone_name              = var.zone_name
  cloudfront_domain_name = module.cloudfront_cdn.cloudfront_domain_name
  cloudfront_zone_id     = module.cloudfront_cdn.cloudfront_zone_id
}
