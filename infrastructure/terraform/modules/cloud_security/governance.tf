# Enterprise Governance and Standardization
# AWS Control Tower, StackSets, and Resource Access Manager

# CloudFormation StackSet for security standardization across accounts
resource "aws_cloudformation_stack_set" "security_baseline" {
  name             = "payment-system-security-baseline"
  description      = "Security baseline for payment system across all accounts"
  permission_model = "SELF_MANAGED"

  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  parameters = {
    Environment = var.environment
    Project     = "payment-system"
  }

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description = "Payment System Security Baseline"
    
    Parameters = {
      Environment = {
        Type = "String"
        Description = "Environment name"
      }
      Project = {
        Type = "String"
        Description = "Project name"
      }
    }

    Resources = {
      # Mandatory CloudTrail for all accounts
      SecurityCloudTrail = {
        Type = "AWS::CloudTrail::Trail"
        Properties = {
          TrailName = "payment-system-mandatory-trail"
          S3BucketName = "payment-system-central-audit-logs"
          IncludeGlobalServiceEvents = true
          IsMultiRegionTrail = true
          EnableLogFileValidation = true
          KMSKeyId = {
            Ref = "CloudTrailKMSKey"
          }
          Tags = [
            {
              Key = "Project"
              Value = {Ref = "Project"}
            },
            {
              Key = "Environment" 
              Value = {Ref = "Environment"}
            },
            {
              Key = "Security"
              Value = "mandatory"
            }
          ]
        }
      }

      # Mandatory KMS key
      CloudTrailKMSKey = {
        Type = "AWS::KMS::Key"
        Properties = {
          Description = "KMS Key for CloudTrail encryption"
          EnableKeyRotation = true
          KeyPolicy = {
            Version = "2012-10-17"
            Statement = [
              {
                Effect = "Allow"
                Principal = {
                  AWS = {"Fn::Sub" = "arn:aws:iam::${AWS::AccountId}:root"}
                }
                Action = "kms:*"
                Resource = "*"
              },
              {
                Effect = "Allow"
                Principal = {
                  Service = "cloudtrail.amazonaws.com"
                }
                Action = [
                  "kms:Decrypt",
                  "kms:DescribeKey",
                  "kms:Encrypt", 
                  "kms:GenerateDataKey*",
                  "kms:ReEncrypt*"
                ]
                Resource = "*"
              }
            ]
          }
          Tags = [
            {
              Key = "Project"
              Value = {Ref = "Project"}
            }
          ]
        }
      }

      # Mandatory GuardDuty
      MandatoryGuardDuty = {
        Type = "AWS::GuardDuty::Detector"
        Properties = {
          Enable = true
          FindingPublishingFrequency = "FIFTEEN_MINUTES"
          DataSources = {
            S3Logs = {
              Enable = true
            }
            MalwareProtection = {
              ScanEc2InstanceWithFindings = {
                EbsVolumes = true
              }
            }
          }
          Tags = [
            {
              Key = "Project"
              Value = {Ref = "Project"}
            }
          ]
        }
      }

      # Mandatory Config
      MandatoryConfig = {
        Type = "AWS::Config::ConfigurationRecorder"
        Properties = {
          Name = "payment-system-mandatory-config"
          RoleARN = {
            "Fn::GetAtt" = ["ConfigRole", "Arn"]
          }
          RecordingGroup = {
            AllSupported = true
            IncludeGlobalResourceTypes = true
          }
        }
      }

      ConfigRole = {
        Type = "AWS::IAM::Role"
        Properties = {
          AssumeRolePolicyDocument = {
            Version = "2012-10-17"
            Statement = [
              {
                Effect = "Allow"
                Principal = {
                  Service = "config.amazonaws.com"
                }
                Action = "sts:AssumeRole"
              }
            ]
          }
          ManagedPolicyArns = [
            "arn:aws:iam::aws:policy/service-role/ConfigRole"
          ]
          Tags = [
            {
              Key = "Project"
              Value = {Ref = "Project"}
            }
          ]
        }
      }
    }
  })

  tags = {
    Name        = "payment-system-security-baseline"
    Environment = var.environment
    Security    = "mandatory"
  }
}

