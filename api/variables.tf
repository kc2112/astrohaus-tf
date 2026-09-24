
variable "domain_name" {
  type = string
}

variable "lambda_integration_uris" {
  type = map(string)
}

variable "lambda_function_names" {
  type = map(string)
}
