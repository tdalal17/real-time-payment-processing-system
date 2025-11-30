# AWS Systems Manager Security Configuration
# Centralized and secure configuration management

# Parameter Store for secure configuration
resource "aws_ssm_parameter" "payment_system_config" {
  name  = "/payment-system/${var.environment}/config/security"
  type  = "SecureString"
  key_id = var.kms_key_arn

  value = jsonencode({
    max_payment_amount = "999999.99"
    fraud_threshold = "0.85"
    session_timeout = "3600"
    rate_limit_default = "100"
    encryption_algorithm = "AES-256-GCM"
    audit_retention_days = "365"
    mfa_required_for_admin = "true"
    geo_blocking_enabled = "true"
    blocked_countries = ["CN", "RU", "KP", "IR"]
    allowed_currencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY"]
  })

  tags = {
    Name        = "payment-system-security-config"
    Environment = var.environment
    Security    = "high"
    Compliance  = "PCI-DSS"
  }
}

# API endpoint configuration
resource "aws_ssm_parameter" "api_endpoints_config" {
  name  = "/payment-system/${var.environment}/config/api-endpoints"
  type  = "SecureString"
  key_id = var.kms_key_arn

  value = jsonencode({
    base_url = "https://lorty8qfz4.execute-api.us-east-1.amazonaws.com/${var.environment}"
    timeout_seconds = "30"
    retry_attempts = "3"
    circuit_breaker_threshold = "5"
    health_check_interval = "60"
    maintenance_mode = "false"
    feature_flags = {
      enable_fraud_detection = "true"
      enable_real_time_monitoring = "true"
      enable_advanced_logging = "true"
      enable_rate_limiting = "true"
    }
  })

  tags = {
    Name        = "payment-system-api-config"
    Environment = var.environment
  }
}

# Database configuration parameters
resource "aws_ssm_parameter" "database_config" {
  name  = "/payment-system/${var.environment}/config/database"
  type  = "SecureString"
  key_id = var.kms_key_arn

  value = jsonencode({
    read_capacity = "5"
    write_capacity = "5"
    backup_retention_days = "35"
    point_in_time_recovery = "true"
    encryption_at_rest = "true"
    table_prefix = "payment-system"
    ttl_enabled = "true"
    global_secondary_indexes = "true"
  })

  tags = {
    Name        = "payment-system-database-config"
    Environment = var.environment
  }
}

# Monitoring and alerting configuration
resource "aws_ssm_parameter" "monitoring_config" {
  name  = "/payment-system/${var.environment}/config/monitoring"
  type  = "SecureString"
  key_id = var.kms_key_arn

  value = jsonencode({
    log_level = "INFO"
    metrics_enabled = "true"
    xray_tracing = "true"
    detailed_monitoring = "true"
    alert_thresholds = {
      error_rate_percent = "5"
      latency_ms = "5000"
      failed_auth_per_minute = "10"
      fraud_score_threshold = "0.85"
    }
    notification_channels = {
      email = "security@company.com"
      slack_webhook = ""
      pagerduty_key = ""
    }
  })

  tags = {
    Name        = "payment-system-monitoring-config"
    Environment = var.environment
  }
}

# Secrets rotation configuration
resource "aws_ssm_parameter" "secrets_rotation" {
  name  = "/payment-system/${var.environment}/config/secrets-rotation"
  type  = "SecureString"
  key_id = var.kms_key_arn

  value = jsonencode({
    api_key_rotation_days = "90"
    kms_key_rotation_days = "365"
    webhook_secret_rotation_days = "30"
    database_password_rotation_days = "60"
    certificate_renewal_days = "30"
    automatic_rotation = "true"
    rotation_notifications = "true"
  })

  tags = {
    Name        = "payment-system-secrets-rotation"
    Environment = var.environment
    Security    = "critical"
  }
}

