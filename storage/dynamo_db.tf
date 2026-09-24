
resource "aws_dynamodb_table" "image_metadata" {
  name           = "${var.website_domain_name}-image-metadata"
  hash_key       = "imageKey"
  read_capacity  = 20
  write_capacity = 20

  attribute {
    name = "imageKey"
    type = "S"
  }
}
