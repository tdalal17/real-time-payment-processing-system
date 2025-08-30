terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "project_name" { type = string }
variable "aws_region"   { type = string  default = "us-east-1" }

locals {
  name = "${var.project_name}-demo"
}

module "payments_lambda" {
  source      = "../../modules/lambda"
  name        = "${local.name}-payments"
  source_dir  = "${path.root}/../../../src/payments/lambda"
  environment = {
    APP_ENV = "demo"
  }
}

module "api" {
  source           = "../../modules/api_gateway"
  name             = "${local.name}-api"
  lambda_invoke_arn = module.payments_lambda.invoke_arn
  lambda_arn        = module.payments_lambda.function_arn
}

module "payments_table" {
  source         = "../../modules/dynamodb"
  table_name     = "${local.name}-payments"
  partition_key  = "pk"
  sort_key       = "sk"
}

output "api_endpoint" { value = module.api.api_endpoint }
output "lambda_name"  { value = module.payments_lambda.function_name }
output "table_name"   { value = module.payments_table.table_name }