# Compliance configuration
resource "aws_ssm_parameter" "compliance_config" {
  name  = "/payment-system/${var.environment}/config/compliance"
  type  = "SecureString"
  key_id = var.kms_key_arn

  value = jsonencode({
    pci_dss_level = "1"
    sox_compliance = "true"
    gdpr_compliance = "true"
    data_residency_requirements = ["US", "EU"]
    audit_log_retention_years = "7"
    encryption_standards = ["AES-256", "RSA-2048"]
    key_management_standards = ["FIPS-140-2-Level-3"]
    access_control_standards = ["RBAC", "ABAC"]
    incident_response_plan = "enabled"
    business_continuity_plan = "enabled"
  })

  tags = {
    Name        = "payment-system-compliance-config"
    Environment = var.environment
    Compliance  = "PCI-DSS"
  }
}

# Automation documents for security operations
resource "aws_ssm_document" "security_incident_response" {
  name          = "payment-system-security-incident-response"
  document_type = "Automation"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "0.3"
    description = "Automated security incident response for payment system"
    assumeRole = aws_iam_role.automation_role.arn
    parameters = {
      IncidentType = {
        type = "String"
        description = "Type of security incident"
        allowedValues = ["DDOS", "FRAUD", "BREACH", "UNAUTHORIZED_ACCESS"]
      }
      SeverityLevel = {
        type = "String"
        description = "Severity level of the incident"
        allowedValues = ["LOW", "MEDIUM", "HIGH", "CRITICAL"]
        default = "MEDIUM"
      }
    }
    mainSteps = [
      {
        name = "NotifySecurityTeam"
        action = "aws:publish"
        inputs = {
          TopicArn = var.sns_topic_arn
          Message = "Security incident detected: {{IncidentType}} - Severity: {{SeverityLevel}}"
        }
      },
      {
        name = "EnableDetailedLogging"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "logs"
          Api = "PutRetentionPolicy"
          logGroupName = "/aws/payment-system/security-events"
          retentionInDays = 365
        }
      },
      {
        name = "IsolateAffectedResources"
        action = "aws:branch"
        inputs = {
          Choices = [
            {
              NextStep = "BlockSuspiciousIPs"
              Variable = "{{IncidentType}}"
              StringEquals = "UNAUTHORIZED_ACCESS"
            },
            {
              NextStep = "EnableDDoSProtection"
              Variable = "{{IncidentType}}"
              StringEquals = "DDOS"
            }
          ]
          Default = "StandardResponse"
        }
      }
    ]
  })

  tags = {
    Name        = "payment-system-incident-response"
    Environment = var.environment
    Security    = "critical"
  }
}

# Automation role for security operations
resource "aws_iam_role" "automation_role" {
  name = "payment-system-automation-role"

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
    Name        = "payment-system-automation-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "automation_policy" {
  name = "payment-system-automation-policy"
  role = aws_iam_role.automation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "logs:PutRetentionPolicy",
          "wafv2:UpdateWebACL",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
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

# Patch management configuration
resource "aws_ssm_patch_baseline" "payment_system_baseline" {
  name             = "payment-system-patch-baseline"
  description      = "Patch baseline for payment system security"
  operating_system = "AMAZON_LINUX_2"

  approval_rule {
    approve_after_days = 7
    compliance_level   = "CRITICAL"

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Security", "Bugfix", "Critical"]
    }

    patch_filter {
      key    = "SEVERITY"
      values = ["Critical", "Important"]
    }
  }

  approval_rule {
    approve_after_days = 14
    compliance_level   = "HIGH"

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Security", "Bugfix"]
    }
  }

  tags = {
    Name        = "payment-system-patch-baseline"
    Environment = var.environment
    Security    = "high"
  }
}

# Variables
variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

# Outputs
output "security_config_parameter" {
  description = "Security configuration parameter name"
  value       = aws_ssm_parameter.payment_system_config.name
}

output "automation_role_arn" {
  description = "Automation role ARN for security operations"
  value       = aws_iam_role.automation_role.arn
}

output "incident_response_document" {
  description = "Security incident response automation document"
  value       = aws_ssm_document.security_incident_response.name
}