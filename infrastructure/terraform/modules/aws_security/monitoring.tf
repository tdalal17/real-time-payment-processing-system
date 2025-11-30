# Enterprise Security Monitoring and Alerting
# Real-time security event detection and response

# SNS Topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  name              = "payment-system-security-alerts-${var.environment}"
  kms_master_key_id = aws_kms_key.audit_encryption_key.arn

  tags = {
    Name        = "payment-system-security-alerts"
    Environment = var.environment
    Security    = "high"
  }
}

# CloudWatch Log Groups for security monitoring
resource "aws_cloudwatch_log_group" "security_events" {
  name              = "/aws/payment-system/security-events"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.audit_encryption_key.arn

  tags = {
    Name        = "payment-system-security-events"
    Environment = var.environment
    Security    = "high"
  }
}

resource "aws_cloudwatch_log_group" "api_access_logs" {
  name              = "/aws/payment-system/api-access"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.audit_encryption_key.arn

  tags = {
    Name        = "payment-system-api-access"
    Environment = var.environment
  }
}

# CloudWatch Metric Filters for security events
resource "aws_cloudwatch_log_metric_filter" "failed_authentication" {
  name           = "payment-system-failed-auth"
  log_group_name = aws_cloudwatch_log_group.security_events.name
  pattern        = "[timestamp, request_id, event_type=\"AUTHENTICATION_FAILED\", ...]"

  metric_transformation {
    name      = "FailedAuthentications"
    namespace = "PaymentSystem/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "rate_limit_exceeded" {
  name           = "payment-system-rate-limit-exceeded"
  log_group_name = aws_cloudwatch_log_group.security_events.name
  pattern        = "[timestamp, request_id, event_type=\"RATE_LIMIT_EXCEEDED\", ...]"

  metric_transformation {
    name      = "RateLimitViolations"
    namespace = "PaymentSystem/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "suspicious_activity" {
  name           = "payment-system-suspicious-activity"
  log_group_name = aws_cloudwatch_log_group.security_events.name
  pattern        = "[timestamp, request_id, event_type=\"SUSPICIOUS_ACTIVITY\", ...]"

  metric_transformation {
    name      = "SuspiciousActivities"
    namespace = "PaymentSystem/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "fraud_detected" {
  name           = "payment-system-fraud-detected"
  log_group_name = aws_cloudwatch_log_group.security_events.name
  pattern        = "[timestamp, request_id, event_type=\"FRAUD_DETECTED\", ...]"

  metric_transformation {
    name      = "FraudDetections"
    namespace = "PaymentSystem/Security"
    value     = "1"
  }
}

# CloudWatch Alarms for critical security events
resource "aws_cloudwatch_metric_alarm" "high_failed_auth_rate" {
  alarm_name          = "payment-system-high-failed-auth-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FailedAuthentications"
  namespace           = "PaymentSystem/Security"
  period              = "300"  # 5 minutes
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors failed authentication attempts"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = {
    Name        = "payment-system-failed-auth-alarm"
    Environment = var.environment
    Security    = "critical"
  }
}

resource "aws_cloudwatch_metric_alarm" "rate_limit_violations" {
  alarm_name          = "payment-system-rate-limit-violations"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RateLimitViolations"
  namespace           = "PaymentSystem/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "50"
  alarm_description   = "This metric monitors rate limit violations"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = {
    Name        = "payment-system-rate-limit-alarm"
    Environment = var.environment
    Security    = "high"
  }
}

resource "aws_cloudwatch_metric_alarm" "fraud_detection_alarm" {
  alarm_name          = "payment-system-fraud-detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FraudDetections"
  namespace           = "PaymentSystem/Security"
  period              = "60"   # 1 minute
  statistic           = "Sum"
  threshold           = "0"    # Alert on any fraud detection
  alarm_description   = "This metric monitors fraud detection events"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = {
    Name        = "payment-system-fraud-alarm"
    Environment = var.environment
    Security    = "critical"
  }
}

# API Gateway CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "api_error_rate" {
  alarm_name          = "payment-system-api-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "High API error rate detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    ApiName = "payment-system-api"
    Stage   = var.environment
  }

  tags = {
    Name        = "payment-system-api-error-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "payment-system-api-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"  # 5 seconds
  alarm_description   = "High API latency detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    ApiName = "payment-system-api"
    Stage   = var.environment
  }

  tags = {
    Name        = "payment-system-latency-alarm"
    Environment = var.environment
  }
}

# Lambda Function Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "payment-system-lambda-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "High Lambda error rate detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    FunctionName = "payment-system-process-payment"
  }

  tags = {
    Name        = "payment-system-lambda-error-alarm"
    Environment = var.environment
  }
}

# DynamoDB Alarms
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttle" {
  alarm_name          = "payment-system-dynamodb-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "DynamoDB throttling detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    TableName = "payment-system-transactions"
  }

  tags = {
    Name        = "payment-system-dynamodb-throttle-alarm"
    Environment = var.environment
  }
}

# Custom Security Dashboard
resource "aws_cloudwatch_dashboard" "security_dashboard" {
  dashboard_name = "payment-system-security-${var.environment}"

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
            ["PaymentSystem/Security", "FailedAuthentications"],
            ["PaymentSystem/Security", "RateLimitViolations"],
            ["PaymentSystem/Security", "FraudDetections"],
            ["PaymentSystem/Security", "SuspiciousActivities"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Security Events Overview"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", "payment-system-api"],
            ["AWS/ApiGateway", "4XXError", "ApiName", "payment-system-api"],
            ["AWS/ApiGateway", "5XXError", "ApiName", "payment-system-api"],
            ["AWS/ApiGateway", "Latency", "ApiName", "payment-system-api"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Gateway Metrics"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          query   = "SOURCE '/aws/payment-system/security-events' | fields @timestamp, event_type, details | filter event_type in ['AUTHENTICATION_FAILED', 'RATE_LIMIT_EXCEEDED', 'FRAUD_DETECTED'] | sort @timestamp desc | limit 20"
          region  = var.aws_region
          title   = "Recent Security Events"
        }
      }
    ]
  })
}

