data "aws_route53_zone" "main" { name = "devopswithdev.com." }

resource "aws_acm_certificate" "main" {
  domain_name               = "devopswithdev.com"
  subject_alternative_names = ["*.devopswithdev.com"]
  validation_method         = "DNS"
  lifecycle { create_before_destroy = true }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => dvo
  }
  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# All subdomains point at the same ALB.
# Gateway API routing rules (HTTPRoute) determine which service each domain hits.
locals {
  subdomains = {
    apex      = "devopswithdev.com"
    api       = "api"
    dev       = "dev"
    dev_api   = "dev-api"
    argocd    = "argocd"
    grafana   = "grafana"
  }
}

resource "aws_route53_record" "records" {
  for_each = local.subdomains
  zone_id  = data.aws_route53_zone.main.zone_id
  name     = each.value
  type     = "A"
  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}