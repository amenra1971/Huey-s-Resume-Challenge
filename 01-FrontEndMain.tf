terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0, < 5.0"
    }
  }
}


provider "aws" {
  region = "us-east-1"
}

# S3 Bucket Resources----------------------------------------------------------
resource "aws_s3_bucket" "s3_bucket" {
  bucket = "resumeforhuey.click"
}

resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.s3_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    sid       = "Allow CloudFront to read from S3 bucket"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::resumeforhuey.click/*"]
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
  version = "2012-10-17"
}

resource "aws_s3_bucket_website_configuration" "s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}
resource "aws_s3_bucket_ownership_controls" "ebucket" {
  bucket = "resumeforhuey.click"
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "s3_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.ebucket]
  bucket = "resumeforhuey.click"
    acl    = "private"
}

resource "aws_s3_bucket_versioning" "s3_bucket" {
  bucket = "resumeforhuey.click"
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "my_objects" {
  for_each      = {       
    "index.html" = "text/html",    
    "script.js"= "application/javascript",
    "navy.jpg" = "image/jpeg"
  }
  key           = each.key
  content_type  = each.value
  source        = "./${each.key}"
  bucket        = aws_s3_bucket.s3_bucket.id
  etag          = filemd5("./${each.key}")
}

# CloudFront Resources ----------------------------------------------------------------
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "access-identity-your_domain_name.s3.amazonaws.com"
}
resource "aws_wafv2_web_acl" "app1_waf_acl" {
    name        = "app1-web-acl"
    description = "Web ACL for app1"
    scope       = "REGIONAL"

    default_action {
      allow {}
    }

    # IP Block Rule
    rule {
      name     = "IPBlockRule"
      priority = 1

      action {
        block {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.ip_block_list.arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = false
        metric_name                = "IPBlockRule"
        sampled_requests_enabled   = false
      }
    }

  # AWS Managed Rules - Admin Protection Rule Set
  rule {
    name     = "AWSManagedRulesAdminProtectionRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAdminProtectionRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAdminProtectionRuleSet"
      sampled_requests_enabled   = true
    }
  }

    # Amazon IP Reputation List
    rule {
      name     = "AWSManagedRulesAmazonIpReputationList"
      priority = 3

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAmazonIpReputationList"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = false
        metric_name                = "AWSManagedRulesAmazonIpReputationList"
        sampled_requests_enabled   = false
      }
    }

    # Anonymous IP List
    rule {
      name     = "AWSManagedRulesAnonymousIpList"
      priority = 4

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAnonymousIpList"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = false
        metric_name                = "AWSManagedRulesAnonymousIpList"
        sampled_requests_enabled   = false
      }
    }

    

    # Known Bad Inputs
    rule {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 6

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesKnownBadInputsRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = false
        metric_name                = "AWSManagedRulesKnownBadInputs"
        sampled_requests_enabled   = false
      }
    }

    # Linux Operating System
    rule {
      name     = "AWSManagedRulesLinuxRuleSet"
      priority = 7

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesLinuxRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = false
        metric_name                = "AWSManagedRulesLinuxRuleSet"
        sampled_requests_enabled   = false
      }
    }

    # Geo-blocking rule to block traffic from Russia
  rule {
    name     = "BlockRussia"
    priority = 8  # Adjust the priority as needed

    action {
      block {}
    }

    statement {
      geo_match_statement {
        country_codes = ["RU"]  # Country code for Russia
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockRussia"
      sampled_requests_enabled   = true
    }
  }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "app1WebACL"
      sampled_requests_enabled   = false
    }

    tags = {
      Name    = "app1-web-acl"
      Service = "application1"
      Owner   = "Chewbacca"
      Planet  = "Mustafar"
    }
  }

  resource "aws_wafv2_ip_set" "ip_block_list" {
    name               = "ip-block-list"
    description        = "List of blocked IP addresses"
    scope              = "REGIONAL"
    ip_address_version = "IPV4"

    addresses = [
      "1.188.0.0/16",
      "1.88.0.0/16",
      "101.144.0.0/16",
      "101.16.0.0/16"
    ]

    tags = {
      Name    = "ip-block-list"
      Service = "application1"
      Owner   = "Chewbacca"
      Planet  = "Mustafar"
    }
  }

  
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.s3_bucket.bucket_domain_name
    origin_id   = "S3-${aws_s3_bucket.s3_bucket.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  
  aliases = ["resumeforhuey.click"]

  default_cache_behavior {
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    origin_request_policy_id   = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
    response_headers_policy_id = "60669652-455b-4ae9-85a4-c4c02393f86c"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD", "OPTIONS"]
    target_origin_id           = "S3-resumeforhuey.click"
    viewer_protocol_policy     = "allow-all"
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.acm_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    error_caching_min_ttl = 0
    response_page_path    = "/index.html"
  }

  wait_for_deployment = false

  depends_on = [
    aws_s3_bucket.s3_bucket,
  ]
 
}

resource "aws_cloudfront_cache_policy" "policy" {
  name        = "hueynewman"
  min_ttl     = 120
  max_ttl     = 31536000
  default_ttl = 86400

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"

      cookies {
        items = []
      }
    }

    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    headers_config {
      header_behavior = "whitelist"

      headers {
        items = [
          "Access-Control-Allow-Origin",
          "Access-Control-Request-Headers",
          "Access-Control-Request-Method",
          "Origin",
        ]
      }
    }

    query_strings_config {
      query_string_behavior = "none"

      query_strings {
        items = []
      }
    }
  }
}

resource "aws_cloudfront_origin_request_policy" "policy" {
  name = "hnewmanresume"

  cookies_config {
    cookie_behavior = "none"

    cookies {
      items = []
    }
  }

  headers_config {
    header_behavior = "whitelist"

    headers {
      items = [
        "Access-Control-Allow-Origin",
        "Access-Control-Request-Headers",
        "Access-Control-Request-Method",
        "Origin",
      ]
    }
  }

  query_strings_config {
    query_string_behavior = "none"

    query_strings {
      items = []
    }
  }
}



# ACM Certificate-----------------------------------------------------------
data "aws_acm_certificate" "acm_cert" {
  domain   = "resumeforhuey.click"
  statuses = ["ISSUED"]
}

# Route53--------------------------------------------------------------------------
data "aws_route53_zone" "my_zone" {
  name         = "resumeforhuey.click"
  private_zone = false
}

resource "aws_route53_record" "a" {
  zone_id = data.aws_route53_zone.my_zone.zone_id
  name    = "resumeforhuey.click"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
