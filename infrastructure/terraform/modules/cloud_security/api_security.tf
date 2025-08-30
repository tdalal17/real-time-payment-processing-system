# Advanced API Gateway Security Configuration
# Enterprise-grade API protection against misuse and attacks

# API Gateway Request Validator
resource "aws_api_gateway_request_validator" "payment_validator" {
  name                        = "payment-system-request-validator"
  rest_api_id                 = var.api_gateway_id
  validate_request_body       = true
  validate_request_parameters = true
}

# API Gateway Models for request validation
resource "aws_api_gateway_model" "payment_request_model" {
  rest_api_id  = var.api_gateway_id
  name         = "PaymentRequest"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title = "Payment Request Schema"
    type = "object"
    required = ["amount", "currency", "user_id", "merchant_id"]
    properties = {
      amount = {
        type = "number"
        minimum = 0.01
        maximum = 999999.99
        multipleOf = 0.01
      }
      currency = {
        type = "string"
        pattern = "^[A-Z]{3}$"
        enum = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY"]
      }
      user_id = {
        type = "string"
        pattern = "^[a-zA-Z0-9_-]{1,50}$"
        minLength = 1
        maxLength = 50
      }
      merchant_id = {
        type = "string"
        pattern = "^[a-zA-Z0-9_-]{1,50}$"
        minLength = 1
        maxLength = 50
      }
      card_number = {
        type = "string"
        pattern = "^[0-9]{13,19}$"
      }
      cvv = {
        type = "string"
        pattern = "^[0-9]{3,4}$"
      }
      card_holder_name = {
        type = "string"
        minLength = 2
        maxLength = 100
        pattern = "^[a-zA-Z\\s\\-\\.]{2,100}$"
      }
      expiry_month = {
        type = "integer"
        minimum = 1
        maximum = 12
      }
      expiry_year = {
        type = "integer"
        minimum = 2024
        maximum = 2040
      }
    }
    additionalProperties = false
  })
}

# Refund request model
resource "aws_api_gateway_model" "refund_request_model" {
  rest_api_id  = var.api_gateway_id
  name         = "RefundRequest"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title = "Refund Request Schema"
    type = "object"
    required = ["reason"]
    properties = {
      amount = {
        type = "number"
        minimum = 0.01
        maximum = 999999.99
        multipleOf = 0.01
      }
      reason = {
        type = "string"
        enum = ["customer_request", "fraudulent", "duplicate", "processing_error", "merchant_error"]
        minLength = 1
        maxLength = 50
      }
      notes = {
        type = "string"
        maxLength = 500
        pattern = "^[a-zA-Z0-9\\s\\-\\.\\_\\,\\!\\?]{0,500}$"
      }
    }
    additionalProperties = false
  })
}

# API Gateway Usage Plans with sophisticated throttling
resource "aws_api_gateway_usage_plan" "enterprise_plan" {
  name         = "payment-system-enterprise-plan"
  description  = "Enterprise usage plan with high limits"

  api_stages {
    api_id = var.api_gateway_id
    stage  = var.environment
  }

  quota_settings {
    limit  = 1000000  # 1M requests per month
    period = "MONTH"
  }

  throttle_settings {
    rate_limit  = 2000  # 2000 requests per second
    burst_limit = 5000  # 5000 burst capacity
  }
}

resource "aws_api_gateway_usage_plan" "premium_plan" {
  name         = "payment-system-premium-plan"
  description  = "Premium usage plan with moderate limits"

  api_stages {
    api_id = var.api_gateway_id
    stage  = var.environment
  }

  quota_settings {
    limit  = 100000   # 100K requests per month
    period = "MONTH"
  }

  throttle_settings {
    rate_limit  = 500   # 500 requests per second
    burst_limit = 1000  # 1000 burst capacity
  }
}