# StackSet deployment to target accounts
resource "aws_cloudformation_stack_set_instance" "security_baseline_deployment" {
  account_id     = data.aws_caller_identity.current.account_id
  region         = var.aws_region
  stack_set_name = aws_cloudformation_stack_set.security_baseline.name

  parameter_overrides = {
    Environment = var.environment
    Project     = "payment-system"
  }
}

# AWS Resource Access Manager for secure resource sharing
resource "aws_ram_resource_share" "payment_system_share" {
  name                      = "payment-system-security-share"
  description               = "Secure resource sharing for payment system"
  allow_external_principals = false

  tags = {
    Name        = "payment-system-resource-share"
    Environment = var.environment
    Security    = "high"
  }
}

# Share security-related resources
resource "aws_ram_resource_association" "kms_key_share" {
  resource_arn       = var.kms_key_arn
  resource_share_arn = aws_ram_resource_share.payment_system_share.arn
}

resource "aws_ram_resource_association" "vpc_share" {
  resource_arn       = var.vpc_arn
  resource_share_arn = aws_ram_resource_share.payment_system_share.arn
}

# Organization-wide security policies
resource "aws_organizations_policy" "mandatory_security_services" {
  name = "MandatorySecurityServices"
  type = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireSecurityServices"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "config:DeleteConfigurationRecorder",
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "securityhub:DisableSecurityHub"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "payment-system"
          }
          StringNotEquals = {
            "aws:PrincipalTag/SecurityAdmin" = "true"
          }
        }
      },
      {
        Sid    = "RequireEncryption"
        Effect = "Deny"
        Action = [
          "s3:PutObject",
          "dynamodb:CreateTable",
          "rds:CreateDBInstance",
          "lambda:CreateFunction"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "payment-system"
          }
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "mandatory-security-services"
    Environment = var.environment
    Security    = "mandatory"
  }
}

# Backup and disaster recovery configuration
resource "aws_backup_vault" "payment_system_vault" {
  name        = "payment-system-backup-vault"
  kms_key_arn = var.kms_key_arn

  tags = {
    Name        = "payment-system-backup-vault"
    Environment = var.environment
    Security    = "high"
  }
}

resource "aws_backup_plan" "payment_system_backup" {
  name = "payment-system-backup-plan"

  rule {
    rule_name         = "payment_system_daily_backup"
    target_vault_name = aws_backup_vault.payment_system_vault.name
    schedule          = "cron(0 5 ? * * *)"  # Daily at 5 AM

    recovery_point_tags = {
      Project     = "payment-system"
      Environment = var.environment
      BackupType  = "daily"
    }

    lifecycle {
      cold_storage_after = 30
      delete_after       = 365  # Keep for 1 year (PCI-DSS requirement)
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.payment_system_vault.arn

      lifecycle {
        cold_storage_after = 30
        delete_after       = 365
      }
    }
  }

  tags = {
    Name        = "payment-system-backup-plan"
    Environment = var.environment
    Security    = "high"
  }
}

# Resource selection for backup
resource "aws_backup_selection" "payment_system_selection" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "payment-system-backup-selection"
  plan_id      = aws_backup_plan.payment_system_backup.id

  resources = [
    "arn:aws:dynamodb:*:*:table/payment-system-*"
  ]

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Project"
    value = "payment-system"
  }
}

# IAM role for AWS Backup
resource "aws_iam_role" "backup_role" {
  name = "payment-system-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "payment-system-backup-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Variables
variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "vpc_arn" {
  description = "VPC ARN for resource sharing"
  type        = string
}

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

# Outputs
output "stack_set_id" {
  description = "CloudFormation StackSet ID for security baseline"
  value       = aws_cloudformation_stack_set.security_baseline.id
}

output "resource_share_arn" {
  description = "RAM resource share ARN"
  value       = aws_ram_resource_share.payment_system_share.arn
}

output "backup_vault_arn" {
  description = "Backup vault ARN"
  value       = aws_backup_vault.payment_system_vault.arn
}