# EventBridge Rules for automated security responses
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "payment-system-guardduty-findings"
  description = "Capture GuardDuty findings for payment system"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [7.0, 8.0, 8.5, 9.0, 10.0]  # High and Critical findings only
    }
  })

  tags = {
    Name        = "payment-system-guardduty-rule"
    Environment = var.environment
    Security    = "critical"
  }
}

resource "aws_cloudwatch_event_target" "security_alerts_target" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}

# Config Rules for compliance monitoring
resource "aws_config_config_rule" "encrypted_volumes" {
  name = "payment-system-encrypted-volumes"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder.payment_system_config]

  tags = {
    Name        = "payment-system-encrypted-volumes-rule"
    Environment = var.environment
    Compliance  = "PCI-DSS"
  }
}

resource "aws_config_config_rule" "root_access_key_check" {
  name = "payment-system-root-access-key-check"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCESS_KEY_CHECK"
  }

  depends_on = [aws_config_configuration_recorder.payment_system_config]

  tags = {
    Name        = "payment-system-root-key-rule"
    Environment = var.environment
    Security    = "critical"
  }
}

resource "aws_config_config_rule" "mfa_enabled_for_iam_console_access" {
  name = "payment-system-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS"
  }

  depends_on = [aws_config_configuration_recorder.payment_system_config]

  tags = {
    Name        = "payment-system-mfa-rule"
    Environment = var.environment
    Security    = "high"
  }
}

# Security automation Lambda function
resource "aws_lambda_function" "security_response" {
  filename         = "security_response.zip"
  function_name    = "payment-system-security-response"
  role            = aws_iam_role.security_response_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.11"
  timeout         = 300

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      ENVIRONMENT = var.environment
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
    }
  }

  kms_key_arn = aws_kms_key.audit_encryption_key.arn

  tags = {
    Name        = "payment-system-security-response"
    Environment = var.environment
    Security    = "high"
  }
}

# IAM role for security response Lambda
resource "aws_iam_role" "security_response_role" {
  name = "payment-system-security-response-role"

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
    Name        = "payment-system-security-response-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "security_response_policy" {
  name = "payment-system-security-response-policy"
  role = aws_iam_role.security_response_role.id

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
          "sns:Publish"
        ]
        Resource = aws_sns_topic.security_alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          "arn:aws:dynamodb:*:*:table/payment-system-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.audit_encryption_key.arn
      }
    ]
  })
}

# WAF v2 Web ACL with advanced rules
resource "aws_wafv2_web_acl" "advanced_protection" {
  name  = "payment-system-advanced-protection"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting per IP
  rule {
    name     = "IPRateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"

        scope_down_statement {
          geo_match_statement {
            country_codes = ["US", "CA", "GB", "FR", "DE", "AU"]  # Allow only specific countries
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "IPRateLimitRule"
      sampled_requests_enabled    = true
    }
  }

  # Geographic blocking
  rule {
    name     = "GeoBlockingRule"
    priority = 2

    action {
      block {}
    }

    statement {
      geo_match_statement {
        country_codes = ["CN", "RU", "KP", "IR"]  # Block high-risk countries
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "GeoBlockingRule"
      sampled_requests_enabled    = true
    }
  }

  # IP reputation blocking
  rule {
    name     = "IPReputationRule"
    priority = 3

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

  # Core rule set
  rule {
    name     = "CoreRuleSetRule"
    priority = 4

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          action_to_use {
            block {}
          }
          name = "SizeRestrictions_BODY"
        }

        rule_action_override {
          action_to_use {
            block {}
          }
          name = "GenericRFI_BODY"
        }
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "CoreRuleSetRule"
      sampled_requests_enabled    = true
    }
  }

  # SQL injection protection
  rule {
    name     = "SQLiProtectionRule"
    priority = 5

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

  # Known bad inputs protection
  rule {
    name     = "KnownBadInputsRule"
    priority = 6

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

  tags = {
    Name        = "payment-system-advanced-waf"
    Environment = var.environment
    Security    = "high"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                 = "PaymentSystemAdvancedWAF"
    sampled_requests_enabled    = true
  }
}

# CloudWatch Insights queries for security analysis
resource "aws_cloudwatch_query_definition" "security_analysis_queries" {
  name = "payment-system-security-analysis"

  log_group_names = [
    aws_cloudwatch_log_group.security_events.name,
    aws_cloudwatch_log_group.api_access_logs.name
  ]

  query_string = <<EOF
fields @timestamp, event_type, details
| filter event_type in ["AUTHENTICATION_FAILED", "RATE_LIMIT_EXCEEDED", "FRAUD_DETECTED"]
| stats count() by event_type
| sort @timestamp desc
EOF
}

# Security automation EventBridge rules
resource "aws_cloudwatch_event_rule" "security_automation" {
  name        = "payment-system-security-automation"
  description = "Trigger security responses for critical events"

  event_pattern = jsonencode({
    source      = ["aws.guardduty", "aws.securityhub"]
    detail-type = ["GuardDuty Finding", "Security Hub Findings - Imported"]
    detail = {
      severity = [7.0, 8.0, 8.5, 9.0, 10.0]
    }
  })

  tags = {
    Name        = "payment-system-security-automation"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "security_response_target" {
  rule      = aws_cloudwatch_event_rule.security_automation.name
  target_id = "SecurityResponseLambda"
  arn       = aws_lambda_function.security_response.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_response.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.security_automation.arn
}