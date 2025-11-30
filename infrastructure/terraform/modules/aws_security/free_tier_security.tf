# FREE TIER ONLY - Enterprise Security for Payment System
# Zero-cost security implementation using AWS Free Tier

# Basic VPC (FREE)
resource "aws_vpc" "payment_vpc_free" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "payment-system-free-vpc"
    Environment = var.environment
    CostTier    = "free"
  }
}

# Internet Gateway (FREE)
resource "aws_internet_gateway" "payment_igw_free" {
  vpc_id = aws_vpc.payment_vpc_free.id

  tags = {
    Name        = "payment-system-free-igw"
    Environment = var.environment
    CostTier    = "free"
  }
}

# Public Subnet (FREE - Lambda functions will be public but secured)
resource "aws_subnet" "public_subnet_free" {
  vpc_id                  = aws_vpc.payment_vpc_free.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "payment-system-free-public"
    Environment = var.environment
    CostTier    = "free"
  }
}

# Route Table (FREE)
resource "aws_route_table" "public_rt_free" {
  vpc_id = aws_vpc.payment_vpc_free.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.payment_igw_free.id
  }

  tags = {
    Name        = "payment-system-free-rt"
    Environment = var.environment
    CostTier    = "free"
  }
}

resource "aws_route_table_association" "public_free" {
  subnet_id      = aws_subnet.public_subnet_free.id
  route_table_id = aws_route_table.public_rt_free.id
}

# Security Groups (FREE)
resource "aws_security_group" "lambda_sg_free" {
  name        = "payment-lambda-free-sg"
  description = "FREE tier security group for Lambda"
  vpc_id      = aws_vpc.payment_vpc_free.id

  # Outbound HTTPS only
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound HTTP for AWS services
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "payment-lambda-free-sg"
    Environment = var.environment
    CostTier    = "free"
  }
}

# Network ACLs for additional security (FREE)
resource "aws_network_acl" "secure_nacl_free" {
  vpc_id = aws_vpc.payment_vpc_free.id

  # Allow HTTPS inbound
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 443
    to_port    = 443
  }

  # Allow HTTP inbound (for redirects)
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 80
    to_port    = 80
  }

  # Allow ephemeral ports
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 1024
    to_port    = 65535
  }

  # Allow all outbound
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name        = "payment-secure-free-nacl"
    Environment = var.environment
    CostTier    = "free"
  }
}

resource "aws_network_acl_association" "secure_free" {
  network_acl_id = aws_network_acl.secure_nacl_free.id
  subnet_id      = aws_subnet.public_subnet_free.id
}

# CloudWatch Logs (FREE - 5GB/month)
resource "aws_cloudwatch_log_group" "payment_logs_free" {
  name              = "/aws/lambda/payment-system-free"
  retention_in_days = 7  # Keep costs minimal

  tags = {
    Name        = "payment-system-free-logs"
    Environment = var.environment
    CostTier    = "free"
  }
}

# CloudWatch Alarms for security monitoring (FREE - 10 alarms)
resource "aws_cloudwatch_metric_alarm" "high_error_rate_free" {
  alarm_name          = "payment-system-high-errors-free"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "High error rate detected"
  alarm_actions       = []  # No SNS to keep it free

  dimensions = {
    FunctionName = "payment-system-process-payment"
  }

  tags = {
    Name        = "payment-high-errors"
    Environment = var.environment
    CostTier    = "free"
  }
}

resource "aws_cloudwatch_metric_alarm" "unusual_invocations_free" {
  alarm_name          = "payment-system-unusual-traffic-free"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1000"  # Adjust based on expected traffic
  alarm_description   = "Unusual traffic spike detected"

  dimensions = {
    FunctionName = "payment-system-process-payment"
  }

  tags = {
    Name        = "payment-unusual-traffic"
    Environment = var.environment
    CostTier    = "free"
  }
}

# Basic CloudTrail (FREE - 1 trail for management events)
resource "aws_cloudtrail" "payment_trail_free" {
  name           = "payment-system-free-trail"
  s3_bucket_name = aws_s3_bucket.trail_logs_free.bucket

  # Only management events (FREE)
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    
    # No data events to keep it free
  }

  tags = {
    Name        = "payment-system-free-trail"
    Environment = var.environment
    CostTier    = "free"
  }
}

# S3 bucket for CloudTrail (FREE - 5GB)
resource "aws_s3_bucket" "trail_logs_free" {
  bucket        = "payment-trail-free-${var.environment}-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Name        = "payment-trail-free"
    Environment = var.environment
    CostTier    = "free"
  }
}

resource "aws_s3_bucket_public_access_block" "trail_logs_free_pab" {
  bucket = aws_s3_bucket.trail_logs_free.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket lifecycle to manage costs
resource "aws_s3_bucket_lifecycle_configuration" "trail_logs_free_lifecycle" {
  bucket = aws_s3_bucket.trail_logs_free.id

  rule {
    id     = "cleanup_old_logs"
    status = "Enabled"

    expiration {
      days = 30  # Delete after 30 days to stay within free tier
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Random ID for unique naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

# Outputs
output "free_vpc_id" {
  description = "Free tier VPC ID"
  value       = aws_vpc.payment_vpc_free.id
}

output "free_subnet_id" {
  description = "Free tier subnet ID"
  value       = aws_subnet.public_subnet_free.id
}

output "free_security_group_id" {
  description = "Free tier Lambda security group ID"
  value       = aws_security_group.lambda_sg_free.id
}

output "free_cloudtrail_arn" {
  description = "Free tier CloudTrail ARN"
  value       = aws_cloudtrail.payment_trail_free.arn
}