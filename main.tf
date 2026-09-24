
locals {
  logging_bucket = "${var.domain_name}-${var.logging_bucket_name}"
}

module "storage" {
  source                      = "./storage"
  website_domain_name         = var.domain_name
  logging_bucket_name         = local.logging_bucket
  cloudfront_arn              = module.web.cloudfront_arn
  cloudfront_distribution_arn = module.web.cloudfront_distribution_arn
  sfn_arn                     = module.compute.sfn_arn

}

module "web" {
  source                             = "./web"
  domain_name                        = var.domain_name
  website_domain                     = module.storage.website_domain
  hosted_zone_id                     = module.storage.website_zone_id
  website_endpoint                   = module.storage.website_endpoint
  images_bucket_name                 = module.storage.images_bucket_name
  images_bucket_regional_domain_name = module.storage.images_bucket_regional_domain_name
  logging_bucket_name                = module.storage.logging_bucket_name
  access_logs_bucket_arn             = module.storage.access_logs_bucket_arn
}

module "compute" {
  source                = "./compute"
  images_bucket_name    = module.storage.images_bucket_name
  image_bucket_arn      = module.storage.image_bucket_arn
  domain_name           = var.domain_name
  dynambo_db_table_name = module.storage.dynambo_db_table_name
}
module "project" {
  source                   = "./project"
  domain_name              = var.domain_name
  gitlab_token             = var.gitlab_token
  gitlab_clone_project_url = var.gitlab_clone_project_url
  ssl_cert_arn             = module.web.ssl_cert_arn
  app_domain_prefix        = var.app_domain_prefix
}

module "api" {
  source                  = "./api"
  domain_name             = var.domain_name
  lambda_integration_uris = module.compute.lambda_integration_uris
  lambda_function_names   = module.compute.lambda_function_names
}

module "queue" {
  source      = "./queue"
  domain_name = var.domain_name
}