

resource "aws_sfn_state_machine" "process_images_sfn" {

  name = "process-images-sfn"
  definition = templatefile("${path.module}/process_images_fn.json", {
    store_image_metadata_lambda_arn = aws_lambda_function.store_image_metadata.arn,
    scale_image_metadata_lambda_arn = aws_lambda_function.scale_image.arn

  })
  role_arn = aws_iam_role.process_images_sfn.arn

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.process_images_log_group.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }
}

resource "aws_cloudwatch_log_group" "process_images_log_group" {
  name = "/aws/vendedlogs/states/process-images"
}

resource "aws_iam_role" "process_images_sfn" {
  name = "process-images-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "sfn_lambda_execute_policy" {
  name = "process-images-sfn-logging-policy"
  role = aws_iam_role.process_images_sfn.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "lambda:InvokeFunction"
        ],
        "Resource" : [aws_lambda_function.scale_image.arn, aws_lambda_function.store_image_metadata.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "sfn_logs" {
  name = "sfn-logs-policy"
  role = aws_iam_role.process_images_sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}
