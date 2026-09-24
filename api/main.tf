data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_api_gateway_rest_api" "main" {

  name = "${var.domain_name}_api"

  body = templatefile("${path.module}/swagger/openapi-dev.json", {
    domain_name    = var.domain_name
    get_images_uri = var.lambda_integration_uris["get_images"]
    get_mock_uri = var.lambda_integration_uris["get_mock"]
  })

}
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.main.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  for_each = toset(["dev", "test", "prod"])

  stage_name    = each.key
  rest_api_id   = aws_api_gateway_rest_api.main.id
  deployment_id = aws_api_gateway_deployment.main.id

  variables = {
    lambdaAlias = each.key # "dev" | "test" | "prod"
  }
}

resource "aws_lambda_permission" "apigw_get_images" {
  for_each = toset(["dev", "test", "prod"])

  statement_id  = "AllowAPIGatewayInvokeGetImages-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_names.get_images
  principal     = "apigateway.amazonaws.com"
  qualifier     = each.key # the alias name

  source_arn = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_get_mock" {
  for_each = toset(["dev", "test", "prod"])

  statement_id  = "AllowAPIGatewayInvokeGetImages-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_names.get_mock
  principal     = "apigateway.amazonaws.com"
  qualifier     = each.key # the alias name

  source_arn = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_api_gateway_api_key" "primary" {
  name    = "${var.domain_name}_api_key"
  enabled = true
}

resource "aws_api_gateway_usage_plan" "main" {
  for_each = toset(["dev", "test", "prod"])
  name     = "${var.domain_name}_usage_plan_${each.key}"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = each.key
  }
  depends_on = [aws_api_gateway_stage.main]
}

resource "aws_api_gateway_usage_plan_key" "main" {
  for_each      = toset(["dev", "test", "prod"])
  key_id        = aws_api_gateway_api_key.primary.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main[each.key].id
}