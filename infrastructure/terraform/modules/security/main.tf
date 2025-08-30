# Enterprise Security Infrastructure

# API Keys table for authentication
resource "aws_dynamodb_table" "api_keys" {
  name           = "payment-system-api-keys"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "key_hash"

  attribute {
    name = "key_hash"
    type = "S"
  }

  attribute {
    name = "client_id"
    type = "S"
  }

  global_secondary_index {
    name     = "ClientIdIndex"
    hash_key = "client_id"
  }

  server_side_encryption {
    enabled     = true
    kms_key_id  = aws_kms_key.payment_system_key.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "PaymentSystem-APIKeys"
    Environment = var.environment
    Project     = "payment-system"
    Security    = "high"
  }
}

# Rate limiting table
resource "aws_dynamodb_table" "rate_limits" {
  name           = "payment-system-rate-limits"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "client_id"

  attribute {
    name = "client_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_id  = aws_kms_key.payment_system_key.arn
  }

  tags = {
    Name        = "PaymentSystem-RateLimits"
    Environment = var.environment
    Project     = "payment-system"
  }
}

# Audit logging table
resource "aws_dynamodb_table" "audit_log" {
  name           = "payment-system-audit-log"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "event_type"
    type = "S"
  }

  global_secondary_index {
    name     = "TimestampIndex"
    hash_key = "event_type"
    range_key = "timestamp"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_id  = aws_kms_key.payment_system_key.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "PaymentSystem-AuditLog"
    Environment = var.environment
    Project     = "payment-system"
    Security    = "high"
  }
}

# KMS key for encryption
resource "aws_kms_key" "payment_system_key" {
  description             = "Payment System Master Key for PCI-DSS compliance"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda Functions"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "PaymentSystem-MasterKey"
    Environment = var.environment
    Project     = "payment-system"
    Security    = "high"
  }
}

resource "aws_kms_alias" "payment_system_key_alias" {
  name          = "alias/payment-system-${var.environment}"
  target_key_id = aws_kms_key.payment_system_key.key_id
}

# WAF Web ACL for DDoS protection
resource "aws_wafv2_web_acl" "payment_api_protection" {
  name  = "payment-system-protection"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000  # 2000 requests per 5-minute window
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "RateLimitRule"
      sampled_requests_enabled    = true
    }
  }

  # IP reputation rule
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 2

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "IPReputationRule"
      sampled_requests_enabled    = true
    }
  }

  # Known bad inputs rule
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "KnownBadInputsRule"
      sampled_requests_enabled    = true
    }
  }

  # SQL injection protection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 4

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "SQLiProtectionRule"
      sampled_requests_enabled    = true
    }
  }

  tags = {
    Name        = "PaymentSystem-WAF"
    Environment = var.environment
    Project     = "payment-system"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                 = "PaymentSystemWAF"
    sampled_requests_enabled    = true
  }
}

# CloudWatch Log Group for security events
resource "aws_cloudwatch_log_group" "security_logs" {
  name              = "/aws/payment-system/security"
  retention_in_days = 365  # Keep security logs for 1 year

  kms_key_id = aws_kms_key.payment_system_key.arn

  tags = {
    Name        = "PaymentSystem-SecurityLogs"
    Environment = var.environment
    Project     = "payment-system"
  }
}

# Data sources
data "aws_caller_identity" "current" {}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

# Outputs
output "kms_key_id" {
  description = "KMS key ID for payment system encryption"
  value       = aws_kms_key.payment_system_key.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for payment system encryption"
  value       = aws_kms_key.payment_system_key.arn
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN for API protection"
  value       = aws_wafv2_web_acl.payment_api_protection.arn
}

output "api_keys_table_name" {
  description = "API keys table name"
  value       = aws_dynamodb_table.api_keys.name
}

output "audit_log_table_name" {
  description = "Audit log table name"
  value       = aws_dynamodb_table.audit_log.name
}