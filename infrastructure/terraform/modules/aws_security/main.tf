# Enterprise AWS Security Infrastructure
# PCI-DSS Level 1 Compliant Cloud Security

# VPC with isolated network architecture
resource "aws_vpc" "payment_system_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "payment-system-vpc"
    Environment = var.environment
    Project     = "payment-system"
    Security    = "high"
    Compliance  = "PCI-DSS"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "payment_system_igw" {
  vpc_id = aws_vpc.payment_system_vpc.id

  tags = {
    Name        = "payment-system-igw"
    Environment = var.environment
    Project     = "payment-system"
  }
}

# Private subnets for Lambda functions (multi-AZ)
resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.payment_system_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "payment-system-private-a"
    Environment = var.environment
    Type        = "private"
    Security    = "high"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.payment_system_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "payment-system-private-b"
    Environment = var.environment
    Type        = "private"
    Security    = "high"
  }
}

# Public subnets for NAT Gateways
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.payment_system_vpc.id
  cidr_block              = "10.0.101.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "payment-system-public-a"
    Environment = var.environment
    Type        = "public"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.payment_system_vpc.id
  cidr_block              = "10.0.102.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name        = "payment-system-public-b"
    Environment = var.environment
    Type        = "public"
  }
}

# NAT Gateways for private subnet internet access
resource "aws_eip" "nat_gateway_a" {
  domain = "vpc"
  
  tags = {
    Name        = "payment-system-nat-eip-a"
    Environment = var.environment
  }
}

resource "aws_eip" "nat_gateway_b" {
  domain = "vpc"
  
  tags = {
    Name        = "payment-system-nat-eip-b"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "payment_system_nat_a" {
  allocation_id = aws_eip.nat_gateway_a.id
  subnet_id     = aws_subnet.public_subnet_a.id

  tags = {
    Name        = "payment-system-nat-a"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.payment_system_igw]
}

resource "aws_nat_gateway" "payment_system_nat_b" {
  allocation_id = aws_eip.nat_gateway_b.id
  subnet_id     = aws_subnet.public_subnet_b.id

  tags = {
    Name        = "payment-system-nat-b"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.payment_system_igw]
}

# Route tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.payment_system_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.payment_system_igw.id
  }

  tags = {
    Name        = "payment-system-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table" "private_rt_a" {
  vpc_id = aws_vpc.payment_system_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.payment_system_nat_a.id
  }

  tags = {
    Name        = "payment-system-private-rt-a"
    Environment = var.environment
  }
}

resource "aws_route_table" "private_rt_b" {
  vpc_id = aws_vpc.payment_system_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.payment_system_nat_b.id
  }

  tags = {
    Name        = "payment-system-private-rt-b"
    Environment = var.environment
  }
}

# Route table associations
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt_b.id
}

# Security Groups
resource "aws_security_group" "lambda_sg" {
  name        = "payment-system-lambda-sg"
  description = "Security group for payment processing Lambda functions"
  vpc_id      = aws_vpc.payment_system_vpc.id

  # Outbound rules (restrictive)
  egress {
    description = "HTTPS to DynamoDB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS to AWS services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "payment-system-lambda-sg"
    Environment = var.environment
    Security    = "high"
  }
}

resource "aws_security_group" "api_gateway_sg" {
  name        = "payment-system-api-gateway-sg"
  description = "Security group for API Gateway"
  vpc_id      = aws_vpc.payment_system_vpc.id

  # Inbound rules (HTTPS only)
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "payment-system-api-gateway-sg"
    Environment = var.environment
    Security    = "high"
  }
}

# VPC Endpoints for private AWS service access
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.payment_system_vpc.id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "dynamodb:Query",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Project" = "payment-system"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "payment-system-dynamodb-endpoint"
    Environment = var.environment
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.payment_system_vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  tags = {
    Name        = "payment-system-s3-endpoint"
    Environment = var.environment
  }
}

# CloudTrail for comprehensive API auditing
resource "aws_cloudtrail" "payment_system_trail" {
  name           = "payment-system-audit-trail"
  s3_bucket_name = aws_s3_bucket.audit_logs.id

  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::DynamoDB::Table"
      values = ["arn:aws:dynamodb:*:*:table/payment-system-*"]
    }

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda:*:*:function:payment-system-*"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  kms_key_id = aws_kms_key.audit_encryption_key.arn

  tags = {
    Name        = "payment-system-cloudtrail"
    Environment = var.environment
    Security    = "high"
    Compliance  = "PCI-DSS"
  }
}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "audit_logs" {
  bucket        = "payment-system-audit-logs-${var.environment}-${random_id.bucket_suffix.hex}"
  force_destroy = false

  tags = {
    Name        = "payment-system-audit-logs"
    Environment = var.environment
    Security    = "high"
    Compliance  = "PCI-DSS"
  }
}