resource "aws_api_gateway_usage_plan" "basic_plan" {
  name         = "payment-system-basic-plan"
  description  = "Basic usage plan with conservative limits"

  api_stages {
    api_id = var.api_gateway_id
    stage  = var.environment
  }

  quota_settings {
    limit  = 10000   # 10K requests per month
    period = "MONTH"
  }

  throttle_settings {
    rate_limit  = 100   # 100 requests per second
    burst_limit = 200   # 200 burst capacity
  }
}

# API Keys with usage plan associations
resource "aws_api_gateway_api_key" "enterprise_client" {
  name        = "payment-system-enterprise-client"
  description = "Enterprise client API key"
  enabled     = true

  tags = {
    Name        = "payment-system-enterprise-key"
    Environment = var.environment
    ClientTier  = "enterprise"
  }
}

resource "aws_api_gateway_usage_plan_key" "enterprise_client_key" {
  key_id        = aws_api_gateway_api_key.enterprise_client.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.enterprise_plan.id
}

# Request/Response transformation for security
resource "aws_api_gateway_method_response" "payment_response" {
  rest_api_id = var.api_gateway_id
  resource_id = var.payment_resource_id
  http_method = "POST"
  status_code = "200"

  response_parameters = {
    "method.response.header.X-Request-ID" = true
    "method.response.header.X-RateLimit-Remaining" = true
    "method.response.header.X-RateLimit-Reset" = true
  }

  response_models = {
    "application/json" = aws_api_gateway_model.payment_response_model.name
  }
}

resource "aws_api_gateway_model" "payment_response_model" {
  rest_api_id  = var.api_gateway_id
  name         = "PaymentResponse"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title = "Payment Response Schema"
    type = "object"
    required = ["transaction_id", "status", "timestamp"]
    properties = {
      transaction_id = {
        type = "string"
        pattern = "^[a-fA-F0-9-]{36}$"
      }
      status = {
        type = "string"
        enum = ["pending", "completed", "failed", "refunded"]
      }
      amount = {
        type = "number"
        minimum = 0
      }
      currency = {
        type = "string"
        pattern = "^[A-Z]{3}$"
      }
      timestamp = {
        type = "integer"
        minimum = 1000000000
      }
      error_code = {
        type = "string"
        pattern = "^[A-Z_]{1,50}$"
      }
      message = {
        type = "string"
        maxLength = 200
      }
    }
    additionalProperties = false
  })
}

# Integration Response with data transformation
resource "aws_api_gateway_integration_response" "payment_integration_response" {
  rest_api_id = var.api_gateway_id
  resource_id = var.payment_resource_id
  http_method = "POST"
  status_code = "200"

  response_parameters = {
    "method.response.header.X-Request-ID" = "integration.response.header.X-Request-ID"
    "method.response.header.X-RateLimit-Remaining" = "integration.response.header.X-RateLimit-Remaining"
  }

  # Response template to sanitize output
  response_templates = {
    "application/json" = jsonencode({
      transaction_id = "$input.path('$.transaction_id')"
      status = "$input.path('$.status')"
      amount = "$input.path('$.amount')"
      currency = "$input.path('$.currency')"
      timestamp = "$input.path('$.timestamp')"
      # Sensitive data is NOT included in response
    })
  }
}

# Method settings for detailed monitoring
resource "aws_api_gateway_method_settings" "payment_method_settings" {
  rest_api_id = var.api_gateway_id
  stage_name  = var.environment
  method_path = "*/POST"

  settings {
    metrics_enabled        = true
    logging_level         = "INFO"
    data_trace_enabled    = false  # Don't log request/response bodies (PCI-DSS)
    throttling_burst_limit = 2000
    throttling_rate_limit  = 1000
    caching_enabled       = false  # No caching for payment requests
  }
}

