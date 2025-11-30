# Real-Time Payment Processing System - Project Structure

This document outlines the complete project structure and explains the purpose of each component.

## 📁 Project Overview

```
Real-Time Payment Processing System/
├── 📄 README.md                           # Main project documentation
├── 📄 PROJECT_STRUCTURE.md                # This file
├── 📄 CLAUDE.md                          # Project management and requirements
├── 📄 SESSION_LOG.md                     # Development session history
├── 📄 SECURITY.md                        # Security documentation
├── 📄 CONTRIBUTING.md                    # Contribution guidelines
│
├── 📂 src/                               # Source code
│   ├── 📂 lambdas/                       # AWS Lambda functions
│   │   ├── 📄 requirements.txt           # Python dependencies
│   │   ├── 📂 authorizer/                # API Gateway Custom Authorizer
│   │   │   └── 📄 lambda_function.py     # API key validation and IAM policies
│   │   ├── 📂 process_payment/           # Payment Processing
│   │   │   └── 📄 lambda_function.py     # Main payment logic with fraud detection
│   │   ├── 📂 get_transaction/           # Transaction Retrieval
│   │   │   └── 📄 lambda_function.py     # Single transaction lookup
│   │   ├── 📂 list_transactions/         # Transaction Listing
│   │   │   └── 📄 lambda_function.py     # Transaction history with filtering
│   │   └── 📂 process_refund/            # Refund Processing
│   │       └── 📄 lambda_function.py     # Full/partial refund handling
│   │
│   ├── 📂 common/                        # Shared utilities
│   │   ├── 📄 __init__.py                # Package initialization
│   │   └── 📄 utils.py                   # Common functions and utilities
│   │
│   └── 📂 auth/                          # Authentication components (legacy)
│       ├── 📄 simple_authorizer.py       # Simplified authorizer (development)
│       ├── 📄 custom_authorizer.py       # Custom authorization logic
│       ├── 📄 api_key_manager.py         # API key management
│       └── 📄 security.py                # Security utilities
│
├── 📂 infrastructure/                    # Infrastructure as Code
│   ├── 📄 README.md                     # Infrastructure documentation
│   └── 📂 terraform/                    # Terraform configurations
│       ├── 📂 modules/                  # Reusable Terraform modules
│       │   ├── 📂 api_gateway/          # API Gateway configuration
│       │   ├── 📂 dynamodb/             # DynamoDB table definitions
│       │   ├── 📂 lambda/               # Lambda function deployments
│       │   └── 📂 security/             # Security and IAM configurations
│       └── 📂 envs/                     # Environment-specific configs
│           └── 📂 demo/                 # Demo environment configuration
│
├── 📂 docs/                             # Documentation
│   └── 📄 README.md                    # Documentation index
│
├── 📂 scripts/                          # Deployment and utility scripts
├── 📂 tests/                           # Test files
└── 📄 package.json                     # Node.js dependencies (if any)
```

## 🏗️ Architecture Components

### Core Lambda Functions

| Function | Purpose | Deployment Status |
|----------|---------|------------------|
| **authorizer** | API key validation and authorization | ✅ Deployed |
| **process_payment** | Main payment processing with fraud detection | ✅ Deployed |
| **get_transaction** | Retrieve individual transaction details | ✅ Deployed |
| **list_transactions** | List transaction history with filtering | ✅ Deployed |
| **process_refund** | Handle full and partial refunds | ✅ Deployed |

### Infrastructure

| Component | Description | Status |
|-----------|-------------|--------|
| **API Gateway** | REST API endpoints with custom authorization | ✅ Active |
| **DynamoDB** | Transaction storage and idempotency tracking | ✅ Active |
| **CloudWatch** | Logging and monitoring | ✅ Active |
| **IAM Roles** | Lambda execution and service permissions | ✅ Configured |

## 🔌 API Endpoints

**Base URL**: `https://lorty8qfz4.execute-api.us-east-1.amazonaws.com/demo`

| Method | Endpoint | Function | Description |
|--------|----------|----------|-------------|
| POST | `/payments` | process_payment | Create new payment |
| GET | `/payments` | list_transactions | List transaction history |
| GET | `/payments/{id}` | get_transaction | Get specific transaction |
| POST | `/payments/{id}/refund` | process_refund | Process refund |

## 🔐 Security Features

- **API Key Authentication**: Three-tier access control (Admin/Merchant/Analytics)
- **Custom Authorizer**: REQUEST-type authorizer with detailed logging
- **Input Validation**: JSON schema validation at API Gateway level
- **Fraud Detection**: Rules-based risk scoring system
- **Audit Logging**: Comprehensive transaction and access logging
- **Rate Limiting**: API Gateway throttling (100 requests/minute per key)

## 📊 Data Models

### Transaction Record
```json
{
  "transaction_id": "uuid",
  "user_id": "string",
  "merchant_id": "string", 
  "amount": "decimal",
  "currency": "string",
  "status": "completed|declined|pending_review",
  "timestamp": "number",
  "created_at": "iso_string",
  "fraud_check": {...},
  "refund_info": {...}
}
```

### API Keys
- **Admin**: `pk_demo_4dMUudRZuMNQYNMJlJ5fPvoGGq-CcUbZq7_OI5kS7eQ`
- **Merchant**: `pk_demo_NNYk8ftmig21ct2STb-QIV958nTor2uMz5n3XdcrDTY`
- **Analytics**: `pk_demo_8ecjpI1J21aGbRU6p7JHoE2Mni5rvVMtGQe7Rm8EPww`

## 🚀 Current System Status

**Deployment**: Fully operational on AWS
**Stage**: demo
**Last Updated**: 2025-08-27
**Version**: 1.0.0

## 📝 Development Notes

- All Lambda functions use Python 3.9+ runtime
- DynamoDB tables configured with on-demand billing
- API Gateway configured with custom domain support
- CloudWatch logs retention set to 14 days
- All components follow AWS Well-Architected Framework principles