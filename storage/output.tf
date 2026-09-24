output "website_domain" {
  value = aws_s3_bucket_website_configuration.static-website-config.website_domain
}

output "website_zone_id" {
  value = aws_s3_bucket.static-website.hosted_zone_id
}

output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.static-website-config.website_endpoint
}

output "images_bucket_name" {
  value = aws_s3_bucket.images_bucket.bucket
}

output "images_bucket_regional_domain_name" {
  value = aws_s3_bucket.images_bucket.bucket_regional_domain_name
}

output "image_bucket_arn" {
  value = aws_s3_bucket.images_bucket.arn
}

output "logging_bucket_name" {
  value = aws_s3_bucket.access_logs.bucket_regional_domain_name
}

output "access_logs_bucket_arn" {
  value = aws_s3_bucket.access_logs.arn
}

output "dynambo_db_table_name" {
  value = aws_dynamodb_table.image_metadata.name
}