resource "aws_route53_zone" "primary_zone" {
  name          = var.domain_name
  force_destroy = true
}

resource "aws_route53_record" "acm_cert_records" {
  for_each = {
    for dvo in aws_acm_certificate.primary_domain_cert.domain_validation_options : dvo.domain_name => {
      zone_id = aws_route53_zone.primary_zone.zone_id
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.primary_zone.zone_id
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary_zone.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  alias {
    evaluate_target_health = true
    name                   = aws_cloudfront_distribution.static_site_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.static_site_distribution.hosted_zone_id
  }
}

resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.primary_zone.zone_id
  type    = "A"
  name    = var.domain_name

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.static_site_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.static_site_distribution.hosted_zone_id
  }
}


#Updates nameservers in domain with NS from hosted zone
resource "aws_route53domains_registered_domain" "primary_domain" {
  domain_name = var.domain_name

  dynamic "name_server" {
    for_each = aws_route53_zone.primary_zone.name_servers
    content {
      name = name_server.value
    }
  }
}
