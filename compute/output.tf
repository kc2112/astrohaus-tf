
data "aws_region" "current" {}

output "sfn_arn" {
  value = aws_sfn_state_machine.process_images_sfn.arn
}

###############################
# Outputs
###############################
output "lambda_alias_invoke_arns" {
  description = "Map of function-stage → invoke ARN"
  value = {
    for k, alias in aws_lambda_alias.this :
    k => alias.invoke_arn
  }
}

output "lambda_alias_arns" {
  value = {
    for k, alias in aws_lambda_alias.this :
    k => alias.arn
  }
}

output "lambda_function_names" {
  value = tomap({
    get_images = aws_lambda_function.get_images.function_name
    get_mock = aws_lambda_function.get_mock.function_name
  })
}

output "lambda_function_arns" {
  value = {
    get_images = aws_lambda_function.get_images.arn
  }
}

output "lambda_integration_uris" {
  description = "Map of logical name → API Gateway integration URI"
  value = {
    get_images = "arn:aws:apigateway:${data.aws_region.current.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.get_images.arn}:$${stageVariables.lambdaAlias}/invocations"
    get_mock = "arn:aws:apigateway:${data.aws_region.current.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.get_mock.arn}:$${stageVariables.lambdaAlias}/invocations"
  }
}