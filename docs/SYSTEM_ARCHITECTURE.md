# 🏗️ System Architecture Documentation

Comprehensive technical architecture documentation for the Real-Time Payment Processing System.

## 📊 **High-Level Architecture**

```
                                    ┌─────────────────┐
                                    │      Client     │
                                    │  Applications   │
                                    └─────────┬───────┘
                                              │
                                    ┌─────────▼───────┐
                                    │   API Gateway   │
                                    │                 │
                                    │ ┌─────────────┐ │
                                    │ │   Custom    │ │
                                    │ │ Authorizer  │ │
                                    │ └─────────────┘ │
                                    │                 │
                                    │ ┌─────────────┐ │
                                    │ │   Input     │ │
                                    │ │ Validation  │ │
                                    │ └─────────────┘ │
                                    └─────────┬───────┘
                                              │
                            ┌─────────────────┼─────────────────┐
                            │                 │                 │
                   ┌────────▼────────┐ ┌─────▼─────┐ ┌────────▼────────┐
                   │   Payment       │ │Transaction│ │    Refund       │
                   │  Processing     │ │ Retrieval │ │  Processing     │
                   │    Lambda       │ │  Lambda   │ │    Lambda       │
                   └────────┬────────┘ └─────┬─────┘ └────────┬────────┘
                            │                │                │
                            └─────────────────┼─────────────────┘
                                              │
                                    ┌─────────▼───────┐
                                    │   DynamoDB      │
                                    │                 │
                                    │ ┌─────────────┐ │
                                    │ │Transaction  │ │
                                    │ │   Table     │ │
                                    │ └─────────────┘ │
                                    │                 │
                                    │ ┌─────────────┐ │
                                    │ │Idempotency  │ │
                                    │ │   Table     │ │
                                    │ └─────────────┘ │
                                    └─────────────────┘
```

## 🔧 **Component Details**

### **1. API Gateway (Entry Point)**
```
┌─────────────────────────────────────────────────────────────┐
│                    AWS API Gateway                          │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Rate Limiting │  │ Request/Response│  │    CORS     │ │
│  │  100-1000/min   │  │    Logging      │  │   Headers   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │Custom Authorizer│  │ Input Validation│  │  Method     │ │
│  │  API Key Auth   │  │ JSON Schema     │  │Integration  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                                                             │
│  Endpoints:                                                 │
│  • POST   /payments              Create payment            │
│  • GET    /payments              List transactions         │
│  • GET    /payments/{id}         Get transaction           │
│  • POST   /payments/{id}/refund  Process refund            │
└─────────────────────────────────────────────────────────────┘
```

### **2. Authentication & Authorization Flow**
```
┌─────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Client    │    │   API Gateway    │    │   Authorizer    │
│             │    │                  │    │     Lambda      │
└─────┬───────┘    └─────────┬────────┘    └─────────┬───────┘
      │                      │                       │
      │ 1. Request with      │                       │
      │    X-API-Key         │                       │
      ├─────────────────────►│                       │
      │                      │                       │
      │                      │ 2. Extract API Key    │
      │                      │    & Invoke Authorizer│
      │                      ├──────────────────────►│
      │                      │                       │
      │                      │                       │ 3. Validate Key
      │                      │                       │    & Check Permissions
      │                      │                       │
      │                      │ 4. Return IAM Policy  │
      │                      │◄──────────────────────┤
      │                      │                       │
      │ 5. Allow/Deny        │                       │
      │    Request           │                       │
      │◄─────────────────────┤                       │
      │                      │                       │
```

