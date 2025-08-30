# Advanced Enterprise IAM Security Policies
# Sophisticated condition-based access controls to prevent API misuse

# Time-based access policy (business hours only for sensitive operations)
resource "aws_iam_policy" "time_based_access" {
  name        = "payment-system-time-based-access"
  description = "Restrict sensitive operations to business hours"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RestrictSensitiveOperationsToBusinessHours"
        Effect = "Deny"
        Action = [
          "dynamodb:DeleteItem",
          "dynamodb:DeleteTable",
          "lambda:DeleteFunction",
          "apigateway:DELETE",
          "kms:DeleteKey"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
          DateGreaterThan = {
            "aws:CurrentTime" = "18:00Z"  # After 6 PM UTC
          }
          DateLessThan = {
            "aws:CurrentTime" = "08:00Z"  # Before 8 AM UTC
          }
          ForAllValues:StringNotEquals = {
            "aws:PrincipalTag/EmergencyAccess" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "payment-system-time-based-policy"
    Environment = var.environment
    Security    = "high"
  }
}

# Location-based access policy
resource "aws_iam_policy" "location_based_access" {
  name        = "payment-system-location-based-access"
  description = "Restrict access based on geographic location"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RestrictAccessByLocation"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
          IpAddressIfExists = {
            "aws:SourceIp" = [
              "0.0.0.0/0"  # This will be replaced with blocked IP ranges
            ]
          }
          StringNotEquals = {
            "aws:RequestedRegion" = [
              "us-east-1",
              "us-west-2",
              "eu-west-1"
            ]
          }
          ForAllValues:StringNotEquals = {
            "aws:PrincipalTag/GlobalAccess" = "true"
          }
        }
      },
      {
        Sid    = "BlockHighRiskCountries"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
          ForAnyValue:StringEquals = {
            "aws:RequestedRegion" = [
              "cn-north-1",
              "cn-northwest-1",
              "ap-northeast-3"  # Restricted regions
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "payment-system-location-policy"
    Environment = var.environment
    Security    = "high"
  }
}

# API usage patterns policy (prevent abnormal usage)
resource "aws_iam_policy" "api_usage_patterns" {
  name        = "payment-system-api-usage-patterns"
  description = "Prevent abnormal API usage patterns"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PreventBulkDataExtraction"
        Effect = "Deny"
        Action = [
          "dynamodb:Scan",
          "dynamodb:BatchGetItem"
        ]
        Resource = [
          "arn:aws:dynamodb:*:*:table/payment-system-transactions",
          "arn:aws:dynamodb:*:*:table/payment-system-*"
        ]
        Condition = {
          NumericGreaterThan = {
            "dynamodb:Select" = "100"  # Prevent large scans
          }
          StringNotEquals = {
            "aws:PrincipalTag/DataAnalyst" = "true"
          }
        }
      },
      {
        Sid    = "PreventRapidFireRequests"
        Effect = "Deny" 
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:*:*:function:payment-system-*"
        Condition = {
          NumericGreaterThan = {
            "aws:TokenIssueTime" = "${formatdate("YYYY-MM-DD'T'HH:mm:ss'Z'", timeadd(timestamp(), "5m"))}"
          }
          StringNotEquals = {
            "aws:PrincipalTag/HighVolumeClient" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "payment-system-usage-patterns-policy"
    Environment = var.environment
    Security    = "high"
  }
}

# Device compliance policy
resource "aws_iam_policy" "device_compliance" {
  name        = "payment-system-device-compliance"
  description = "Ensure access only from compliant devices"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireSSLClientCertificate"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "RequireManagedDevice"
        Effect = "Deny"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
          StringNotLike = {
            "aws:userid" = "*:managed-device-*"
          }
          StringNotEquals = {
            "aws:PrincipalTag/DeviceCompliant" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "payment-system-device-compliance-policy"
    Environment = var.environment
    Security    = "high"
  }
}

# Session security policy
resource "aws_iam_policy" "session_security" {
  name        = "payment-system-session-security"
  description = "Advanced session security controls"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnforceSessionTimeout"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
          DateGreaterThan = {
            "aws:TokenIssueTime" = "${formatdate("YYYY-MM-DD'T'HH:mm:ss'Z'", timeadd(timestamp(), "4h"))}"
          }
          StringNotEquals = {
            "aws:PrincipalTag/ExtendedSession" = "true"
          }
        }
      },
      {
        Sid    = "PreventSessionHijacking"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
          IpAddressNotEquals = {
            "aws:SourceIp" = "${data.aws_ip_ranges.cloudfront.cidr_blocks}"
          }
          StringNotEquals = {
            "aws:SourceIp" = "#{aws:PrincipalTag/AllowedSourceIP}"
          }
          Bool = {
            "aws:ViaAWSService" = "false"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "payment-system-session-policy"
    Environment = var.environment
    Security    = "critical"
  }
}

# Data protection policy
resource "aws_iam_policy" "data_protection" {
  name        = "payment-system-data-protection"
  description = "Advanced data protection and exfiltration prevention"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PreventDataExfiltration"
        Effect = "Deny"
        Action = [
          "s3:GetObject",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:BatchGetItem"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
          StringNotEquals = {
            "aws:SourceVpc" = aws_vpc.payment_system_vpc.id
          }
          StringNotEquals = {
            "aws:PrincipalTag/DataAccess" = "authorized"
          }
          Bool = {
            "aws:ViaAWSService" = "false"
          }
        }
      },
      {
        Sid    = "PreventUnauthorizedDownloads"
        Effect = "Deny"
        Action = [
          "s3:GetObject*",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
          NumericGreaterThan = {
            "s3:max-keys" = "1000"  # Prevent bulk downloads
          }
          StringNotEquals = {
            "aws:PrincipalTag/BulkDataAccess" = "authorized"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "payment-system-data-protection-policy"
    Environment = var.environment
    Security    = "critical"
  }
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Data sources
data "aws_ip_ranges" "cloudfront" {
  services = ["cloudfront"]
}

data "aws_caller_identity" "current" {}

# Reference to VPC from security module
data "aws_vpc" "payment_system_vpc" {
  tags = {
    Name = "payment-system-vpc"
  }
}

data "aws_sns_topic" "security_alerts" {
  name = "payment-system-security-alerts-${var.environment}"
}

# Local reference to VPC for policies
locals {
  vpc_id = data.aws_vpc.payment_system_vpc.id
}

# Use the VPC ID in policies
resource "aws_vpc" "payment_system_vpc" {
  cidr_block = "10.0.0.0/16"  # This should reference existing VPC
  
  tags = {
    Name = "payment-system-vpc"
    Environment = var.environment
  }
}

resource "aws_sns_topic" "security_alerts" {
  name = "payment-system-security-alerts-${var.environment}"
  
  tags = {
    Name = "payment-system-security-alerts"
    Environment = var.environment
  }
}