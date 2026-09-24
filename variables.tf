
variable "domain_name" {
  type    = string
  default = "kc2112.com"
}

variable "logging_bucket_name" {
  type    = string
  default = "logging"
}

variable "gitlab_token" {
  description = "GitLab Personal Access Token"
  type        = string
  sensitive   = true
}

variable "gitlab_clone_project_url" {
  description = "Gitlab project url to use as a template for the app"
  type        = string
  default     = "https://gitlab.com/com.kc2112/astrohaus.net.git"

}

variable "app_domain_prefix" {
  type    = string
  default = "ddd"
}