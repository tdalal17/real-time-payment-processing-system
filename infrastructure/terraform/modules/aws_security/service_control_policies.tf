# Service Control Policies for Enterprise Security
# Implements organization-level security controls

# Prevent deletion of critical resources
resource "aws_organizations_policy" "prevent_resource_deletion" {
  name = "PreventCriticalResourceDeletion"
  type = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PreventDeletionOfCriticalResources"
        Effect = "Deny"
        Action = [
          "dynamodb:DeleteTable",
          "kms:DeleteKey",
          "kms:DisableKey",
          "s3:DeleteBucket",
          "iam:DeleteRole",
          "iam:DeletePolicy",
          "lambda:DeleteFunction",
          "apigateway:DELETE",
          "cloudtrail:DeleteTrail",
          "guardduty:DeleteDetector"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
          Bool = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

# Enforce encryption requirements
resource "aws_organizations_policy" "enforce_encryption" {
  name = "EnforceEncryptionRequirements"
  type = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireS3Encryption"
        Effect = "Deny"
        Action = [
          "s3:PutObject"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = ["aws:kms", "AES256"]
          }
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
        }
      },
      {
        Sid    = "RequireDynamoDBEncryption"
        Effect = "Deny"
        Action = [
          "dynamodb:CreateTable"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "dynamodb:EncryptionEnabled" = "false"
          }
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
        }
      },
      {
        Sid    = "RequireLambdaEncryption"
        Effect = "Deny"
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionConfiguration"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "lambda:KMSKeyArn" = "true"
          }
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
        }
      }
    ]
  })
}

# Restrict privileged actions to specific regions
resource "aws_organizations_policy" "region_restriction" {
  name = "RegionRestrictionPolicy"
  type = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RestrictRegions"
        Effect = "Deny"
        NotAction = [
          "iam:*",
          "organizations:*",
          "support:*",
          "trustedadvisor:*"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = [
              "us-east-1",
              "us-west-2",
              "eu-west-1"
            ]
          }
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
        }
      }
    ]
  })
}

# Prevent privilege escalation
resource "aws_organizations_policy" "prevent_privilege_escalation" {
  name = "PreventPrivilegeEscalation"
  type = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PreventIAMPrivilegeEscalation"
        Effect = "Deny"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:CreatePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringNotLike = {
            "aws:PrincipalTag/Department" = "DevOps"
          }
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
        }
      },
      {
        Sid    = "PreventAssumingHighPrivilegeRoles"
        Effect = "Deny"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::*:role/OrganizationAccountAccessRole",
          "arn:aws:iam::*:role/*Admin*",
          "arn:aws:iam::*:role/*Root*"
        ]
        Condition = {
          StringNotLike = {
            "aws:PrincipalTag/Role" = "SecurityAdmin"
          }
        }
      }
    ]
  })
}

# Enforce MFA for sensitive operations
resource "aws_organizations_policy" "enforce_mfa" {
  name = "EnforceMFAForSensitiveOperations"
  type = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireMFAForSensitiveActions"
        Effect = "Deny"
        Action = [
          "dynamodb:DeleteTable",
          "dynamodb:DeleteItem",
          "kms:DeleteKey",
          "iam:DeleteRole",
          "iam:DeleteUser",
          "s3:DeleteBucket",
          "lambda:DeleteFunction"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "false"
          }
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
        }
      }
    ]
  })
}

# Prevent modification of security logging
resource "aws_organizations_policy" "protect_security_logging" {
  name = "ProtectSecurityLogging"
  type = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PreventCloudTrailDisabling"
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "cloudtrail:PutEventSelectors"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = "payment-system"
          }
          StringNotLike = {
            "aws:PrincipalTag/Role" = "SecurityAdmin"
          }
        }
      },
      {
        Sid    = "PreventGuardDutyDisabling"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "guardduty:DisableOrganizationAdminAccount",
          "guardduty:StopMonitoringMembers"
        ]
        Resource = "*"
        Condition = {
          StringNotLike = {
            "aws:PrincipalTag/Role" = "SecurityAdmin"
          }
        }
      },
      {
        Sid    = "PreventConfigDisabling"
        Effect = "Deny"
        Action = [
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "config:StopConfigurationRecorder"
        ]
        Resource = "*"
        Condition = {
          StringNotLike = {
            "aws:PrincipalTag/Role" = "SecurityAdmin"
          }
        }
      }
    ]
  })
}