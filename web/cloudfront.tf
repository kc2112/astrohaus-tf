
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "cors_s3" {
  name = "Managed-CORS-S3Origin"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

resource "aws_cloudfront_origin_request_policy" "presigned_url_policy" {
  name    = "kc2112-presigned-url-origin-request-policy"
  comment = "Forward all query strings for presigned URLs"

  cookies_config {
    cookie_behavior = "none"
  }

  headers_config {
    header_behavior = "none"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

resource "aws_cloudfront_distribution" "static_site_distribution" {

  enabled         = true
  is_ipv6_enabled = true

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.primary_domain_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }


  default_cache_behavior {
    min_ttl                  = 0
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD", "OPTIONS"]
    target_origin_id         = var.website_endpoint
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.cors_s3.id
    compress                 = true
    grpc_config {
      enabled = false
    }
    #realtime_log_config_arn  = aws_cloudfront_realtime_log_config.example.arn

  }

  aliases = [var.domain_name, "www.${var.domain_name}"]

  origin {
    domain_name = var.website_endpoint
    origin_id   = var.website_endpoint

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2", "TLSv1.1", "TLSv1"]
    }
  }

  origin {
    domain_name = "images.${var.images_bucket_regional_domain_name}"
    origin_id   = "images.${var.images_bucket_name}"

    s3_origin_config {
      origin_access_identity = ""
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/images/*"
    target_origin_id       = "images.${var.images_bucket_name}"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id
    # Forwards all query string params (X-Amz-Signature, X-Amz-Expires, etc.) to S3
    origin_request_policy_id = aws_cloudfront_origin_request_policy.presigned_url_policy.id
    compress                 = true
  }
}

resource "aws_cloudfront_function" "redirect_www" {
  name    = "redirect-www-to-apex"
  runtime = "cloudfront-js-2.0"
  comment = "Redirects www subdomain to primary domain"
  publish = true
  code    = <<EOF
function handler(event) {
    var request = event.request;
    var host = request.headers.host.value;

    // Check if the request is for the www domain
    if (host.startsWith('www.')) {
        var targetHost = host.substring(4);
        var response = {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                'location': {
                    value: 'https://' + targetHost + request.uri
                }
            }
        };
        return response;
    }

    return request;
}
EOF
}


#######################   ACCESS LOGS  ###################################

resource "aws_cloudwatch_log_delivery_source" "cf_access_logs_src" {
  name         = "cf_access_logs_src"
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.static_site_distribution.arn
  lifecycle {
    replace_triggered_by = [aws_cloudfront_distribution.static_site_distribution]
  }

}

# resource "aws_cloudwatch_log_delivery_destination" "cf_access_logs_dest" {

#   name = "cf_access_logs_dest"

#   delivery_destination_configuration {
#     destination_resource_arn = var.access_logs_bucket_arn
#   }
#   output_format = "json"
# }

# resource "aws_cloudwatch_log_delivery" "cf_delivery_s3" {
#   delivery_source_name     = aws_cloudwatch_log_delivery_source.cf_access_logs_src.name
#   delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cf_access_logs_dest.arn

#   s3_delivery_configuration {
#     suffix_path                 = "AWSLogs/{accountid}/CloudFront"
#     enable_hive_compatible_path = true
#   }

#   depends_on = [aws_cloudwatch_log_delivery_source.cf_access_logs_src]

# }