### **3. Lambda Functions Architecture**
```
                    ┌─────────────────────────────────┐
                    │         Lambda Layer            │
                    │                                 │
┌─────────────────┐ │  ┌─────────────────────────────┐ │
│   Authorizer    │ │  │     Business Logic          │ │
│                 │ │  │                             │ │
│ • API Key       │ │  │ ┌─────────────────────────┐ │ │
│   Validation    │ │  │ │   Payment Processor     │ │ │
│ • Permission    │ │  │ │                         │ │ │
│   Checking      │ │  │ │ • Input Validation      │ │ │
│ • IAM Policy    │ │  │ │ • Fraud Detection       │ │ │
│   Generation    │ │  │ │ • Transaction Storage   │ │ │
│                 │ │  │ └─────────────────────────┘ │ │
└─────────────────┘ │  │                             │ │
                    │  │ ┌─────────────────────────┐ │ │
                    │  │ │  Transaction Manager    │ │ │
                    │  │ │                         │ │ │
                    │  │ │ • Single Transaction    │ │ │
                    │  │ │ • Transaction History   │ │ │
                    │  │ │ • Filtering & Pagination│ │ │
                    │  │ └─────────────────────────┘ │ │
                    │  │                             │ │
                    │  │ ┌─────────────────────────┐ │ │
                    │  │ │   Refund Processor      │ │ │
                    │  │ │                         │ │ │
                    │  │ │ • Refund Validation     │ │ │
                    │  │ │ • Partial/Full Refunds  │ │ │
                    │  │ │ • Audit Trail           │ │ │
                    │  │ └─────────────────────────┘ │ │
                    │  └─────────────────────────────┘ │
                    └─────────────────────────────────┘
```

### **4. Data Flow Architecture**
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Request   │    │ Validation  │    │   Business  │    │   Storage   │
│  Processing │    │ & Security  │    │    Logic    │    │ & Response  │
└─────┬───────┘    └─────┬───────┘    └─────┬───────┘    └─────┬───────┘
      │                  │                  │                  │
      ▼                  ▼                  ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│1. Client    │───►│2. API Key   │───►│3. Fraud     │───►│4. DynamoDB  │
│   Request   │    │   Auth      │    │   Detection │    │   Storage   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
      │                  │                  │                  │
      │            ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
      │            │   Input     │    │ Transaction │    │ Idempotency │
      │            │ Validation  │    │ Processing  │    │   Check     │
      │            └─────────────┘    └─────────────┘    └─────────────┘
      │                                                           │
      │                                                           ▼
      │                                                   ┌─────────────┐
      └───────────────────────────────────────────────────│5. Response  │
                                                          │   to Client │
                                                          └─────────────┘
```

## 🛡️ **Security Architecture**

### **Multi-Layer Security Model**
```
┌─────────────────────────────────────────────────────────────┐
│                   Security Layers                          │
│                                                             │
│  Layer 1: API Gateway Security                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • Rate Limiting (100-1000 requests/minute)         │   │
│  │ • HTTPS/TLS 1.2+ Encryption                        │   │
│  │ • CORS Headers                                      │   │
│  │ • Request Size Limits                               │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Layer 2: Custom Authorization                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • API Key Validation (SHA256 hashing)              │   │
│  │ • Role-Based Access Control                         │   │
│  │ • Permission Matrix Enforcement                     │   │
│  │ • Request Context Logging                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Layer 3: Input Validation                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • JSON Schema Validation                            │   │
│  │ • Business Rule Enforcement                         │   │
│  │ • SQL Injection Prevention                          │   │
│  │ • XSS Protection                                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Layer 4: Application Security                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • Data Encryption at Rest                           │   │
│  │ • Sensitive Data Masking in Logs                    │   │
│  │ • Audit Trail for All Operations                    │   │
│  │ • Error Handling (No Info Disclosure)               │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### **API Key Permission Matrix**
```
┌─────────────────────────────────────────────────────────────┐
│                 Permission Matrix                           │
├─────────────┬─────────────┬─────────────┬─────────────────┤
│ Permission  │    Admin    │  Merchant   │   Analytics     │
├─────────────┼─────────────┼─────────────┼─────────────────┤
│ Create      │      ✅     │      ✅     │       ❌        │
│ Payment     │             │             │                 │
├─────────────┼─────────────┼─────────────┼─────────────────┤
│ Read        │      ✅     │      ✅     │       ✅        │
│ Transaction │             │             │                 │
├─────────────┼─────────────┼─────────────┼─────────────────┤
│ List        │      ✅     │      ✅     │       ✅        │
│ Transactions│             │             │                 │
├─────────────┼─────────────┼─────────────┼─────────────────┤
│ Process     │      ✅     │      ❌     │       ❌        │
│ Refund      │             │             │                 │
├─────────────┼─────────────┼─────────────┼─────────────────┤
│ Rate Limit  │ 1000/min    │ 100/min     │   500/min       │
└─────────────┴─────────────┴─────────────┴─────────────────┘
```

## 🗄️ **Database Architecture**

