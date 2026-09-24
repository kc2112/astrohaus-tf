
variable "domain_name" {
  type = string
}

variable "website_domain" {
  type = string
}

variable "hosted_zone_id" {
  type = string
}

variable "website_endpoint" {
  type = string
}

variable "logging_bucket_name" {
  type = string
}

variable "access_logs_policy_id" {
  type    = string
  default = null
}

variable "access_logs_bucket_arn" {
  type = string
}

variable "images_bucket_name" {
  type = string
}

variable "images_bucket_regional_domain_name" {
  type = string
}