data "gitlab_group" "AuraHaus" {
  full_path = "aurahaus"
}

resource "gitlab_group" "frontend" {
  name             = "${var.domain_name}_frontend"
  path             = "frontend"
  description      = "frontend projects"
  parent_id        = data.gitlab_group.AuraHaus.id
  visibility_level = "private"
}

resource "gitlab_project" "primary_application" {
  name = var.domain_name
  path = var.domain_name

  description      = "terraform deployed infrastructure"
  visibility_level = "private"
  namespace_id     = gitlab_group.frontend.id

  import_url     = var.gitlab_clone_project_url
  default_branch = "main"

}

resource "gitlab_branch_protection" "main" {
  project                      = gitlab_project.primary_application.id
  branch                       = "main"
  allowed_to_push              = var.allowed_to_push
  allowed_to_merge             = var.allowed_to_push
  allow_force_push             = false
  code_owner_approval_required = false
}

resource "gitlab_branch_protection" "test" {
  project                      = gitlab_project.primary_application.id
  branch                       = "test"
  allowed_to_push              = var.allowed_to_push
  allowed_to_merge             = var.allowed_to_push
  allow_force_push             = true
  code_owner_approval_required = false
}

resource "gitlab_branch_protection" "dev" {
  project                      = gitlab_project.primary_application.id
  branch                       = "dev"
  allowed_to_push              = var.allowed_to_push
  allowed_to_merge             = var.allowed_to_push
  allow_force_push             = true
  code_owner_approval_required = false
}