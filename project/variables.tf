
variable "domain_name" {
  type = string
}

variable "gitlab_token" {
  description = "GitLab Personal Access Token"
  type        = string
  sensitive   = true
}

variable "ssl_cert_arn" {
  type = string
}

variable "gitlab_clone_project_url" {
  type = string
}

variable "app_domain_prefix" {
  type = string
}

variable "allowed_to_push" {
  description = "Access levels allowed to push"
  type = list(object({
    access_level = string
  }))
  default = [
    {
      access_level = "maintainer"
    }
  ]
}