# Advanced Data Protection and Classification
# AWS Macie, Certificate Manager, and Inspector configuration

# AWS Certificate Manager for TLS termination
resource "aws_acm_certificate" "payment_system_cert" {
  domain_name       = "api.payment-system.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.payment-system.com",
    "admin.payment-system.com",
    "dashboard.payment-system.com"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "payment-system-certificate"
    Environment = var.environment
    Security    = "high"
  }
}

# Certificate validation (requires Route53 hosted zone)
resource "aws_route53_zone" "payment_system_zone" {
  name = "payment-system.com"

  tags = {
    Name        = "payment-system-zone"
    Environment = var.environment
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.payment_system_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.payment_system_zone.zone_id
}

resource "aws_acm_certificate_validation" "payment_system_cert_validation" {
  certificate_arn         = aws_acm_certificate.payment_system_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# AWS Macie for data classification and protection
resource "aws_macie2_account" "payment_system_macie" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                      = "ENABLED"
}

# Macie classification job for S3 buckets
resource "aws_macie2_classification_job" "payment_data_classification" {
  job_type = "ONE_TIME"
  name     = "payment-system-data-classification"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [var.audit_logs_bucket]
    }

    scoping {
      excludes {
        and {
          simple_scope_term {
            comparator = "EQ"
            key        = "OBJECT_EXTENSION"
            values     = ["zip", "gz", "tar"]
          }
        }
      }
    }
  }

  tags = {
    Name        = "payment-system-data-classification"
    Environment = var.environment
    Security    = "high"
  }
}

# Custom data identifier for payment card data
resource "aws_macie2_custom_data_identifier" "payment_card_data" {
  name        = "payment-system-card-data"
  description = "Detect payment card data in payment system"
  
  regex = "\\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|3[0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\\b"
  
  keywords = ["card", "payment", "credit", "debit", "visa", "mastercard", "amex"]

  tags = {
    Name        = "payment-system-card-data-identifier"
    Environment = var.environment
    Security    = "critical"
  }
}

# Macie findings filter for payment system
resource "aws_macie2_findings_filter" "payment_system_filter" {
  name   = "payment-system-findings-filter"
  action = "ARCHIVE"

  finding_criteria {
    criterion {
      field = "type"
      eq    = ["SensitiveData:S3Object/Personal"]
    }

    criterion {
      field = "severity.description"
      eq    = ["High", "Critical"]
    }
  }

  tags = {
    Name        = "payment-system-findings-filter"
    Environment = var.environment
  }
}

# AWS Inspector for vulnerability assessments
resource "aws_inspector2_enabler" "payment_system_inspector" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["ECR", "EC2", "LAMBDA"]
}

# Inspector assessment target (if using EC2 instances)
resource "aws_inspector_assessment_target" "payment_system_target" {
  name = "payment-system-assessment-target"

  resource_group_arn = aws_inspector_resource_group.payment_system_rg.arn
}

resource "aws_inspector_resource_group" "payment_system_rg" {
  tags = {
    Project = "payment-system"
    Environment = var.environment
  }
}

# Assessment template for security scanning
resource "aws_inspector_assessment_template" "payment_system_template" {
  name       = "payment-system-security-assessment"
  target_arn = aws_inspector_assessment_target.payment_system_target.arn
  duration   = 3600  # 1 hour

  rules_package_arns = [
    "arn:aws:inspector:${var.aws_region}:316112463485:rulespackage/0-R01qwB5Q",  # Security Best Practices
    "arn:aws:inspector:${var.aws_region}:316112463485:rulespackage/0-gEjTy7T7",  # Network Reachability
    "arn:aws:inspector:${var.aws_region}:316112463485:rulespackage/0-rExsr2X8",  # Runtime Behavior Analysis
    "arn:aws:inspector:${var.aws_region}:316112463485:rulespackage/0-R01qwB5Q"   # Common Vulnerabilities and Exposures
  ]

  tags = {
    Name        = "payment-system-assessment"
    Environment = var.environment
    Security    = "high"
  }
}

# EventBridge rule for automated Inspector assessments
resource "aws_cloudwatch_event_rule" "weekly_security_assessment" {
  name                = "payment-system-weekly-assessment"
  description         = "Trigger weekly security assessment"
  schedule_expression = "cron(0 2 ? * SUN *)"  # Every Sunday at 2 AM

  tags = {
    Name        = "payment-system-weekly-assessment"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "inspector_assessment_target" {
  rule      = aws_cloudwatch_event_rule.weekly_security_assessment.name
  target_id = "TriggerInspectorAssessment"
  arn       = "arn:aws:inspector:${var.aws_region}:${data.aws_caller_identity.current.account_id}:target/${aws_inspector_assessment_target.payment_system_target.arn}"

  role_arn = aws_iam_role.eventbridge_inspector_role.arn
}

# IAM role for EventBridge to trigger Inspector
resource "aws_iam_role" "eventbridge_inspector_role" {
  name = "payment-system-eventbridge-inspector-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_inspector_policy" {
  name = "payment-system-eventbridge-inspector-policy"
  role = aws_iam_role.eventbridge_inspector_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "inspector:StartAssessmentRun"
        ]
        Resource = "*"
      }
    ]
  })
}

# Data Loss Prevention (DLP) configuration
resource "aws_ssm_parameter" "dlp_config" {
  name  = "/payment-system/${var.environment}/config/data-loss-prevention"
  type  = "SecureString"
  key_id = var.kms_key_arn

  value = jsonencode({
    enable_dlp = "true"
    sensitive_data_patterns = [
      "credit_card_numbers",
      "social_security_numbers", 
      "bank_account_numbers",
      "routing_numbers",
      "personal_identification"
    ]
    data_classification_levels = {
      public = "0"
      internal = "1"
      confidential = "2"
      restricted = "3"
      top_secret = "4"
    }
    encryption_requirements = {
      level_0 = "none"
      level_1 = "transit"
      level_2 = "transit_and_rest"
      level_3 = "end_to_end"
      level_4 = "hardware_security_module"
    }
    data_retention_policies = {
      transaction_data = "7_years"
      audit_logs = "7_years"
      security_logs = "1_year"
      access_logs = "90_days"
      debug_logs = "30_days"
    }
  })

  tags = {
    Name        = "payment-system-dlp-config"
    Environment = var.environment
    Security    = "critical"
  }
}

# Variables
variable "audit_logs_bucket" {
  description = "S3 bucket name for audit logs"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Data sources
data "aws_caller_identity" "current" {}

# Outputs
output "certificate_arn" {
  description = "ACM certificate ARN for TLS termination"
  value       = aws_acm_certificate.payment_system_cert.arn
}

output "macie_account_id" {
  description = "Macie account ID"
  value       = aws_macie2_account.payment_system_macie.id
}

output "inspector_template_arn" {
  description = "Inspector assessment template ARN"
  value       = aws_inspector_assessment_template.payment_system_template.arn
}