
output "gitlab_link" {
  value = gitlab_project.primary_application.http_url_to_repo
}

output "primary_application_url" {
  value = "https://${var.app_domain_prefix}.${aws_amplify_domain_association.main.domain_name}"
}