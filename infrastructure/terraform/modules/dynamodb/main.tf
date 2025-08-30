terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "table_name" {
  type        = string
  description = "DynamoDB table name"
}

variable "partition_key" {
  type        = string
  description = "Partition key name"
}

variable "sort_key" {
  type        = string
  default     = null
  description = "Sort key name (optional)"
}

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = var.partition_key

  dynamic "attribute" {
    for_each = var.sort_key == null ? [
      { name = var.partition_key, type = "S" }
    ] : [
      { name = var.partition_key, type = "S" },
      { name = var.sort_key,      type = "S" }
    ]
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

output "table_name" { value = aws_dynamodb_table.this.name }
output "table_arn"  { value = aws_dynamodb_table.this.arn }


