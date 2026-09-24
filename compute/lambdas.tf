
data "archive_file" "store_images_metadata" {
  type        = "zip"
  output_path = "${path.module}/archives/get_images/index.zip"
  source {
    content  = file("${path.module}/archives/store_metadata/index.mjs")
    filename = "index.mjs"
  }
}

data "archive_file" "scale_images" {
  type        = "zip"
  source_file = "${path.module}/archives/scale_image/index.mjs"
  output_path = "${path.module}/archives/scale_image/index.zip"
}

data "archive_file" "get_images" {
  type        = "zip"
  output_path = "${path.module}/archives/get_images/index.zip"
  source {
    content = templatefile("${path.module}/archives/get_images/index.mjs", {
      domain_name           = var.domain_name
      image_bucket_name     = var.images_bucket_name
      dynambo_db_table_name = var.dynambo_db_table_name
    })
    filename = "index.mjs"
  }
}

data "archive_file" "get_mock" {
  type        = "zip"
  output_path = "${path.module}/archives/get_mock/index.zip"
  source {
    content = templatefile("${path.module}/archives/get_mock/index.mjs", {
      domain_name           = var.domain_name
    })
    filename = "index.mjs"
  }
}

variable "stages" {
  type    = list(string)
  default = ["dev", "test", "prod"]
}

resource "aws_lambda_function" "get_mock" {
  filename      = data.archive_file.get_mock.output_path
  description = "mock data for api testing"
  function_name = "get-mock"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  code_sha256   = data.archive_file.get_mock.output_base64sha256

  timeout     = 15
  memory_size = 1024
  runtime     = "nodejs24.x"

  publish = true
  layers  = [aws_lambda_layer_version.node_aws.id]

}

resource "aws_lambda_function" "store_image_metadata" {
  filename      = data.archive_file.store_images_metadata.output_path
  function_name = "store-image-metadata"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  code_sha256   = data.archive_file.store_images_metadata.output_base64sha256
  timeout       = 5
  memory_size   = 256
  runtime       = "nodejs24.x"

  publish = true
  layers  = [aws_lambda_layer_version.node_aws.id]

}

resource "aws_lambda_function" "scale_image" {
  filename      = data.archive_file.scale_images.output_path
  function_name = "scale-image"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  code_sha256   = data.archive_file.scale_images.output_base64sha256

  timeout     = 15
  memory_size = 1024
  runtime     = "nodejs24.x"

  publish = true
  layers  = [aws_lambda_layer_version.node_aws.id]
}

resource "aws_lambda_function" "get_images" {
  filename      = data.archive_file.get_images.output_path
  function_name = "get-images"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  code_sha256   = data.archive_file.get_images.output_base64sha256

  timeout     = 15
  memory_size = 1024
  runtime     = "nodejs24.x"

  publish = true
  layers  = [aws_lambda_layer_version.node_aws.id]

}

resource "aws_lambda_provisioned_concurrency_config" "get_images" {
  function_name                     = aws_lambda_function.get_images.function_name
  provisioned_concurrent_executions = 1
  qualifier                         = "prod"
}

resource "aws_lambda_alias" "this" {
  for_each = {
    for pair in setproduct(
      ["get_mock", "get_images", "scale_image", "store_image_metadata"],
      var.stages
    ) :
    "${pair[0]}-${pair[1]}" => {
      function_key = pair[0]
      stage        = pair[1]
    }
  }

  name = each.value.stage

  function_name = {
    "get_mock"             = aws_lambda_function.get_mock.function_name
    "get_images"           = aws_lambda_function.get_images.function_name
    "scale_image"          = aws_lambda_function.scale_image.function_name
    "store_image_metadata" = aws_lambda_function.store_image_metadata.function_name
  }[each.value.function_key]

  function_version = each.value.stage == "dev" ? "$LATEST" : {
    "get_mock"             = aws_lambda_function.get_mock.version
    "get_images"           = aws_lambda_function.get_images.version
    "scale_image"          = aws_lambda_function.scale_image.version
    "store_image_metadata" = aws_lambda_function.store_image_metadata.version
  }[each.value.function_key]
}

resource "aws_iam_role" "lambda_role" {
  name                 = "lambda-iam-role"
  max_session_duration = 3600
  assume_role_policy   = file("${path.module}/lambda-role.json")
}

resource "aws_iam_policy" "lambda_execute_policy" {
  name        = "lambda-execute-policy"
  description = "Policy for Lambda to execute."

  policy = file("${path.module}/lambda-invoke-policy.json")
}

resource "aws_iam_policy" "lambda_s3_policy" {
  name   = "lambda_s3_policy"
  policy = file("${path.module}/lambda_s3_policy.json")
}

resource "aws_iam_policy" "dynamo_db_policy" {
  name   = "dynamo_db_policy"
  policy = file("${path.module}/dynamo_db_policy.json")
}

resource "aws_iam_role_policy_attachment" "dynamo_db_policy_attachment" {
  policy_arn = aws_iam_policy.dynamo_db_policy.arn
  role       = aws_iam_role.lambda_role.name
}


resource "aws_iam_role_policy_attachment" "lambda_s3_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy_attachment" "iam-policy_role_attachment_lambda" {
  policy_arn = aws_iam_policy.lambda_execute_policy.arn
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy_attachment" "scale_image_lambda_logging" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