### **DynamoDB Tables Structure**
```
┌─────────────────────────────────────────────────────────────┐
│                    Transactions Table                      │
├─────────────────────────────────────────────────────────────┤
│ Primary Key: transaction_id (String)                        │
│                                                             │
│ Attributes:                                                 │
│ • user_id (String) - Customer identifier                   │
│ • merchant_id (String) - Merchant identifier               │
│ • amount (String) - Transaction amount (decimal as string) │
│ • currency (String) - Currency code (USD, EUR, GBP)        │
│ • status (String) - completed|declined|pending_review      │
│ • timestamp (Number) - Unix timestamp in milliseconds      │
│ • created_at (String) - ISO datetime string                │
│ • fraud_check (Map) - Fraud detection results              │
│   ├─ fraud_score (Number)                                  │
│   ├─ risk_level (String)                                   │
│   ├─ decision (String)                                     │
│   └─ risk_factors (List)                                   │
│ • refund_info (Map) - Refund tracking                      │
│   ├─ total_refunded (String)                               │
│   ├─ refund_count (Number)                                 │
│   ├─ last_refund_at (Number)                               │
│   └─ refunds (List of Maps)                                │
│     ├─ refund_id (String)                                  │
│     ├─ amount (String)                                     │
│     ├─ timestamp (Number)                                  │
│     ├─ reason (String)                                     │
│     └─ processed_at (String)                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Idempotency Table                        │
├─────────────────────────────────────────────────────────────┤
│ Primary Key: idempotency_key (String)                       │
│ TTL: ttl (Number) - Expires after 24 hours                 │
│                                                             │
│ Attributes:                                                 │
│ • transaction_id (String) - Link to transaction            │
│ • response_data (Map) - Cached response                    │
│ • created_at (Number) - Creation timestamp                 │
└─────────────────────────────────────────────────────────────┘
```

## 📈 **Scalability & Performance**

### **Auto-Scaling Architecture**
```
                              Load Increases
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────┐
│                 Auto-Scaling Components                    │
│                                                             │
│  API Gateway                                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • 10,000+ requests/second capacity                  │   │
│  │ • Automatic throttling                              │   │
│  │ • Built-in DDoS protection                          │   │
│  └─────────────────────────────────────────────────────┘   │
│                              │                             │
│                              ▼                             │
│  Lambda Functions                                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • Automatic horizontal scaling                      │   │
│  │ • 1000+ concurrent executions                       │   │
│  │ • Cold start optimization                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                              │                             │
│                              ▼                             │
│  DynamoDB                                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • On-demand capacity scaling                        │   │
│  │ • Automatic read/write scaling                      │   │
│  │ • Built-in high availability                        │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### **Performance Optimization**
```
┌─────────────────────────────────────────────────────────────┐
│                Performance Optimizations                   │
│                                                             │
│  Lambda Optimizations:                                      │
│  • Memory: 128MB-512MB (right-sized per function)          │
│  • Timeout: 30 seconds maximum                             │
│  • Runtime: Python 3.9+ (optimized startup)               │
│  • Connection pooling for DynamoDB                         │
│                                                             │
│  DynamoDB Optimizations:                                    │
│  • On-demand billing (no pre-provisioned capacity)         │
│  • Efficient key design for single-table queries           │
│  • TTL for automatic cleanup (idempotency records)         │
│  • Consistent reads only when necessary                    │
│                                                             │
│  API Gateway Optimizations:                                 │
│  • Response caching for read operations                     │
│  • Request/response compression                             │
│  • Edge-optimized distribution                              │
│  • Minimal response payload size                            │
└─────────────────────────────────────────────────────────────┘
```

## 📊 **Monitoring & Observability**

### **CloudWatch Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│                CloudWatch Integration                       │
│                                                             │
│  Logs                                                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • Structured JSON logging                           │   │
│  │ • Component-based log groups                        │   │
│  │ • 14-day retention for cost control                 │   │
│  │ • Error aggregation and alerting                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Metrics                                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • API Gateway: Request count, latency, errors       │   │
│  │ • Lambda: Duration, memory usage, error rate        │   │
│  │ • DynamoDB: Read/write capacity, throttling         │   │
│  │ • Custom: Fraud scores, payment success rates       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Alarms                                                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • Error rate > 1%                                   │   │
│  │ • Response time > 1000ms                            │   │
│  │ • Lambda function failures                          │   │
│  │ • DynamoDB throttling events                        │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 **Fraud Detection Architecture**

### **Risk Scoring Engine**
```
┌─────────────────────────────────────────────────────────────┐
│               Fraud Detection Pipeline                     │
│                                                             │
│  Input: Transaction Data                                    │
│              │                                              │
│              ▼                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │            Rule-Based Scoring                       │   │
│  │                                                     │   │
│  │  • Amount Thresholds                                │   │
│  │    - High (>$1000): +30 points                     │   │
│  │    - Very High (>$5000): +50 points                │   │
│  │                                                     │   │
│  │  • Pattern Detection                                │   │
│  │    - Round amounts: +15 points                     │   │
│  │    - Test user IDs: +25 points                     │   │
│  │    - Suspicious patterns: +20 points               │   │
│  └─────────────────────────────────────────────────────┘   │
│              │                                              │
│              ▼                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           Decision Matrix                            │   │
│  │                                                     │   │
│  │  Score 0-49:    APPROVE (Low Risk)                 │   │
│  │  Score 50-79:   REVIEW (Medium Risk)               │   │
│  │  Score 80+:     DECLINE (High Risk)                │   │
│  └─────────────────────────────────────────────────────┘   │
│              │                                              │
│              ▼                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │            Audit & Logging                          │   │
│  │                                                     │   │
│  │  • Decision reasoning                               │   │
│  │  • Risk factors identified                          │   │
│  │  • Score calculation details                        │   │
│  │  • Timestamp and transaction context               │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 **Deployment Architecture**