# Advanced request mapping template with validation
resource "aws_api_gateway_integration" "secure_payment_integration" {
  rest_api_id = var.api_gateway_id
  resource_id = var.payment_resource_id
  http_method = "POST"
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.lambda_function_arn}/invocations"

  # Request template with input sanitization
  request_templates = {
    "application/json" = jsonencode({
      body = "$util.escapeJavaScript($input.body)"
      headers = {
        "#foreach($header in $input.params().header.keySet())"
        "$header" = "$util.escapeJavaScript($input.params().header.get($header))"
        "#end"
      }
      query_params = {
        "#foreach($param in $input.params().querystring.keySet())"
        "$param" = "$util.escapeJavaScript($input.params().querystring.get($param))"
        "#end"
      }
      path_params = {
        "#foreach($param in $input.params().path.keySet())"
        "$param" = "$util.escapeJavaScript($input.params().path.get($param))"
        "#end"
      }
      stage_variables = {
        "#foreach($var in $stageVariables.keySet())"
        "$var" = "$util.escapeJavaScript($stageVariables.get($var))"
        "#end"
      }
      context = {
        request_id = "$context.requestId"
        source_ip = "$context.identity.sourceIp"
        user_agent = "$context.identity.userAgent"
        request_time = "$context.requestTime"
      }
    })
  }
}

# Gateway Response customization for security
resource "aws_api_gateway_gateway_response" "access_denied" {
  rest_api_id   = var.api_gateway_id
  response_type = "ACCESS_DENIED"
  status_code   = "403"

  response_templates = {
    "application/json" = jsonencode({
      error = "ACCESS_DENIED"
      message = "Access denied. Contact support if you believe this is an error."
      timestamp = "$context.requestTime"
      request_id = "$context.requestId"
    })
  }

  response_parameters = {
    "gatewayresponse.header.X-Request-ID" = "$context.requestId"
    "gatewayresponse.header.X-Security-Policy" = "'strict'"
  }
}

resource "aws_api_gateway_gateway_response" "throttled" {
  rest_api_id   = var.api_gateway_id
  response_type = "THROTTLED"
  status_code   = "429"

  response_templates = {
    "application/json" = jsonencode({
      error = "RATE_LIMITED"
      message = "Request rate limit exceeded. Please retry after some time."
      timestamp = "$context.requestTime"
      retry_after = "60"
    })
  }

  response_parameters = {
    "gatewayresponse.header.Retry-After" = "'60'"
    "gatewayresponse.header.X-RateLimit-Policy" = "'strict'"
  }
}

resource "aws_api_gateway_gateway_response" "unauthorized" {
  rest_api_id   = var.api_gateway_id
  response_type = "UNAUTHORIZED"
  status_code   = "401"

  response_templates = {
    "application/json" = jsonencode({
      error = "UNAUTHORIZED"
      message = "Valid API key required. Include X-API-Key header."
      timestamp = "$context.requestTime"
    })
  }

  response_parameters = {
    "gatewayresponse.header.WWW-Authenticate" = "'Bearer'"
  }
}

# Advanced stage configuration with comprehensive logging
resource "aws_api_gateway_stage" "secure_stage" {
  deployment_id = var.deployment_id
  rest_api_id   = var.api_gateway_id
  stage_name    = "${var.environment}-secure"

  # Enable X-Ray tracing for security analysis
  xray_tracing_enabled = true

  # Comprehensive access logging
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access_logs.arn
    format = jsonencode({
      requestId = "$context.requestId"
      ip = "$context.identity.sourceIp"
      caller = "$context.identity.caller"
      user = "$context.identity.user"
      requestTime = "$context.requestTime"
      httpMethod = "$context.httpMethod"
      resourcePath = "$context.resourcePath"
      status = "$context.status"
      protocol = "$context.protocol"
      responseLength = "$context.responseLength"
      requestTime = "$context.requestTime"
      responseTime = "$context.responseTime"
      userAgent = "$context.identity.userAgent"
      apiKeyId = "$context.identity.apiKeyId"
      principalOrgId = "$context.identity.principalOrgId"
      cognitoIdentityPoolId = "$context.identity.cognitoIdentityPoolId"
      cognitoIdentityId = "$context.identity.cognitoIdentityId"
      error = "$context.error.message"
      integrationError = "$context.integration.error"
      integrationStatus = "$context.integration.status"
      integrationLatency = "$context.integration.latency"
      responseLatency = "$context.responseLatency"
    })
  }

  tags = {
    Name        = "payment-system-secure-stage"
    Environment = var.environment
    Security    = "high"
  }
}

