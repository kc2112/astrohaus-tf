

resource "aws_sqs_queue" "main" {
  name                       = replace("${var.domain_name}-queue", ".", "-")
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "dlq" {
  name = replace("${var.domain_name}-queue-dlq", ".", "-")
}



resource "aws_pipes_pipe" "sqs_to_sfn" {
  name   = replace("${var.domain_name}-pipe", ".", "-")
  source = aws_sqs_queue.main.arn
  target = aws_sfn_state_machine.processor.arn

  role_arn = aws_iam_role.pipes_exec.arn

  source_parameters {
    sqs_queue_parameters {
      batch_size                         = 10
      maximum_batching_window_in_seconds = 180
    }
  }

  target_parameters {
    step_function_state_machine_parameters {
      invocation_type = "FIRE_AND_FORGET"
    }
  }
}



resource "aws_iam_role" "pipes_exec" {
  name = replace("${var.domain_name}-pipes_exec", ".", "-")
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pipes.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "pipes_exec" {
  name = "${var.domain_name}-pipes-policy"
  role = aws_iam_role.pipes_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ---- Source: SQS ----
      {
        Sid    = "AllowSQSSource"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.main.arn
      },

      # ---- Target: Step Functions ----
      {
        Sid    = "AllowStepFunctionsTarget"
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = aws_sfn_state_machine.processor.arn
      }
    ]
  })
}

resource "aws_iam_role" "sfn_exec" {
  name = replace("${var.domain_name}-exec", ".", "-")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_sfn_state_machine" "processor" {
  name     = replace("${var.domain_name}-sfn", ".", "-")
  role_arn = aws_iam_role.sfn_exec.arn

  definition = jsonencode({
    Comment = "Process SQS order messages from EventBridge Pipe"
    StartAt = "ProcessRecords"
    States = {
      ProcessRecords = {
        Type           = "Map"
        ItemsPath      = "$"
        MaxConcurrency = 5
        ItemProcessor = {
          ProcessorConfig = {
            Mode = "INLINE"
          }
          StartAt = "ParseBody"
          States = {
            ParseBody = {
              Type = "Pass"
              Parameters = {
                "order.$" = "States.StringToJson($.body)"
              }
              End = true
            }
          }
        }
        End = true
      }
    }
  })
}
