# 🧪 API Testing Guide

Complete guide for testing the Real-Time Payment Processing System API using Postman or other HTTP clients.

## 📋 Quick Start

### **1. Import Postman Collection**
1. Open Postman
2. Click "Import" button
3. Select `docs/Payment_System_API.postman_collection.json`
4. Import the environment: `docs/Payment_System_Environment.postman_environment.json`
5. Select "Payment System - Demo Environment" from environment dropdown

### **2. Run Collection**
- Click "Run Collection" to execute all tests automatically
- Or run individual requests to explore specific functionality

---

## 🔐 **Authentication**

All API endpoints require the `X-API-Key` header:

```bash
X-API-Key: your_admin_api_key_here
```

### **Available API Keys:**

| Key Type | API Key | Permissions | Rate Limit |
|----------|---------|-------------|------------|
| **Admin** | `your_admin_api_key_here` | Full access | 1000/min |
| **Merchant** | `your_merchant_api_key_here` | Create + Read | 100/min |
| **Analytics** | `your_analytics_api_key_here` | Read only | 500/min |

---

## 🚀 **Test Scenarios**

### **Scenario 1: Successful Payment Flow**

**Step 1 - Create Payment:**
```bash
POST /payments
{
  "amount": 125.50,
  "currency": "USD",
  "user_id": "demo_user_001",
  "merchant_id": "demo_merchant_store"
}
```

**Expected Response:**
```json
{
  "transaction_id": "uuid-here",
  "status": "completed",
  "amount": "125.50",
  "currency": "USD",
  "timestamp": 1693478400000,
  "message": "Payment processed successfully",
  "fraud_check": {
    "risk_level": "LOW",
    "fraud_score": 15
  }
}
```

**Step 2 - Retrieve Transaction:**
```bash
GET /payments/{transaction_id}
```

**Step 3 - Process Refund:**
```bash
POST /payments/{transaction_id}/refund
{
  "amount": 125.50,
  "reason": "Customer requested refund"
}
```

### **Scenario 2: Fraud Detection Demo**

**High-Risk Payment (Review Required):**
```bash
POST /payments
{
  "amount": 5000.00,
  "currency": "USD",
  "user_id": "demo_user_002",
  "merchant_id": "electronics_store"
}
```

**Expected Response:**
```json
{
  "transaction_id": "uuid-here",
  "status": "pending_review",
  "amount": "5000.00",
  "message": "Payment requires manual review"
}
```

**Very High-Risk Payment (Declined):**
```bash
POST /payments
{
  "amount": 10000.00,
  "currency": "USD",
  "user_id": "test_suspicious_user",
  "merchant_id": "temp_merchant_test"
}
```

**Expected Response (402):**
```json
{
  "transaction_id": "uuid-here",
  "status": "declined",
  "message": "Payment declined due to risk assessment"
}
```

### **Scenario 3: Idempotency Testing**

**Duplicate Prevention:**
```bash
POST /payments
Headers: 
  X-API-Key: your-key
  Idempotency-Key: unique-key-123
  
{
  "amount": 50.00,
  "currency": "USD",
  "user_id": "demo_user_003",
  "merchant_id": "coffee_shop"
}
```

**Run the same request twice** - second request should return identical response without creating duplicate transaction.

### **Scenario 4: Transaction History**

**List All Transactions:**
```bash
GET /payments?limit=10
```

**Filter by User:**
```bash
GET /payments?user_id=demo_user_001&limit=5
```

**Filter by Status and Merchant:**
```bash
GET /payments?status=completed&merchant_id=demo_merchant_store&limit=5
```

### **Scenario 5: Refund Processing**

**Full Refund:**
```bash
POST /payments/{transaction_id}/refund
{
  "amount": 125.50,
  "reason": "Customer requested full refund - defective product"
}
```

**Partial Refund:**
```bash
POST /payments/{transaction_id}/refund
{
  "amount": 25.00,
  "reason": "Partial refund - shipping damage to one item"
}
```

---

## ❌ **Error Testing**

### **Authentication Errors**

**Missing API Key (401):**
```bash
POST /payments
# No X-API-Key header
{
  "amount": 100.00,
  "currency": "USD",
  "user_id": "test_user",
  "merchant_id": "test_merchant"
}
```

**Invalid API Key (401):**
```bash
POST /payments
Headers: X-API-Key: invalid-key-12345
{
  "amount": 100.00,
  "currency": "USD",
  "user_id": "test_user",
  "merchant_id": "test_merchant"
}
```

