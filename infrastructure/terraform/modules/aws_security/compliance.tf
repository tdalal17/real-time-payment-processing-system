# PCI-DSS Compliance Monitoring with AWS Config
# Automated compliance checking and remediation

# Additional Config rules for PCI-DSS compliance
resource "aws_config_config_rule" "s3_bucket_ssl_requests_only" {
  name = "payment-system-s3-ssl-only"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SSL_REQUESTS_ONLY"
  }

  depends_on = [aws_config_configuration_recorder.payment_system_config]

  tags = {
    Name        = "payment-system-s3-ssl-rule"
    Environment = var.environment
    Compliance  = "PCI-DSS-3.4"  # Encrypt transmission of cardholder data
  }
}

resource "aws_config_config_rule" "dynamodb_table_encryption_enabled" {
  name = "payment-system-dynamodb-encryption"

  source {
    owner             = "AWS"
    source_identifier = "DYNAMODB_TABLE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.payment_system_config]

  tags = {
    Name        = "payment-system-dynamodb-encryption-rule"
    Environment = var.environment
    Compliance  = "PCI-DSS-3.4"  # Protect stored cardholder data
  }
}

resource "aws_config_config_rule" "lambda_function_public_read_prohibited" {
  name = "payment-system-lambda-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "LAMBDA_FUNCTION_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.payment_system_config]

  tags = {
    Name        = "payment-system-lambda-public-rule"
    Environment = var.environment
    Compliance  = "PCI-DSS-1.2"  # Restrict access to system components
  }
}

resource "aws_config_config_rule" "api_gateway_ssl_enabled" {
  name = "payment-system-api-gateway-ssl"

  source {
    owner             = "AWS"
    source_identifier = "API_GW_SSL_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.payment_system_config]

  tags = {
    Name        = "payment-system-api-ssl-rule"
    Environment = var.environment
    Compliance  = "PCI-DSS-4.1"  # Use strong cryptography for transmission
  }
}

# Custom Config rule for payment system specific requirements
resource "aws_config_config_rule" "payment_system_tagging" {
  name = "payment-system-required-tags"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    requiredTagKey1 = "Project"
    requiredTagValue1 = "payment-system"
    requiredTagKey2 = "Environment"
    requiredTagKey3 = "Security"
  })

  depends_on = [aws_config_configuration_recorder.payment_system_config]

  tags = {
    Name        = "payment-system-tagging-rule"
    Environment = var.environment
    Compliance  = "Internal-Policy"
  }
}

# Config remediation configurations
resource "aws_config_remediation_configuration" "s3_bucket_ssl_remediation" {
  config_rule_name = aws_config_config_rule.s3_bucket_ssl_requests_only.name

  resource_type = "AWS::S3::Bucket"
  target_type   = "SSM_DOCUMENT"
  target_id     = "AutomationAssumeRoleExecutionRoleArn"
  target_version = "1"

  parameter {
    name           = "AutomationAssumeRole"
    static_value   = aws_iam_role.config_remediation_role.arn
  }

  parameter {
    name               = "BucketName"
    resource_value     = "RESOURCE_ID"
  }

  automatic = true
  maximum_automatic_attempts = 3

  tags = {
    Name        = "payment-system-s3-ssl-remediation"
    Environment = var.environment
  }
}

# IAM role for Config remediation
resource "aws_iam_role" "config_remediation_role" {
  name = "payment-system-config-remediation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "payment-system-remediation-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "config_remediation_policy" {
  name = "payment-system-config-remediation-policy"
  role = aws_iam_role.config_remediation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutBucketPolicy",
          "s3:GetBucketPolicy",
          "dynamodb:UpdateTable",
          "lambda:UpdateFunctionConfiguration",
          "apigateway:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "payment-system"
          }
        }
      }
    ]
  })
}

# Compliance dashboard
resource "aws_cloudwatch_dashboard" "compliance_dashboard" {
  dashboard_name = "payment-system-compliance-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Config", "ComplianceByConfigRule", "ConfigRuleName", aws_config_config_rule.s3_bucket_ssl_requests_only.name],
            ["AWS/Config", "ComplianceByConfigRule", "ConfigRuleName", aws_config_config_rule.dynamodb_table_encryption_enabled.name],
            ["AWS/Config", "ComplianceByConfigRule", "ConfigRuleName", aws_config_config_rule.lambda_function_public_read_prohibited.name],
            ["AWS/Config", "ComplianceByConfigRule", "ConfigRuleName", aws_config_config_rule.api_gateway_ssl_enabled.name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "PCI-DSS Compliance Status"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["AWS/GuardDuty", "FindingCount"]
          ]
          view    = "singleValue"
          region  = var.aws_region
          title   = "Active GuardDuty Findings"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 6
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["PaymentSystem/Security", "SecurityIncidents"]
          ]
          view    = "singleValue"
          region  = var.aws_region
          title   = "Security Incidents (24h)"
          period  = 86400
        }
      }
    ]
  })
}

# Security Hub custom insights
resource "aws_securityhub_insight" "payment_system_high_severity" {
  filters {
    severity_label {
      comparison = "EQUALS"
      value      = "HIGH"
    }
    severity_label {
      comparison = "EQUALS"
      value      = "CRITICAL"
    }
    resource_tags {
      comparison = "EQUALS"
      key        = "Project"
      value      = "payment-system"
    }
  }

  group_by_attribute = "ResourceId"
  name              = "Payment System High Severity Findings"
}

# Automated compliance reporting
resource "aws_lambda_function" "compliance_reporter" {
  filename         = "compliance_reporter.zip"
  function_name    = "payment-system-compliance-reporter"
  role            = aws_iam_role.compliance_reporter_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.11"
  timeout         = 900  # 15 minutes for comprehensive reporting

  environment {
    variables = {
      ENVIRONMENT = var.environment
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
    }
  }

  kms_key_arn = aws_kms_key.audit_encryption_key.arn

  tags = {
    Name        = "payment-system-compliance-reporter"
    Environment = var.environment
    Security    = "high"
  }
}

# IAM role for compliance reporter
resource "aws_iam_role" "compliance_reporter_role" {
  name = "payment-system-compliance-reporter-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "payment-system-compliance-reporter-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "compliance_reporter_policy" {
  name = "payment-system-compliance-reporter-policy"
  role = aws_iam_role.compliance_reporter_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "config:GetComplianceDetailsByConfigRule",
          "config:GetComplianceSummaryByConfigRule",
          "config:DescribeConfigRules"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "securityhub:GetFindings",
          "securityhub:GetInsights"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

# EventBridge rule for daily compliance reporting
resource "aws_cloudwatch_event_rule" "daily_compliance_report" {
  name                = "payment-system-daily-compliance"
  description         = "Trigger daily compliance report"
  schedule_expression = "cron(0 8 * * ? *)"  # 8 AM UTC daily

  tags = {
    Name        = "payment-system-compliance-schedule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "compliance_report_target" {
  rule      = aws_cloudwatch_event_rule.daily_compliance_report.name
  target_id = "ComplianceReporterTarget"
  arn       = aws_lambda_function.compliance_reporter.arn
}

resource "aws_lambda_permission" "allow_eventbridge_compliance" {
  statement_id  = "AllowExecutionFromEventBridgeCompliance"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compliance_reporter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_compliance_report.arn
}