

resource "aws_amplify_app" "frontend" {
  name        = gitlab_project.primary_application.name
  description = "Terraform Amplify project"
  repository  = gitlab_project.primary_application.http_url_to_repo

  access_token                = var.gitlab_token
  enable_branch_auto_build    = true
  enable_branch_auto_deletion = true

  //platform = "WEB_COMPUTE"
  build_spec = file("${path.module}/build-spec.yml")
}

resource "aws_amplify_branch" "main" {
  app_id            = aws_amplify_app.frontend.id
  branch_name       = "main"
  enable_auto_build = true
  stage             = "PRODUCTION"

  framework = "React"

}

resource "null_resource" "trigger_production_build" {
  depends_on = [aws_amplify_branch.main]

  provisioner "local-exec" {
    command = "aws amplify start-job --app-id ${aws_amplify_app.frontend.id} --branch-name ${aws_amplify_branch.main.branch_name} --job-type RELEASE"
  }
}

resource "aws_amplify_domain_association" "main" {
  app_id                = aws_amplify_app.frontend.id
  domain_name           = var.domain_name
  wait_for_verification = true

  sub_domain {
    branch_name = "main"
    prefix      = var.app_domain_prefix
  }

  depends_on = [aws_amplify_branch.main]
}