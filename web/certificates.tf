resource "aws_acm_certificate" "primary_domain_cert" {
  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = [var.domain_name, "*.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "certificate_validation" {
  certificate_arn         = aws_acm_certificate.primary_domain_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_cert_records : record.fqdn]
}