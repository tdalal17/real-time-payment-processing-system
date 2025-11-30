terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
  }
}

variable "name" {
  type        = string
  description = "Lambda function name"
}

variable "runtime" {
  type        = string
  default     = "python3.12"
  description = "Lambda runtime"
}

variable "handler" {
  type        = string
  default     = "handler.lambda_handler"
  description = "Handler entrypoint"
}

variable "source_dir" {
  type        = string
  description = "Directory of lambda source code"
}

variable "environment" {
  type        = map(string)
  default     = {}
  description = "Environment variables"
}

data "archive_file" "zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/lambda.zip"
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "this" {
  function_name = var.name
  role          = aws_iam_role.lambda.arn
  runtime       = var.runtime
  handler       = var.handler
  filename      = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  environment {
    variables = var.environment
  }
}

output "function_name" { value = aws_lambda_function.this.function_name }
output "function_arn" { value = aws_lambda_function.this.arn }
output "invoke_arn"   { value = aws_lambda_function.this.invoke_arn }