resource "aws_s3_bucket_encryption" "audit_logs_encryption" {
  bucket = aws_s3_bucket.audit_logs.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.audit_encryption_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_versioning" "audit_logs_versioning" {
  bucket = aws_s3_bucket.audit_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "audit_logs_pab" {
  bucket = aws_s3_bucket.audit_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# GuardDuty for threat detection
resource "aws_guardduty_detector" "payment_system_guardduty" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Name        = "payment-system-guardduty"
    Environment = var.environment
    Security    = "high"
  }
}

# AWS Config for compliance monitoring
resource "aws_config_configuration_recorder" "payment_system_config" {
  name     = "payment-system-config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "payment_system_config" {
  name           = "payment-system-config-delivery"
  s3_bucket_name = aws_s3_bucket.config_logs.bucket
}

# S3 bucket for Config logs
resource "aws_s3_bucket" "config_logs" {
  bucket        = "payment-system-config-logs-${var.environment}-${random_id.bucket_suffix.hex}"
  force_destroy = false

  tags = {
    Name        = "payment-system-config-logs"
    Environment = var.environment
    Security    = "high"
  }
}

# AWS Security Hub for centralized security monitoring
resource "aws_securityhub_account" "payment_system_security_hub" {
  enable_default_standards = true
}

# Enable CIS AWS Foundations Benchmark
resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:::ruleset/finding-format/aws-foundational-security-standard/v/1.0.0"
}

# Enable AWS Foundational Security Standard
resource "aws_securityhub_standards_subscription" "aws_foundational" {
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standard/aws-foundational-security-standard/v/1.0.0"
}

# KMS key for audit encryption
resource "aws_kms_key" "audit_encryption_key" {
  description             = "Payment System Audit Encryption Key"
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
        Sid    = "Allow CloudTrail"
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
  })

  tags = {
    Name        = "payment-system-audit-key"
    Environment = var.environment
    Security    = "high"
  }
}

# IAM role for AWS Config
resource "aws_iam_role" "config_role" {
  name = "payment-system-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "payment-system-config-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "config_role_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# Secrets Manager for sensitive configuration
resource "aws_secretsmanager_secret" "payment_system_secrets" {
  name                    = "payment-system-secrets-${var.environment}"
  description             = "Payment system sensitive configuration"
  recovery_window_in_days = 30
  kms_key_id              = aws_kms_key.audit_encryption_key.arn

  tags = {
    Name        = "payment-system-secrets"
    Environment = var.environment
    Security    = "high"
  }
}

# Initial secret values
resource "aws_secretsmanager_secret_version" "payment_system_secrets" {
  secret_id = aws_secretsmanager_secret.payment_system_secrets.id
  secret_string = jsonencode({
    api_encryption_key = random_password.api_encryption_key.result
    webhook_signing_secret = random_password.webhook_signing_secret.result
    database_encryption_key = random_password.database_encryption_key.result
    fraud_detection_threshold = "0.85"
    max_payment_amount = "999999.99"
  })
}

# Random passwords for secrets
resource "random_password" "api_encryption_key" {
  length  = 32
  special = true
}

resource "random_password" "webhook_signing_secret" {
  length  = 64
  special = true
}

resource "random_password" "database_encryption_key" {
  length  = 32
  special = true
}

# Network ACLs for additional security
resource "aws_network_acl" "private_nacl" {
  vpc_id = aws_vpc.payment_system_vpc.id

  # Allow inbound HTTPS
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.0.0/16"
    from_port  = 443
    to_port    = 443
  }

  # Allow outbound HTTPS
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow ephemeral ports for responses
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name        = "payment-system-private-nacl"
    Environment = var.environment
    Security    = "high"
  }
}

resource "aws_network_acl_association" "private_a" {
  network_acl_id = aws_network_acl.private_nacl.id
  subnet_id      = aws_subnet.private_subnet_a.id
}

resource "aws_network_acl_association" "private_b" {
  network_acl_id = aws_network_acl.private_nacl.id
  subnet_id      = aws_subnet.private_subnet_b.id
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Random ID for unique resource names
resource "random_id" "bucket_suffix" {
  byte_length = 4
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

# Outputs
output "vpc_id" {
  description = "VPC ID for payment system"
  value       = aws_vpc.payment_system_vpc.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for Lambda functions"
  value       = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
}

output "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  value       = aws_security_group.lambda_sg.id
}

output "secrets_manager_arn" {
  description = "Secrets Manager ARN for payment system secrets"
  value       = aws_secretsmanager_secret.payment_system_secrets.arn
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN for audit logging"
  value       = aws_cloudtrail.payment_system_trail.arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.payment_system_guardduty.id
}