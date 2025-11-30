# AWS Shield Advanced Configuration
# Enterprise DDoS protection for payment processing system

# Note: AWS Shield Advanced requires manual subscription through AWS Console
# This configuration sets up the resources to work with Shield Advanced

# CloudWatch Alarms for DDoS detection
resource "aws_cloudwatch_metric_alarm" "ddos_attack_alarm" {
  alarm_name          = "payment-system-ddos-attack"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DDoSDetected"
  namespace           = "AWS/DDoSProtection"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "DDoS attack detected on payment system"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = {
    Name        = "payment-system-ddos-alarm"
    Environment = var.environment
    Security    = "critical"
  }
}

# Application Load Balancer for Shield Advanced protection
resource "aws_lb" "payment_system_alb" {
  name               = "payment-system-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]

  enable_deletion_protection = true
  enable_http2              = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "payment-system-alb"
    enabled = true
  }

  tags = {
    Name        = "payment-system-alb"
    Environment = var.environment
    Security    = "high"
  }
}

# Security group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "payment-system-alb-sg"
  description = "Security group for payment system ALB"
  vpc_id      = aws_vpc.payment_system_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "payment-system-alb-sg"
    Environment = var.environment
    Security    = "high"
  }
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "payment-system-alb-logs-${var.environment}-${random_id.bucket_suffix.hex}"
  force_destroy = false

  tags = {
    Name        = "payment-system-alb-logs"
    Environment = var.environment
    Security    = "high"
  }
}

resource "aws_s3_bucket_policy" "alb_logs_policy" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_elb_service_account.main.id}:root"
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/payment-system-alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/payment-system-alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# Shield Response Team (SRT) access role
resource "aws_iam_role" "shield_response_team_role" {
  name = "payment-system-shield-response-team-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::aws:root"
        }
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      }
    ]
  })

  tags = {
    Name        = "payment-system-srt-role"
    Environment = var.environment
    Security    = "critical"
  }
}

resource "aws_iam_role_policy" "shield_response_team_policy" {
  name = "payment-system-shield-response-team-policy"
  role = aws_iam_role.shield_response_team_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:List*",
          "cloudfront:Get*",
          "route53:List*",
          "route53:Get*",
          "elasticloadbalancing:Describe*",
          "ec2:Describe*",
          "logs:Describe*",
          "logs:Get*",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*"
        ]
        Resource = "*"
      }
    ]
  })
}

# DDoS protection resources
resource "aws_route53_health_check" "payment_api_health" {
  fqdn                            = "lorty8qfz4.execute-api.us-east-1.amazonaws.com"
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/demo/health"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_alarm_region         = var.aws_region
  cloudwatch_alarm_name           = "payment-system-api-health"
  insufficient_data_health_status = "Failure"

  tags = {
    Name        = "payment-system-api-health-check"
    Environment = var.environment
  }
}

# Emergency response procedures documentation
resource "aws_s3_object" "emergency_procedures" {
  bucket = aws_s3_bucket.audit_logs.id
  key    = "security/emergency-response-procedures.json"
  
  content = jsonencode({
    version = "1.0"
    last_updated = formatdate("YYYY-MM-DD", timestamp())
    procedures = {
      ddos_attack = {
        priority = "CRITICAL"
        steps = [
          "Verify attack through CloudWatch metrics",
          "Contact AWS Shield Response Team",
          "Implement emergency rate limiting",
          "Activate backup API endpoints",
          "Notify stakeholders via SNS"
        ]
        contacts = [
          "security@company.com",
          "devops@company.com",
          "+1-555-SECURITY"
        ]
      }
      data_breach = {
        priority = "CRITICAL"
        steps = [
          "Isolate affected systems",
          "Preserve evidence",
          "Notify legal and compliance teams",
          "Implement containment measures",
          "Begin forensic investigation"
        ]
        compliance_requirements = [
          "Notify authorities within 72 hours (GDPR)",
          "Document all actions taken",
          "Prepare customer notifications"
        ]
      }
      fraud_detection = {
        priority = "HIGH"
        steps = [
          "Verify fraud indicators",
          "Block suspicious transactions",
          "Disable compromised accounts",
          "Initiate investigation workflow",
          "Update fraud detection rules"
        ]
      }
    }
  })

  tags = {
    Name        = "payment-system-emergency-procedures"
    Environment = var.environment
    Security    = "critical"
  }
}

# Data source for ELB service account
data "aws_elb_service_account" "main" {}

# Additional outputs for Shield Advanced configuration
output "alb_arn" {
  description = "Application Load Balancer ARN for Shield Advanced protection"
  value       = aws_lb.payment_system_alb.arn
}

output "route53_health_check_id" {
  description = "Route53 health check ID for monitoring"
  value       = aws_route53_health_check.payment_api_health.id
}

output "security_alerts_topic_arn" {
  description = "SNS topic ARN for security alerts"
  value       = aws_sns_topic.security_alerts.arn
}