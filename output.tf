

output "image_bucket_name" {
  value = module.storage.images_bucket_name
}

output "domain_name" {
  value = module.storage.website_domain
}

output "gitlab_link" {
  value = module.project.gitlab_link
}

output "app_url" {
  value = module.project.primary_application_url
}