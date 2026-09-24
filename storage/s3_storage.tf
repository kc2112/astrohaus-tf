# Data source to get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "static-website" {
  bucket              = var.website_domain_name
  object_lock_enabled = false
}

resource "aws_s3_bucket_website_configuration" "static-website-config" {
  bucket = aws_s3_bucket.static-website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

}

resource "aws_s3_bucket_ownership_controls" "site-ownership" {
  bucket = aws_s3_bucket.static-website.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.static-website.id

  # Ensures policy is only applied AFTER public access blocks are removed
  depends_on = [aws_s3_bucket_public_access_block.static-public-access-allow]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.static-website.arn}/*"
    }]
  })

}

resource "aws_s3_bucket_public_access_block" "static-public-access-allow" {

  bucket                  = aws_s3_bucket.static-website.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.static-website.id
  key    = "index.html"
  content = templatefile("${path.module}/static/index.tftpl", {
    website_domain_name = var.website_domain_name
  })
  content_type = "text/html"
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.static-website.id
  key          = "error.html"
  source       = "${path.module}/static/error.html"
  content_type = "text/html"
}

#########################    IMAGES BUCKET   ################################


resource "aws_s3_bucket" "images_bucket" {
  bucket        = "${var.website_domain_name}-images"
  force_destroy = true
}


resource "aws_s3_object" "images_folder" {
  bucket = aws_s3_bucket.images_bucket.id
  key    = "images/"
}

resource "aws_s3_object" "scaled_folder" {
  bucket = aws_s3_bucket.images_bucket.id
  key    = "scaled/"
}

resource "aws_s3_bucket_notification" "images_folder_notification" {
  bucket      = aws_s3_bucket.images_bucket.id
  eventbridge = true
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "images_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontOACReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.images_bucket.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [var.cloudfront_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "images" {
  bucket     = aws_s3_bucket.images_bucket.id
  policy     = data.aws_iam_policy_document.images_bucket_policy.json
  depends_on = [aws_s3_bucket_public_access_block.images]
}

resource "aws_cloudwatch_event_rule" "image_created_trigger" {
  name        = "image_created_trigger"
  description = "Triggers when a new image is created in the s3 bucket"

  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.images_bucket.bucket]
      }
      object = {
        key = [{ prefix = "images/" }]
      }
    }
  })
}

resource "aws_iam_role" "eventbridge_to_sfn" {
  name = "eventbridge-sfn-invocation-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_sfn_policy" {
  role = aws_iam_role.eventbridge_to_sfn.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = var.sfn_arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "sfn_target" {
  rule      = aws_cloudwatch_event_rule.image_created_trigger.name
  target_id = "sfn_target"
  arn       = var.sfn_arn
  role_arn  = aws_iam_role.eventbridge_to_sfn.arn
}

resource "aws_s3_bucket_public_access_block" "images_policy" {
  bucket = aws_s3_bucket.images_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#########################   CLOUDFRONT ACCESS LOGS ################################
resource "aws_s3_bucket" "access_logs" {
  bucket        = var.logging_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "access-logs-policy" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "s3-access-config" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    id     = "expire-logs"
    status = "Enabled"
    expiration {
      days = 10
    }
  }
}

# Add the missing S3 bucket policy
resource "aws_s3_bucket_policy" "access_logs_policy" {
  bucket = replace(aws_s3_bucket.access_logs.arn, "arn:aws:s3:::", "")

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.access_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.access_logs.arn
      }
    ]
  })
}