### **Validation Errors**

**Missing Required Field (400):**
```bash
POST /payments
{
  "amount": 100.00,
  "currency": "USD"
  // Missing user_id and merchant_id
}
```

**Invalid Amount (400):**
```bash
POST /payments
{
  "amount": -50.00,  // Negative amount
  "currency": "USD",
  "user_id": "test_user",
  "merchant_id": "test_merchant"
}
```

**Invalid Currency (400):**
```bash
POST /payments
{
  "amount": 100.00,
  "currency": "INVALID",
  "user_id": "test_user",
  "merchant_id": "test_merchant"
}
```

### **Resource Errors**

**Transaction Not Found (404):**
```bash
GET /payments/nonexistent-transaction-id
```

**Refund Invalid Transaction (404):**
```bash
POST /payments/invalid-transaction-id/refund
{
  "amount": 50.00,
  "reason": "Test refund"
}
```

---

## 🔬 **Advanced Testing**

### **Performance Testing**
Use tools like Apache Bench or wrk for load testing:

```bash
# Test 100 concurrent requests
ab -n 1000 -c 100 -H "X-API-Key: your-key" -H "Content-Type: application/json" -p payment.json https://api-url/payments
```

### **Security Testing**
- Test rate limiting by sending rapid requests
- Verify API key validation with various invalid keys
- Test SQL injection attempts in request parameters
- Verify data masking in error responses

### **Business Logic Testing**
- Test maximum amount limits
- Verify currency validation
- Test refund amount validation (exceed original amount)
- Test duplicate idempotency keys
- Verify fraud detection rules with various amounts

---

## 📊 **Expected Performance Metrics**

| Metric | Target | Notes |
|--------|---------|-------|
| **Response Time** | < 200ms | 95th percentile |
| **Throughput** | 1000+ TPS | Under normal load |
| **Availability** | > 99.9% | Including AWS dependencies |
| **Error Rate** | < 0.1% | Excluding client errors (4xx) |

---

## 🐛 **Troubleshooting**

### **Common Issues**

**"Unauthorized" Response:**
- Verify X-API-Key header is present and correct
- Check API key permissions for the endpoint being called
- Ensure API key format is correct (starts with pk_demo_)

**"Invalid request body" Error:**
- Verify all required fields are present: amount, currency, user_id, merchant_id
- Check JSON formatting is valid
- Ensure amount is a positive number
- Verify currency is one of: USD, EUR, GBP

**Slow Response Times:**
- Check AWS region (API is in us-east-1)
- Verify network connectivity
- Consider Lambda cold start delays for first requests

**Transaction Not Found:**
- Verify transaction_id is correctly formatted UUID
- Check that transaction was actually created successfully
- Ensure using the correct API endpoint

### **Debug Information**

All responses include headers for debugging:
- `X-Payment-System: v1.0` - System version
- Response timing information in logs
- Structured error messages with specific validation failures

### **Log Analysis**

Check CloudWatch logs for detailed error information:
- API Gateway execution logs
- Lambda function logs with structured JSON
- Custom authorizer logs for authentication issues

---

## ✅ **Test Checklist**

Use this checklist to verify complete API functionality:

### **Payment Processing**
- [ ] Successful payment creation
- [ ] Fraud detection (low, medium, high risk)
- [ ] Input validation (required fields, data types)
- [ ] Idempotency handling
- [ ] Currency support (USD, EUR, GBP)

### **Transaction Management**
- [ ] Transaction retrieval by ID
- [ ] Transaction listing with pagination
- [ ] Filtering by user_id, merchant_id, status
- [ ] Proper error handling for not found

### **Refund Processing**
- [ ] Full refund processing
- [ ] Partial refund processing
- [ ] Refund validation (amount limits)
- [ ] Multiple refunds on same transaction
- [ ] Refund audit trail

### **Security & Error Handling**
- [ ] API key authentication
- [ ] Rate limiting enforcement
- [ ] Input validation and sanitization
- [ ] Proper HTTP status codes
- [ ] Structured error messages
- [ ] No sensitive data in logs

### **Performance**
- [ ] Response times under 200ms
- [ ] Concurrent request handling
- [ ] Proper scaling under load
- [ ] Error recovery and retries

---

**This testing guide ensures comprehensive verification of all system capabilities and proper error handling for a production-ready payment processing system.**