# CloudWatch Log Group for API access logs
resource "aws_cloudwatch_log_group" "api_access_logs" {
  name              = "/aws/apigateway/payment-system-access-${var.environment}"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "payment-system-api-access-logs"
    Environment = var.environment
    Security    = "high"
  }
}

# Custom authorizer Lambda for advanced authentication
resource "aws_lambda_function" "custom_authorizer" {
  filename         = "custom_authorizer.zip"
  function_name    = "payment-system-custom-authorizer"
  role            = aws_iam_role.authorizer_role.arn
  handler         = "authorizer.lambda_handler"
  runtime         = "python3.11"
  timeout         = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
      KMS_KEY_ARN = var.kms_key_arn
    }
  }

  kms_key_arn = var.kms_key_arn

  tags = {
    Name        = "payment-system-custom-authorizer"
    Environment = var.environment
    Security    = "critical"
  }
}

# IAM role for custom authorizer
resource "aws_iam_role" "authorizer_role" {
  name = "payment-system-authorizer-role"

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
    Name        = "payment-system-authorizer-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "authorizer_policy" {
  name = "payment-system-authorizer-policy"
  role = aws_iam_role.authorizer_role.id

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
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = [
          "arn:aws:dynamodb:*:*:table/payment-system-api-keys",
          "arn:aws:dynamodb:*:*:table/payment-system-api-keys/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# API Gateway Authorizer
resource "aws_api_gateway_authorizer" "payment_authorizer" {
  name                   = "payment-system-authorizer"
  rest_api_id            = var.api_gateway_id
  authorizer_uri         = aws_lambda_function.custom_authorizer.invoke_arn
  authorizer_credentials = aws_iam_role.authorizer_execution_role.arn
  type                   = "REQUEST"
  identity_source        = "method.request.header.X-API-Key,method.request.header.Authorization,context.sourceIp"
  
  # Cache authorization results for 5 minutes
  authorizer_result_ttl_in_seconds = 300
}

# Execution role for authorizer
resource "aws_iam_role" "authorizer_execution_role" {
  name = "payment-system-authorizer-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "authorizer_execution_policy" {
  name = "payment-system-authorizer-execution-policy"
  role = aws_iam_role.authorizer_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.custom_authorizer.arn
      }
    ]
  })
}

# Lambda permission for API Gateway to invoke authorizer
resource "aws_lambda_permission" "authorizer_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.custom_authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.api_gateway_id}/authorizers/${aws_api_gateway_authorizer.payment_authorizer.id}"
}

# Variables
variable "api_gateway_id" {
  description = "API Gateway ID"
  type        = string
}

variable "payment_resource_id" {
  description = "Payment resource ID in API Gateway"
  type        = string
}

variable "deployment_id" {
  description = "API Gateway deployment ID"
  type        = string
}

variable "lambda_function_arn" {
  description = "Lambda function ARN for integration"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
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

# Data sources
data "aws_caller_identity" "current" {}

# Outputs
output "custom_authorizer_arn" {
  description = "Custom authorizer Lambda ARN"
  value       = aws_lambda_function.custom_authorizer.arn
}

output "enterprise_api_key_id" {
  description = "Enterprise API key ID"
  value       = aws_api_gateway_api_key.enterprise_client.id
  sensitive   = true
}

output "usage_plans" {
  description = "API Gateway usage plans"
  value = {
    enterprise = aws_api_gateway_usage_plan.enterprise_plan.id
    premium    = aws_api_gateway_usage_plan.premium_plan.id
    basic      = aws_api_gateway_usage_plan.basic_plan.id
  }
}