### **Infrastructure as Code**
```
┌─────────────────────────────────────────────────────────────┐
│                 Deployment Pipeline                        │
│                                                             │
│  Development                                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • Local development environment                     │   │
│  │ • Unit testing with mocked AWS services            │   │
│  │ • Code quality checks and linting                  │   │
│  └─────────────────────────────────────────────────────┘   │
│              │                                              │
│              ▼                                              │
│  Terraform Infrastructure                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • Modular Terraform configuration                   │   │
│  │ • Environment-specific variables                    │   │
│  │ • State management and version control              │   │
│  └─────────────────────────────────────────────────────┘   │
│              │                                              │
│              ▼                                              │
│  AWS Deployment                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • Lambda function deployment                        │   │
│  │ • API Gateway configuration                         │   │
│  │ • DynamoDB table creation                           │   │
│  │ • IAM role and policy setup                         │   │
│  │ • CloudWatch log group creation                     │   │
│  └─────────────────────────────────────────────────────┘   │
│              │                                              │
│              ▼                                              │
│  Testing & Validation                                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • API endpoint testing                              │   │
│  │ • Integration test suite                            │   │
│  │ • Performance benchmarking                          │   │
│  │ • Security scan validation                          │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 💰 **Cost Architecture**

### **Cost Optimization Strategy**
```
┌─────────────────────────────────────────────────────────────┐
│                  Cost Breakdown                            │
│                                                             │
│  API Gateway                                                │
│  • $3.50 per million API calls                             │
│  • Free tier: 1 million calls/month                        │
│  • Demo usage: ~$5-10/month                                │
│                                                             │
│  Lambda Functions                                           │
│  • $0.20 per 1M requests                                   │
│  • $0.0000166667 per GB-second                             │
│  • Free tier: 1M requests + 400,000 GB-seconds            │
│  • Demo usage: ~$2-5/month                                 │
│                                                             │
│  DynamoDB                                                   │
│  • On-demand: $1.25 per million write requests             │
│  • On-demand: $0.25 per million read requests              │
│  • Storage: $0.25 per GB-month                             │
│  • Demo usage: ~$1-3/month                                 │
│                                                             │
│  CloudWatch Logs                                            │
│  • $0.50 per GB ingested                                   │
│  • $0.03 per GB-month stored                               │
│  • 14-day retention for cost control                       │
│  • Demo usage: ~$1-2/month                                 │
│                                                             │
│  Total Monthly Cost: ~$10-20 for demo usage               │
│  Cost per transaction: ~$0.001 (1/10th of a cent)         │
└─────────────────────────────────────────────────────────────┘
```

---

This architecture documentation demonstrates enterprise-grade system design with proper separation of concerns, scalability considerations, security best practices, and cost optimization strategies suitable for production fintech applications.