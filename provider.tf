terraform {

  required_version = "1.15.8"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 19" # latest major.minor as of now (19.2.1)
    }
  }

}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Name = var.domain_name
    }
  }
}

provider "gitlab" {
  token = var.gitlab_token
}