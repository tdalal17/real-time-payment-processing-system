# Real-Time Payment Processing System

A serverless payment processing platform built on AWS Lambda, API Gateway, and DynamoDB. Handles payment processing, fraud detection, and transaction management.

## System Overview

- **Base URL**: `https://your-api-gateway-url.execute-api.region.amazonaws.com/stage`
- **Architecture**: AWS Serverless (Lambda + API Gateway + DynamoDB)
- **Version**: 1.0.0

## Table of Contents

- [Architecture](#architecture)
- [Features](#features)
- [Security](#security)
- [API Endpoints](#api-endpoints)
- [Quick Start](#quick-start)
- [Usage Examples](#usage-examples)
- [Testing](#testing)
- [Project Structure](#project-structure)

## Architecture

The system uses a serverless, event-driven architecture:

```
┌─────────────────┐    ┌──────────────────┐    ┌───────────────┐
│   API Gateway   │────│  Custom          │────│   Lambda      │
│                 │    │  Authorizer      │    │   Functions   │
│ • Rate Limiting │    │ • API Key Auth   │    │ • Payment     │
│ • Input Valid.  │    │ • IAM Policies   │    │ • Transaction │
│ • CORS Headers  │    │ • Audit Logs     │    │ • Refunds     │
└─────────────────┘    └──────────────────┘    └───────────────┘
         │                                              │
         │              ┌──────────────────┐            │
         └──────────────│    DynamoDB      │────────────┘
                        │                  │
                        │ • Transactions   │
                        │ • Idempotency    │
                        │ • Audit Trail    │
                        └──────────────────┘
```

### Core Components

- **API Gateway**: RESTful API with custom authorization
- **Lambda Functions**: 5 serverless functions for payment operations
- **DynamoDB**: Transaction and idempotency storage
- **Custom Authorizer**: API key-based authentication
- **CloudWatch**: Logging and monitoring

## Features

### Payment Processing
- Real-time payment processing with instant confirmation
- Multi-currency support (USD, EUR, GBP)
- Idempotency handling to prevent duplicate payments
- Fraud detection with rules-based risk scoring
- Input validation and business rule enforcement

### Transaction Management
- Full and partial refund processing
- Transaction history with filtering
- Status tracking (pending, completed, declined, refunded)
- Search by user, merchant, or status

### Security
- API Key authentication with permission-based access control
- Custom REQUEST authorizer with IAM policy generation
- Rate limiting (100 requests/minute default)
- Audit logging for compliance
- Sensitive data masking in logs

### Fraud Detection
- Real-time risk scoring
- Amount threshold monitoring
- Automated decisions (Approve/Review/Decline)
- Configurable risk rules

## Security

### Authentication & Authorization

The system uses a three-tier API key architecture:

| Access Level | Permissions | Rate Limit | Use Case |
|-------------|-------------|------------|----------|
| Admin | Full access (Create, Read, Refund) | 1000/min | System administration |
| Merchant | Create & Read payments | 100/min | Point of sale systems |
| Analytics | Read-only access | 500/min | Reporting & analysis |

### API Keys (Demo Environment)
```bash
# Admin API Key (Full Access)
X-API-Key: pk_admin_demo_key_12345

# Merchant API Key (Payments + Read)
X-API-Key: pk_merchant_demo_key_67890

# Analytics API Key (Read Only)
X-API-Key: pk_analytics_demo_key_54321
```

### Security Features

- Custom REQUEST authorizer validates API keys and generates IAM policies
- Input validation prevents malformed requests
- Rate limiting protects against abuse
- Comprehensive audit logging
- Data masking for sensitive information

## API Endpoints

### Base URL
```
https://your-api-gateway-url.execute-api.region.amazonaws.com/stage
```

### Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/payments` | Create new payment | Yes |
| GET | `/payments` | List transaction history | Yes |
| GET | `/payments/{id}` | Get specific transaction | Yes |
| POST | `/payments/{id}/refund` | Process refund | Yes |

## Quick Start

### Prerequisites
- Valid API key (see Security section above)
- HTTP client (curl, Postman, or similar)

### 1. Create a Payment
```bash
curl -X POST https://your-api-gateway-url.execute-api.region.amazonaws.com/stage/payments \
  -H "X-API-Key: your_admin_api_key_here" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 25.50,
    "currency": "USD", 
    "user_id": "user123",
    "merchant_id": "shop456"
  }'
```

Response:
```json
{
  "transaction_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "completed",
  "amount": "25.50",
  "currency": "USD",
  "timestamp": 1693478400000,
  "message": "Payment processed successfully",
  "fraud_check": {
    "risk_level": "LOW",
    "fraud_score": 10
  }
}
```

### **2. Retrieve Transaction**
```bash
curl -X GET https://your-api-gateway-url.execute-api.region.amazonaws.com/stage/payments/a1b2c3d4-e5f6-7890-abcd-ef1234567890 \
  -H "X-API-Key: your_admin_api_key_here"
```

### **3. List Transactions**
```bash
curl -X GET "https://your-api-gateway-url.execute-api.region.amazonaws.com/stage/payments?user_id=user123&limit=10" \
  -H "X-API-Key: your_admin_api_key_here"
```

### **4. Process Refund**
```bash
curl -X POST https://your-api-gateway-url.execute-api.region.amazonaws.com/stage/payments/a1b2c3d4-e5f6-7890-abcd-ef1234567890/refund \
  -H "X-API-Key: your_admin_api_key_here" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 25.50,
    "reason": "Customer requested refund"
  }'
```

---

## Usage Examples

### Example 1: High-Value Transaction (Fraud Detection)
```bash
curl -X POST https://your-api-gateway-url.execute-api.region.amazonaws.com/stage/payments \
  -H "X-API-Key: your_admin_api_key_here" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 5000.00,
    "currency": "USD",
    "user_id": "user789",
    "merchant_id": "electronics_store"
  }'
```

Response (High Risk):
```json
{
  "transaction_id": "x1y2z3a4-b5c6-7890-def1-234567890abc",
  "status": "pending_review",
  "amount": "5000.00",
  "currency": "USD", 
  "timestamp": 1693478460000,
  "message": "Payment requires manual review"
}
```

### Example 2: Partial Refund
```bash
curl -X POST https://your-api-gateway-url.execute-api.region.amazonaws.com/stage/payments/a1b2c3d4-e5f6-7890-abcd-ef1234567890/refund \
  -H "X-API-Key: your_admin_api_key_here" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 10.00,
    "reason": "Partial refund for damaged item"
  }'
```

Response:
```json
{
  "refund_id": "ref_123456789",
  "transaction_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "refund_amount": "10.00",
  "original_amount": "25.50",
  "total_refunded": "10.00",
  "status": "partially_refunded",
  "message": "Refund processed successfully"
}
```

### Example 3: Transaction History with Filtering
```bash
curl -X GET "https://your-api-gateway-url.execute-api.region.amazonaws.com/stage/payments?merchant_id=shop456&status=completed&limit=5" \
  -H "X-API-Key: your_admin_api_key_here"
```

---

## Testing

### Test Scenarios

#### Successful Payment
```json
{
  "amount": 100.00,
  "currency": "USD",
  "user_id": "test_user",
  "merchant_id": "test_merchant"
}
```

#### High-Risk Payment (Review Required)
```json
{
  "amount": 5000.00,
  "currency": "USD", 
  "user_id": "test_user",
  "merchant_id": "electronics"
}
```

#### Declined Payment (Very High Risk)
```json
{
  "amount": 10000.00,
  "currency": "USD",
  "user_id": "test_suspicious",
  "merchant_id": "temp_merchant"
}
```

#### Idempotency Testing
```bash
# Add Idempotency-Key header
curl -X POST https://your-api-gateway-url.execute-api.region.amazonaws.com/stage/payments \
  -H "X-API-Key: your_admin_api_key_here" \
  -H "Idempotency-Key: unique-key-123" \
  -H "Content-Type: application/json" \
  -d '{"amount": 50.00, "currency": "USD", "user_id": "user1", "merchant_id": "shop1"}'
```

### Error Handling Examples

#### 400 - Invalid Request
```bash
# Missing required field
curl -X POST https://your-api-gateway-url.execute-api.region.amazonaws.com/stage/payments \
  -H "X-API-Key: your_admin_api_key_here" \
  -H "Content-Type: application/json" \
  -d '{"amount": 25.50, "currency": "USD"}'
```

Response:
```json
{
  "error": "Missing required field: user_id"
}
```

#### 401 - Unauthorized
```bash
# Invalid API key
curl -X POST https://your-api-gateway-url.execute-api.region.amazonaws.com/stage/payments \
  -H "X-API-Key: invalid-key" \
  -H "Content-Type: application/json" \
  -d '{"amount": 25.50, "currency": "USD", "user_id": "user1", "merchant_id": "shop1"}'
```

#### 404 - Transaction Not Found
```bash
curl -X GET https://your-api-gateway-url.execute-api.region.amazonaws.com/stage/payments/nonexistent-id \
  -H "X-API-Key: your_admin_api_key_here"
```

---

## Monitoring

### CloudWatch Dashboards

The system includes monitoring for:
- API Gateway: Request count, latency, error rates
- Lambda: Duration, memory usage, error rates
- DynamoDB: Read/write capacity, throttling
- Custom Metrics: Fraud scores, payment success rates

### Key Metrics

- API Response Time: < 200ms (95th percentile)
- Error Rate: < 0.1%
- Fraud Detection: Risk-based scoring system

### Logging
All components use structured JSON logging:
```json
{
  "timestamp": "2025-08-27T00:00:00Z",
  "component": "PaymentProcessor", 
  "level": "INFO",
  "message": "Payment processed successfully",
  "transaction_id": "abc123",
  "amount": "25.50",
  "fraud_score": 15
}
```

---

## Infrastructure

### AWS Services

| Service | Purpose | Configuration |
|---------|---------|---------------|
| API Gateway | REST API hosting | Custom authorizer, rate limiting, CORS |
| Lambda | Serverless compute | Python 3.9+, 128MB-512MB memory |
| DynamoDB | Transaction storage | On-demand billing, TTL enabled |
| CloudWatch | Monitoring & logging | 14-day log retention |
| IAM | Access management | Least-privilege principle |

### Cost & Scalability

- Serverless pay-per-use pricing
- On-demand DynamoDB capacity
- Lambda auto-scales with demand
- Multi-AZ high availability

---

## Project Structure

```
src/
├── lambdas/                    # AWS Lambda Functions
│   ├── authorizer/             # Custom API authorizer
│   ├── process_payment/        # Payment processing logic
│   ├── get_transaction/        # Transaction retrieval
│   ├── list_transactions/      # Transaction history
│   └── process_refund/         # Refund processing
├── common/                     # Shared utilities
│   └── utils.py               # Common functions
└── auth/                      # Legacy auth components

infrastructure/
└── terraform/                 # Infrastructure as Code
    ├── modules/               # Reusable Terraform modules
    └── envs/demo/            # Demo environment config

docs/                          # Documentation
tests/                         # Unit and integration tests
```

---

## Development & Deployment

### Local Development
```bash
# Install dependencies
pip install -r src/lambdas/requirements.txt

# Run tests
python -m pytest tests/

# Deploy infrastructure
cd infrastructure/terraform/envs/demo
terraform init
terraform plan
terraform apply
```

### CI/CD

- Infrastructure: Terraform for IaC
- Application: AWS CLI for Lambda deployments
- Testing: pytest with coverage
- Monitoring: Health checks post-deployment

---

## Fraud Detection

### Risk Scoring Algorithm
```python
# Example risk factors and scores
High Amount (>$1000): +30 points
Very High Amount (>$5000): +50 points  
Round Dollar Amounts: +15 points
Test/Demo User IDs: +25 points
Suspicious Patterns: +20 points

# Decision Matrix
Score 0-49: APPROVE (Low Risk)
Score 50-79: REVIEW (Medium Risk)  
Score 80+: DECLINE (High Risk)
```

### Implementation Notes

- Risk assessment runs in real-time during payment processing
- Rules are configurable via the fraud detection module
- All decisions are logged for audit purposes

## Additional Documentation

- [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) - Detailed project structure
- [SECURITY.md](SECURITY.md) - Security policies and best practices
- `/docs` - Additional architecture documentation
