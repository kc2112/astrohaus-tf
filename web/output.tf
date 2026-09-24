output "cloudfront_arn" {
  value = aws_cloudfront_distribution.static_site_distribution.arn
}

output "cloudfront_distribution_arn" {
  value = aws_cloudfront_distribution.static_site_distribution.arn
}

output "ssl_cert_arn" {
  value = aws_acm_certificate.primary_domain_cert.arn
}