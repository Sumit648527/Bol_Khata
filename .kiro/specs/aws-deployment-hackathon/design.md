# Technical Design Document: AWS Deployment for Hackathon Submission

## 1. Introduction

This document provides the comprehensive technical design for deploying the Bol Khata voice banking application to AWS infrastructure. The design ensures zero-error, zero-throttling, production-ready deployment while maintaining cost efficiency within the $150 AWS credit budget.

### 1.1 Design Goals

- Zero cold starts through provisioned concurrency
- Zero throttling through proper rate limits and queuing
- Zero user-visible errors through comprehensive retry and fallback mechanisms
- Sub-2-second API response times
- Sub-8-second voice processing times
- 99.9% uptime guarantee
- $10-15/month operational cost

### 1.2 Design Principles

1. **Resilience First**: Every component has retry logic, fallback mechanisms, and graceful degradation
2. **Performance Optimized**: Provisioned concurrency, connection pooling, caching at every layer
3. **Cost Conscious**: Maximize free tier usage while maintaining performance
4. **Security by Default**: Encryption, least privilege, secrets management
5. **Observable**: Comprehensive logging, metrics, and alarms

## 2. High-Level Architecture

### 2.1 System Overview

The deployment follows a serverless-first architecture with managed services:

```
User Browser/Mobile
        ↓
    AWS Amplify (Frontend CDN)
        ↓
    API Gateway (REST API + Caching)
        ↓
    AWS Lambda (Compute Layer)
        ↓
    ├─→ Amazon RDS PostgreSQL (Data Layer)
    ├─→ Amazon S3 (Storage Layer)
    ├─→ Amazon Bedrock (AI Layer)
    └─→ AWS Secrets Manager (Security Layer)
        ↓
    CloudWatch (Monitoring Layer)
```

### 2.2 Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      PUBLIC INTERNET                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    AWS CLOUD (us-east-1)                     │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              PUBLIC SUBNET (AZ-1a)                     │ │
│  │                                                         │ │
│  │  ┌──────────────┐         ┌──────────────┐           │ │
│  │  │ API Gateway  │         │  AWS Amplify │           │ │
│  │  │  (REST API)  │         │   (Frontend) │           │ │
│  │  └──────┬───────┘         └──────────────┘           │ │
│  │         │                                              │ │
│  └─────────┼──────────────────────────────────────────────┘ │
│            │                                                 │
│  ┌─────────▼──────────────────────────────────────────────┐ │
│  │           PRIVATE SUBNET (AZ-1a, AZ-1b)                │ │
│  │                                                         │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │ │
│  │  │   Lambda     │  │   Lambda     │  │   Lambda    │ │ │
│  │  │  (Banking)   │  │   (Voice)    │  │   (Auth)    │ │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘ │ │
│  │         │                  │                  │        │ │
│  │         └──────────────────┼──────────────────┘        │ │
│  │                            │                           │ │
│  │  ┌─────────────────────────▼────────────────────────┐ │ │
│  │  │         RDS PostgreSQL (Multi-AZ)                │ │ │
│  │  │         Primary: AZ-1a, Standby: AZ-1b          │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  │                                                         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              AWS MANAGED SERVICES                        │ │
│  │                                                           │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐│ │
│  │  │    S3    │  │ Bedrock  │  │ Secrets  │  │CloudWatch││ │
│  │  │ (Audio)  │  │  (AI)    │  │ Manager  │  │ (Logs)  ││ │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────────┘│ │
│  └─────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

### 2.3 Data Flow Diagrams

#### 2.3.1 Voice Transaction Flow

```
User → Records Audio
  ↓
Frontend → Uploads to S3 via presigned URL
  ↓
S3 → Triggers Lambda (Voice Service)
  ↓
Lambda → Downloads audio from S3
  ↓
Lambda → Calls Sarvam AI (Speech-to-Text)
  ↓
Lambda → Checks if simple pattern (regex)
  ├─ YES → Extract with regex (90% of cases)
  └─ NO  → Call Amazon Bedrock for NLU (10% of cases)
  ↓
Lambda → Retry Bedrock 3x with exponential backoff if fails
  ↓
Lambda → If all retries fail, use enhanced regex fallback
  ↓
Lambda → Save transaction to RDS (with retry)
  ↓
Lambda → Return result to Frontend
  ↓
Frontend → Display transaction with confidence indicator
```


#### 2.3.2 Manual Transaction Flow

```
User → Fills form (customer, amount, type)
  ↓
Frontend → Validates input locally
  ↓
Frontend → Sends POST to API Gateway
  ↓
API Gateway → Validates JWT token
  ↓
API Gateway → Routes to Transaction Lambda
  ↓
Lambda → Validates request payload
  ↓
Lambda → Gets DB connection from pool (with retry)
  ↓
Lambda → Inserts transaction (with retry 3x)
  ↓
Lambda → Returns success response
  ↓
API Gateway → Caches response (if GET)
  ↓
Frontend → Updates UI optimistically
```

#### 2.3.3 Passbook PDF Generation Flow

```
User → Selects date range + clicks "Download PDF"
  ↓
Frontend → Calls API Gateway /api/passbook/generate
  ↓
API Gateway → Routes to Banking Lambda
  ↓
Lambda → Queries transactions from RDS (indexed query)
  ↓
Lambda → Calculates aggregates (income, credit, outstanding)
  ↓
Lambda → Generates PDF using library
  ↓
Lambda → Uploads PDF to S3 with 1-hour expiry
  ↓
Lambda → Returns presigned URL
  ↓
Frontend → Downloads PDF from S3
```

## 3. Component Specifications

### 3.1 Frontend Layer (AWS Amplify)

#### 3.1.1 Configuration

```yaml
Service: AWS Amplify
Deployment Type: Manual (no Git integration)
Region: us-east-1
Build Settings:
  baseDirectory: /
  files:
    - '**/*'
Environment Variables:
  API_BASE_URL: ${API_GATEWAY_URL}
  VOICE_API_URL: ${API_GATEWAY_URL}/voice
Features:
  - HTTPS (automatic SSL)
  - CDN (CloudFront distribution)
  - Gzip compression
  - Custom headers (CORS, security)
Performance:
  - Service Worker for offline capability
  - Asset caching (1 year for static assets)
  - Lazy loading for images
  - Code splitting for JS bundles
```

#### 3.1.2 File Structure

```
web-ui/
├── app-final.html          # Main application
├── login-pro.html          # Login page
├── register-enhanced.html  # Registration page
├── styles-pro.css          # Styles
├── app-final.js            # Application logic
└── service-worker.js       # NEW: Offline support
```

#### 3.1.3 Service Worker Implementation

```javascript
// service-worker.js - NEW FILE
const CACHE_NAME = 'bolkhata-v1';
const urlsToCache = [
  '/app-final.html',
  '/login-pro.html',
  '/styles-pro.css',
  '/app-final.js'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(urlsToCache))
  );
});

self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => response || fetch(event.request))
  );
});
```

### 3.2 API Gateway Layer

#### 3.2.1 REST API Configuration

```yaml
API Name: bolkhata-api
Protocol: REST
Endpoint Type: Regional
Region: us-east-1

Stages:
  - Name: prod
    Throttling:
      RateLimit: 10000  # requests per second
      BurstLimit: 5000  # concurrent requests
    Caching:
      Enabled: true
      TTL: 300  # 5 minutes
      CacheKeyParameters:
        - method.request.header.Authorization
    Logging:
      AccessLogging: true
      ExecutionLogging: true
      LogLevel: INFO

CORS Configuration:
  AllowOrigins: 
    - https://*.amplifyapp.com
  AllowMethods:
    - GET
    - POST
    - PUT
    - DELETE
    - OPTIONS
  AllowHeaders:
    - Content-Type
    - Authorization
    - X-Requested-With
  ExposeHeaders:
    - X-Request-Id
  MaxAge: 3600
  AllowCredentials: true
```

#### 3.2.2 API Routes

```yaml
Routes:
  # Authentication
  POST /api/auth/register:
    Integration: Lambda (auth-lambda)
    Authorization: None
    Caching: false
    Timeout: 15s
    
  POST /api/auth/login:
    Integration: Lambda (auth-lambda)
    Authorization: None
    Caching: false
    Timeout: 15s
    
  # Customers
  GET /api/customers:
    Integration: Lambda (customer-lambda)
    Authorization: JWT
    Caching: true (300s)
    Timeout: 15s
    
  POST /api/customers:
    Integration: Lambda (customer-lambda)
    Authorization: JWT
    Caching: false
    Timeout: 15s
    
  GET /api/customers/{id}:
    Integration: Lambda (customer-lambda)
    Authorization: JWT
    Caching: true (300s)
    Timeout: 15s
    
  PUT /api/customers/{id}:
    Integration: Lambda (customer-lambda)
    Authorization: JWT
    Caching: false
    Timeout: 15s
    
  # Transactions
  GET /api/transactions:
    Integration: Lambda (transaction-lambda)
    Authorization: JWT
    Caching: true (60s)
    Timeout: 15s
    
  POST /api/transactions:
    Integration: Lambda (transaction-lambda)
    Authorization: JWT
    Caching: false
    Timeout: 15s
    
  GET /api/transactions/{id}:
    Integration: Lambda (transaction-lambda)
    Authorization: JWT
    Caching: true (300s)
    Timeout: 15s
    
  # Statistics
  GET /api/statistics:
    Integration: Lambda (banking-lambda)
    Authorization: JWT
    Caching: true (300s)
    Timeout: 15s
    
  # Passbook
  POST /api/passbook/generate:
    Integration: Lambda (banking-lambda)
    Authorization: JWT
    Caching: false
    Timeout: 30s
    
  # Voice Processing
  POST /voice/process-voice:
    Integration: Lambda (voice-lambda)
    Authorization: JWT
    Caching: false
    Timeout: 30s
    PayloadSize: 10MB  # For audio uploads
    
  GET /voice/audio/{id}:
    Integration: Lambda (voice-lambda)
    Authorization: JWT
    Caching: true (3600s)
    Timeout: 15s
```

#### 3.2.3 Request Validation

```json
{
  "POST /api/transactions": {
    "body": {
      "type": "object",
      "required": ["customerId", "amount", "transactionType"],
      "properties": {
        "customerId": {"type": "integer", "minimum": 1},
        "amount": {"type": "number", "minimum": 0.01},
        "transactionType": {
          "type": "string",
          "enum": ["SALE_PAID", "SALE_CREDIT", "PAYMENT_RECEIVED"]
        },
        "description": {"type": "string", "maxLength": 500},
        "audioPath": {"type": "string", "maxLength": 255}
      }
    }
  }
}
```

#### 3.2.4 Error Response Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request payload",
    "details": [
      {
        "field": "amount",
        "issue": "must be greater than 0"
      }
    ],
    "requestId": "abc-123-def",
    "timestamp": "2026-03-06T10:30:00Z"
  }
}
```


### 3.3 Lambda Functions (Compute Layer)

#### 3.3.1 Banking Service Lambda

```yaml
Function Name: bolkhata-banking-service
Runtime: java17
Architecture: arm64  # 20% cost savings
Handler: com.bolkhata.StreamLambdaHandler
Memory: 1024MB  # Increased for zero OOM errors
Timeout: 15s
Provisioned Concurrency: 2  # Zero cold starts
Reserved Concurrency: 50  # Prevent throttling
Environment Variables:
  DB_HOST: ${RDS_ENDPOINT}
  DB_PORT: 5432
  DB_NAME: bol_khata
  DB_USER: ${SECRET:db-credentials:username}
  DB_PASSWORD: ${SECRET:db-credentials:password}
  DB_POOL_MIN: 5
  DB_POOL_MAX: 20
  JWT_SECRET: ${SECRET:jwt-secret:value}
  JWT_EXPIRATION: 86400
VPC Configuration:
  SubnetIds:
    - subnet-private-1a
    - subnet-private-1b
  SecurityGroupIds:
    - sg-lambda-to-rds
Layers:
  - AWS Lambda Web Adapter (for Spring Boot)
Dead Letter Queue:
  TargetArn: ${SQS_DLQ_ARN}
Retry Configuration:
  MaximumRetryAttempts: 2
  MaximumEventAge: 3600
```

#### 3.3.2 Voice Service Lambda

```yaml
Function Name: bolkhata-voice-service
Runtime: python3.11
Architecture: arm64
Handler: app.main.lambda_handler
Memory: 1024MB  # Increased for AI processing
Timeout: 30s
Provisioned Concurrency: 2  # Zero cold starts
Reserved Concurrency: 20  # Prevent throttling
Environment Variables:
  DB_HOST: ${RDS_ENDPOINT}
  DB_PORT: 5432
  DB_NAME: bol_khata
  DB_USER: ${SECRET:db-credentials:username}
  DB_PASSWORD: ${SECRET:db-credentials:password}
  SARVAM_API_KEY: ${SECRET:api-keys:sarvam}
  BEDROCK_REGION: us-east-1
  BEDROCK_MODEL_ID: anthropic.claude-3-haiku-20240307-v1:0
  S3_BUCKET: bolkhata-audio-files
  S3_REGION: us-east-1
  AI_RETRY_ATTEMPTS: 3
  AI_RETRY_DELAY: 1  # seconds
  AI_TIMEOUT: 5  # seconds
VPC Configuration:
  SubnetIds:
    - subnet-private-1a
    - subnet-private-1b
  SecurityGroupIds:
    - sg-lambda-to-rds
    - sg-lambda-to-internet  # For Sarvam AI API
IAM Role Permissions:
  - s3:GetObject
  - s3:PutObject
  - bedrock:InvokeModel
  - secretsmanager:GetSecretValue
  - logs:CreateLogGroup
  - logs:CreateLogStream
  - logs:PutLogEvents
Dead Letter Queue:
  TargetArn: ${SQS_DLQ_ARN}
```

#### 3.3.3 Auth Lambda

```yaml
Function Name: bolkhata-auth-service
Runtime: python3.11
Architecture: arm64
Handler: auth.handler
Memory: 512MB
Timeout: 10s
Provisioned Concurrency: 1
Reserved Concurrency: 20
Environment Variables:
  DB_HOST: ${RDS_ENDPOINT}
  DB_PORT: 5432
  DB_NAME: bol_khata
  DB_USER: ${SECRET:db-credentials:username}
  DB_PASSWORD: ${SECRET:db-credentials:password}
  JWT_SECRET: ${SECRET:jwt-secret:value}
  JWT_EXPIRATION: 86400
  BCRYPT_ROUNDS: 12
VPC Configuration:
  SubnetIds:
    - subnet-private-1a
    - subnet-private-1b
  SecurityGroupIds:
    - sg-lambda-to-rds
```

#### 3.3.4 Transaction Lambda

```yaml
Function Name: bolkhata-transaction-service
Runtime: python3.11
Architecture: arm64
Handler: transaction.handler
Memory: 512MB
Timeout: 15s
Provisioned Concurrency: 2
Reserved Concurrency: 30
Environment Variables:
  DB_HOST: ${RDS_ENDPOINT}
  DB_PORT: 5432
  DB_NAME: bol_khata
  DB_USER: ${SECRET:db-credentials:username}
  DB_PASSWORD: ${SECRET:db-credentials:password}
  DB_POOL_MIN: 5
  DB_POOL_MAX: 20
VPC Configuration:
  SubnetIds:
    - subnet-private-1a
    - subnet-private-1b
  SecurityGroupIds:
    - sg-lambda-to-rds
```

#### 3.3.5 Customer Lambda

```yaml
Function Name: bolkhata-customer-service
Runtime: python3.11
Architecture: arm64
Handler: customer.handler
Memory: 512MB
Timeout: 15s
Provisioned Concurrency: 1
Reserved Concurrency: 20
Environment Variables:
  DB_HOST: ${RDS_ENDPOINT}
  DB_PORT: 5432
  DB_NAME: bol_khata
  DB_USER: ${SECRET:db-credentials:username}
  DB_PASSWORD: ${SECRET:db-credentials:password}
  DB_POOL_MIN: 3
  DB_POOL_MAX: 15
VPC Configuration:
  SubnetIds:
    - subnet-private-1a
    - subnet-private-1b
  SecurityGroupIds:
    - sg-lambda-to-rds
```

#### 3.3.6 Lambda Retry Logic Pattern

```python
# Retry with exponential backoff pattern
import time
from functools import wraps

def retry_with_backoff(max_attempts=3, initial_delay=1, backoff_factor=2):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            delay = initial_delay
            last_exception = None
            
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    last_exception = e
                    if attempt < max_attempts - 1:
                        print(f"Attempt {attempt + 1} failed: {e}. Retrying in {delay}s...")
                        time.sleep(delay)
                        delay *= backoff_factor
                    else:
                        print(f"All {max_attempts} attempts failed")
            
            raise last_exception
        return wrapper
    return decorator

# Usage example
@retry_with_backoff(max_attempts=3, initial_delay=1, backoff_factor=2)
def call_bedrock(prompt):
    response = bedrock_client.invoke_model(
        modelId='anthropic.claude-3-haiku-20240307-v1:0',
        body=json.dumps({"prompt": prompt, "max_tokens": 500})
    )
    return response

@retry_with_backoff(max_attempts=3, initial_delay=0.5, backoff_factor=2)
def execute_db_query(query, params):
    with connection_pool.get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query, params)
        return cursor.fetchall()
```

#### 3.3.7 Connection Pooling Pattern

```python
# Database connection pooling
from psycopg2 import pool
import os

# Initialize connection pool (reused across Lambda invocations)
connection_pool = None

def get_connection_pool():
    global connection_pool
    if connection_pool is None:
        connection_pool = pool.ThreadedConnectionPool(
            minconn=int(os.environ.get('DB_POOL_MIN', 5)),
            maxconn=int(os.environ.get('DB_POOL_MAX', 20)),
            host=os.environ['DB_HOST'],
            port=int(os.environ.get('DB_PORT', 5432)),
            database=os.environ['DB_NAME'],
            user=os.environ['DB_USER'],
            password=os.environ['DB_PASSWORD'],
            connect_timeout=10,
            options='-c statement_timeout=5000'  # 5s query timeout
        )
    return connection_pool

def lambda_handler(event, context):
    pool = get_connection_pool()
    conn = pool.getconn()
    try:
        # Use connection
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM transactions")
        results = cursor.fetchall()
        return {"statusCode": 200, "body": json.dumps(results)}
    finally:
        pool.putconn(conn)  # Return connection to pool
```


### 3.4 Database Layer (Amazon RDS PostgreSQL)

#### 3.4.1 RDS Configuration

```yaml
Instance Identifier: bolkhata-db
Engine: postgres
Engine Version: 15.4
Instance Class: db.t3.micro
vCPUs: 2
Memory: 1 GiB
Storage:
  Type: gp2 (SSD)
  Allocated: 20 GB
  Max: 100 GB (auto-scaling enabled)
  IOPS: 100 (baseline)
Multi-AZ: true  # High availability
Backup:
  Automated: true
  Retention: 7 days
  Window: 03:00-04:00 UTC
  Copy to S3: true
Maintenance:
  Window: Sun:04:00-Sun:05:00 UTC
  Auto Minor Version Upgrade: true
Network:
  VPC: vpc-bolkhata
  Subnet Group: private-subnets
  Public Access: false
  Security Groups:
    - sg-rds-from-lambda
Parameter Group:
  max_connections: 100
  shared_buffers: 256MB
  effective_cache_size: 768MB
  maintenance_work_mem: 64MB
  checkpoint_completion_target: 0.9
  wal_buffers: 16MB
  default_statistics_target: 100
  random_page_cost: 1.1
  effective_io_concurrency: 200
  work_mem: 2621kB
  min_wal_size: 1GB
  max_wal_size: 4GB
Performance Insights:
  Enabled: true
  Retention: 7 days
Enhanced Monitoring:
  Enabled: true
  Interval: 60 seconds
Encryption:
  At Rest: true (AWS KMS)
  In Transit: true (SSL/TLS)
```

#### 3.4.2 Database Schema

```sql
-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    shop_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

-- Customers table
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    balance DECIMAL(10, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_customers_user_id ON customers(user_id);
CREATE INDEX idx_customers_name ON customers(name);
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_balance ON customers(balance);

-- Transactions table
CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('SALE_PAID', 'SALE_CREDIT', 'PAYMENT_RECEIVED')),
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    description TEXT,
    audio_path VARCHAR(255),
    confidence_score DECIMAL(3, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transactions_user_id ON transactions(user_id);
CREATE INDEX idx_transactions_customer_id ON transactions(customer_id);
CREATE INDEX idx_transactions_type ON transactions(transaction_type);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);
CREATE INDEX idx_transactions_user_created ON transactions(user_id, created_at DESC);
CREATE INDEX idx_transactions_customer_created ON transactions(customer_id, created_at DESC);

-- Trigger to update customer balance
CREATE OR REPLACE FUNCTION update_customer_balance()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.transaction_type = 'SALE_CREDIT' THEN
            UPDATE customers SET balance = balance + NEW.amount WHERE id = NEW.customer_id;
        ELSIF NEW.transaction_type = 'PAYMENT_RECEIVED' THEN
            UPDATE customers SET balance = balance - NEW.amount WHERE id = NEW.customer_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.transaction_type = 'SALE_CREDIT' THEN
            UPDATE customers SET balance = balance - OLD.amount WHERE id = OLD.customer_id;
        ELSIF OLD.transaction_type = 'PAYMENT_RECEIVED' THEN
            UPDATE customers SET balance = balance + OLD.amount WHERE id = OLD.customer_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_customer_balance
AFTER INSERT OR DELETE ON transactions
FOR EACH ROW EXECUTE FUNCTION update_customer_balance();

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_customers_updated_at BEFORE UPDATE ON customers
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_transactions_updated_at BEFORE UPDATE ON transactions
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### 3.4.3 Connection Management

```python
# Connection pool configuration
import psycopg2
from psycopg2 import pool
import os

class DatabaseManager:
    _instance = None
    _pool = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(DatabaseManager, cls).__new__(cls)
        return cls._instance
    
    def initialize_pool(self):
        if self._pool is None:
            self._pool = psycopg2.pool.ThreadedConnectionPool(
                minconn=5,
                maxconn=20,
                host=os.environ['DB_HOST'],
                port=int(os.environ.get('DB_PORT', 5432)),
                database=os.environ['DB_NAME'],
                user=os.environ['DB_USER'],
                password=os.environ['DB_PASSWORD'],
                connect_timeout=10,
                keepalives=1,
                keepalives_idle=30,
                keepalives_interval=10,
                keepalives_count=5
            )
    
    def get_connection(self):
        if self._pool is None:
            self.initialize_pool()
        return self._pool.getconn()
    
    def return_connection(self, conn):
        self._pool.putconn(conn)
    
    def close_all_connections(self):
        if self._pool is not None:
            self._pool.closeall()

# Usage in Lambda
db_manager = DatabaseManager()

def lambda_handler(event, context):
    conn = None
    try:
        conn = db_manager.get_connection()
        cursor = conn.cursor()
        
        # Execute query with retry
        for attempt in range(3):
            try:
                cursor.execute("SELECT * FROM transactions WHERE user_id = %s", (user_id,))
                results = cursor.fetchall()
                break
            except psycopg2.OperationalError as e:
                if attempt < 2:
                    time.sleep(2 ** attempt)  # Exponential backoff
                    conn = db_manager.get_connection()
                    cursor = conn.cursor()
                else:
                    raise
        
        return {"statusCode": 200, "body": json.dumps(results)}
    
    except Exception as e:
        print(f"Database error: {e}")
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
    
    finally:
        if conn:
            db_manager.return_connection(conn)
```

### 3.5 Storage Layer (Amazon S3)

#### 3.5.1 S3 Bucket Configuration

```yaml
Bucket Name: bolkhata-audio-files-${ACCOUNT_ID}
Region: us-east-1
Versioning: Enabled
Encryption:
  Type: AES-256 (SSE-S3)
  Default: true
Lifecycle Rules:
  - Name: compress-and-archive
    Status: Enabled
    Transitions:
      - Days: 30
        StorageClass: INTELLIGENT_TIERING
      - Days: 90
        StorageClass: GLACIER
    Expiration:
      Days: 365
Public Access Block:
  BlockPublicAcls: true
  IgnorePublicAcls: true
  BlockPublicPolicy: true
  RestrictPublicBuckets: true
CORS Configuration:
  - AllowedOrigins:
      - https://*.amplifyapp.com
    AllowedMethods:
      - GET
      - PUT
      - POST
    AllowedHeaders:
      - "*"
    ExposeHeaders:
      - ETag
    MaxAgeSeconds: 3600
Event Notifications:
  - Name: audio-processing-trigger
    Events:
      - s3:ObjectCreated:*
    Filter:
      Prefix: audio/
      Suffix: .wav
    Destination:
      Type: Lambda
      Arn: ${VOICE_LAMBDA_ARN}
```

#### 3.5.2 S3 Object Key Structure

```
bolkhata-audio-files/
├── audio/
│   ├── {user_id}/
│   │   ├── {year}/
│   │   │   ├── {month}/
│   │   │   │   ├── {timestamp}_{random_id}.mp3
│   │   │   │   └── {timestamp}_{random_id}.mp3
├── pdfs/
│   ├── {user_id}/
│   │   ├── passbook_{timestamp}.pdf
│   │   └── passbook_{timestamp}.pdf
└── backups/
    ├── {date}/
    │   └── database_backup.sql.gz
```

#### 3.5.3 Presigned URL Generation

```python
import boto3
from botocore.exceptions import ClientError
import os

s3_client = boto3.client('s3', region_name='us-east-1')

def generate_upload_url(user_id, file_extension='mp3'):
    """Generate presigned URL for audio upload"""
    timestamp = int(time.time() * 1000)
    random_id = secrets.token_hex(4)
    year = datetime.now().year
    month = datetime.now().strftime('%m')
    
    object_key = f"audio/{user_id}/{year}/{month}/{timestamp}_{random_id}.{file_extension}"
    
    try:
        url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': os.environ['S3_BUCKET'],
                'Key': object_key,
                'ContentType': f'audio/{file_extension}'
            },
            ExpiresIn=300  # 5 minutes
        )
        return {'url': url, 'key': object_key}
    except ClientError as e:
        print(f"Error generating presigned URL: {e}")
        raise

def generate_download_url(object_key, expires_in=3600):
    """Generate presigned URL for audio download"""
    try:
        url = s3_client.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': os.environ['S3_BUCKET'],
                'Key': object_key
            },
            ExpiresIn=expires_in  # 1 hour default
        )
        return url
    except ClientError as e:
        print(f"Error generating presigned URL: {e}")
        raise
```


### 3.6 AI Layer (Amazon Bedrock)

#### 3.6.1 Bedrock Configuration

```yaml
Model: anthropic.claude-3-haiku-20240307-v1:0
Region: us-east-1
Pricing:
  Input: $0.25 per 1M tokens
  Output: $1.25 per 1M tokens
Performance:
  Latency: ~1-2 seconds
  Max Tokens: 4096
  Context Window: 200K tokens
IAM Permissions:
  - bedrock:InvokeModel
  - bedrock:InvokeModelWithResponseStream
```

#### 3.6.2 NLU Prompt Engineering

```python
import boto3
import json
from typing import Dict, Optional

bedrock_runtime = boto3.client('bedrock-runtime', region_name='us-east-1')

def extract_transaction_with_bedrock(transcription: str, language: str = 'hindi') -> Dict:
    """
    Extract transaction details using Amazon Bedrock
    """
    prompt = f"""You are a financial transaction parser for Indian street vendors.

Extract transaction details from this {language} voice transcription:
"{transcription}"

Return ONLY a JSON object with these exact fields:
{{
  "customer_name": "extracted customer name",
  "amount": numeric_value,
  "transaction_type": "SALE_PAID" or "SALE_CREDIT" or "PAYMENT_RECEIVED",
  "confidence": 0.0 to 1.0,
  "reasoning": "brief explanation"
}}

Rules:
1. customer_name: Extract the person's name mentioned
2. amount: Extract numeric value (convert words to numbers if needed)
3. transaction_type:
   - SALE_PAID: Customer paid cash immediately (keywords: दिया, paid, cash, नकद)
   - SALE_CREDIT: Customer took on credit/udhaar (keywords: उधार, credit, बाकी, later)
   - PAYMENT_RECEIVED: Customer paid back old debt (keywords: वापस, returned, paid back, चुकाया)
4. confidence: Your confidence in extraction (0.0-1.0)
5. reasoning: Brief explanation of your decision

Examples:
- "राजू ने 50 रुपये उधार लिए" → {{"customer_name": "राजू", "amount": 50, "transaction_type": "SALE_CREDIT", "confidence": 0.95}}
- "सीता ने 100 रुपये दिए" → {{"customer_name": "सीता", "amount": 100, "transaction_type": "SALE_PAID", "confidence": 0.95}}
- "मोहन ने 200 रुपये वापस किए" → {{"customer_name": "मोहन", "amount": 200, "transaction_type": "PAYMENT_RECEIVED", "confidence": 0.95}}

Return ONLY the JSON, no other text."""

    try:
        response = bedrock_runtime.invoke_model(
            modelId='anthropic.claude-3-haiku-20240307-v1:0',
            contentType='application/json',
            accept='application/json',
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 500,
                "temperature": 0.1,  # Low temperature for consistent extraction
                "messages": [
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            })
        )
        
        response_body = json.loads(response['body'].read())
        content = response_body['content'][0]['text']
        
        # Extract JSON from response
        import re
        json_match = re.search(r'\{.*\}', content, re.DOTALL)
        if json_match:
            result = json.loads(json_match.group())
            return result
        else:
            raise ValueError("No JSON found in Bedrock response")
    
    except Exception as e:
        print(f"Bedrock extraction failed: {e}")
        raise

def smart_nlu_with_fallback(transcription: str, language: str = 'hindi') -> Dict:
    """
    Smart NLU with regex-first approach and Bedrock fallback
    """
    # Try simple regex patterns first (90% of cases)
    regex_result = extract_with_regex(transcription, language)
    
    if regex_result and regex_result.get('confidence', 0) > 0.8:
        print("Using regex extraction (fast path)")
        return regex_result
    
    # Use Bedrock for complex cases with retry
    print("Using Bedrock extraction (complex case)")
    for attempt in range(3):
        try:
            bedrock_result = extract_transaction_with_bedrock(transcription, language)
            return bedrock_result
        except Exception as e:
            if attempt < 2:
                print(f"Bedrock attempt {attempt + 1} failed: {e}. Retrying...")
                time.sleep(2 ** attempt)  # Exponential backoff
            else:
                print(f"All Bedrock attempts failed. Using enhanced regex fallback.")
                return enhanced_regex_fallback(transcription, language)

def extract_with_regex(transcription: str, language: str) -> Optional[Dict]:
    """
    Fast regex-based extraction for simple patterns
    """
    import re
    
    # Hindi patterns
    if language == 'hindi':
        # Pattern: {name} ने {amount} रुपये {action}
        patterns = [
            r'(\w+)\s+ने\s+(\d+)\s+रुपये?\s+(उधार|दिया|दिए|वापस)',
            r'(\w+)\s+को\s+(\d+)\s+रुपये?\s+(उधार|दिया|दिए)',
            r'(\w+)\s+से\s+(\d+)\s+रुपये?\s+(लिए|मिले)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, transcription)
            if match:
                name = match.group(1)
                amount = float(match.group(2))
                action = match.group(3)
                
                # Determine transaction type
                if action in ['उधार']:
                    tx_type = 'SALE_CREDIT'
                elif action in ['दिया', 'दिए']:
                    tx_type = 'SALE_PAID'
                elif action in ['वापस', 'लिए', 'मिले']:
                    tx_type = 'PAYMENT_RECEIVED'
                else:
                    continue
                
                return {
                    'customer_name': name,
                    'amount': amount,
                    'transaction_type': tx_type,
                    'confidence': 0.85,
                    'reasoning': 'Regex pattern match'
                }
    
    # English patterns
    elif language == 'english':
        patterns = [
            r'(\w+)\s+(?:paid|gave)\s+(?:rs\.?|rupees?)\s*(\d+)',
            r'(\w+)\s+took\s+(?:rs\.?|rupees?)\s*(\d+)\s+(?:on\s+)?credit',
            r'(\w+)\s+returned\s+(?:rs\.?|rupees?)\s*(\d+)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, transcription, re.IGNORECASE)
            if match:
                name = match.group(1)
                amount = float(match.group(2))
                
                if 'credit' in transcription.lower():
                    tx_type = 'SALE_CREDIT'
                elif 'returned' in transcription.lower():
                    tx_type = 'PAYMENT_RECEIVED'
                else:
                    tx_type = 'SALE_PAID'
                
                return {
                    'customer_name': name,
                    'amount': amount,
                    'transaction_type': tx_type,
                    'confidence': 0.85,
                    'reasoning': 'Regex pattern match'
                }
    
    return None

def enhanced_regex_fallback(transcription: str, language: str) -> Dict:
    """
    Enhanced regex fallback when Bedrock fails
    """
    # More aggressive pattern matching
    import re
    
    # Extract any number
    amount_match = re.search(r'(\d+)', transcription)
    amount = float(amount_match.group(1)) if amount_match else 0.0
    
    # Extract first word as name
    name_match = re.search(r'(\w+)', transcription)
    name = name_match.group(1) if name_match else 'Unknown'
    
    # Guess transaction type based on keywords
    transcription_lower = transcription.lower()
    if any(word in transcription_lower for word in ['उधार', 'credit', 'बाकी']):
        tx_type = 'SALE_CREDIT'
    elif any(word in transcription_lower for word in ['वापस', 'returned', 'paid back']):
        tx_type = 'PAYMENT_RECEIVED'
    else:
        tx_type = 'SALE_PAID'
    
    return {
        'customer_name': name,
        'amount': amount,
        'transaction_type': tx_type,
        'confidence': 0.5,  # Low confidence
        'reasoning': 'Enhanced regex fallback (manual review recommended)'
    }
```

#### 3.6.3 Bedrock Cost Optimization

```python
# Cache common customer names to reduce Bedrock calls
from functools import lru_cache
import hashlib

@lru_cache(maxsize=1000)
def get_cached_extraction(transcription_hash: str, transcription: str, language: str) -> Dict:
    """Cache Bedrock results for identical transcriptions"""
    return extract_transaction_with_bedrock(transcription, language)

def extract_with_cache(transcription: str, language: str) -> Dict:
    """Use cache to reduce Bedrock API calls"""
    # Create hash of transcription
    transcription_hash = hashlib.md5(transcription.encode()).hexdigest()
    
    try:
        return get_cached_extraction(transcription_hash, transcription, language)
    except Exception as e:
        print(f"Cache miss or error: {e}")
        return extract_transaction_with_bedrock(transcription, language)
```

### 3.7 Security Layer

#### 3.7.1 AWS Secrets Manager Configuration

```yaml
Secrets:
  - Name: bolkhata/db-credentials
    Description: RDS PostgreSQL credentials
    Value:
      username: bolkhata_admin
      password: ${GENERATED_PASSWORD}
      host: ${RDS_ENDPOINT}
      port: 5432
      database: bol_khata
    Rotation:
      Enabled: true
      Interval: 30 days
      Lambda: ${ROTATION_LAMBDA_ARN}
    
  - Name: bolkhata/api-keys
    Description: External API keys
    Value:
      sarvam: ${SARVAM_API_KEY}
      whatsapp: ${WHATSAPP_API_KEY}
    Rotation:
      Enabled: false
    
  - Name: bolkhata/jwt-secret
    Description: JWT signing secret
    Value:
      secret: ${GENERATED_JWT_SECRET}
    Rotation:
      Enabled: true
      Interval: 90 days
```

#### 3.7.2 IAM Roles and Policies

```yaml
# Lambda Execution Role
Role Name: bolkhata-lambda-execution-role
Policies:
  - PolicyName: LambdaBasicExecution
    PolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Action:
            - logs:CreateLogGroup
            - logs:CreateLogStream
            - logs:PutLogEvents
          Resource: arn:aws:logs:*:*:*
  
  - PolicyName: VPCAccess
    PolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Action:
            - ec2:CreateNetworkInterface
            - ec2:DescribeNetworkInterfaces
            - ec2:DeleteNetworkInterface
          Resource: '*'
  
  - PolicyName: SecretsManagerAccess
    PolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Action:
            - secretsmanager:GetSecretValue
          Resource:
            - arn:aws:secretsmanager:*:*:secret:bolkhata/*
  
  - PolicyName: S3Access
    PolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Action:
            - s3:GetObject
            - s3:PutObject
            - s3:DeleteObject
          Resource:
            - arn:aws:s3:::bolkhata-audio-files/*
  
  - PolicyName: BedrockAccess
    PolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Action:
            - bedrock:InvokeModel
          Resource:
            - arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-*
```

#### 3.7.3 VPC Security Groups

```yaml
# Lambda to RDS Security Group
SecurityGroup Name: sg-lambda-to-rds
Description: Allow Lambda functions to access RDS
VPC: vpc-bolkhata
Inbound Rules: []
Outbound Rules:
  - Protocol: TCP
    Port: 5432
    Destination: sg-rds-from-lambda

# RDS Security Group
SecurityGroup Name: sg-rds-from-lambda
Description: Allow RDS access from Lambda
VPC: vpc-bolkhata
Inbound Rules:
  - Protocol: TCP
    Port: 5432
    Source: sg-lambda-to-rds
Outbound Rules: []

# Lambda to Internet Security Group
SecurityGroup Name: sg-lambda-to-internet
Description: Allow Lambda to access internet (for Sarvam AI)
VPC: vpc-bolkhata
Inbound Rules: []
Outbound Rules:
  - Protocol: TCP
    Port: 443
    Destination: 0.0.0.0/0
```


### 3.8 Monitoring Layer (Amazon CloudWatch)

#### 3.8.1 CloudWatch Metrics

```yaml
Custom Metrics:
  - Namespace: BolKhata/API
    Metrics:
      - Name: APILatency
        Unit: Milliseconds
        Dimensions:
          - Name: Endpoint
          - Name: Method
      
      - Name: APIErrorRate
        Unit: Percent
        Dimensions:
          - Name: Endpoint
          - Name: ErrorType
      
      - Name: APIRequestCount
        Unit: Count
        Dimensions:
          - Name: Endpoint
          - Name: StatusCode
  
  - Namespace: BolKhata/Voice
    Metrics:
      - Name: VoiceProcessingTime
        Unit: Seconds
        Dimensions:
          - Name: Language
      
      - Name: AIConfidenceScore
        Unit: None
        Dimensions:
          - Name: TransactionType
      
      - Name: BedrockUsageCount
        Unit: Count
        Dimensions:
          - Name: Success
      
      - Name: RegexUsageCount
        Unit: Count
        Dimensions:
          - Name: Success
  
  - Namespace: BolKhata/Database
    Metrics:
      - Name: ConnectionPoolUtilization
        Unit: Percent
      
      - Name: QueryExecutionTime
        Unit: Milliseconds
        Dimensions:
          - Name: QueryType
      
      - Name: ConnectionErrors
        Unit: Count
        Dimensions:
          - Name: ErrorType
  
  - Namespace: BolKhata/Cost
    Metrics:
      - Name: BedrockTokenUsage
        Unit: Count
        Dimensions:
          - Name: ModelId
      
      - Name: EstimatedDailyCost
        Unit: None
        Dimensions:
          - Name: Service
```

#### 3.8.2 CloudWatch Alarms

```yaml
Alarms:
  - Name: HighAPIErrorRate
    Metric: BolKhata/API/APIErrorRate
    Threshold: 5  # percent
    EvaluationPeriods: 2
    DatapointsToAlarm: 2
    ComparisonOperator: GreaterThanThreshold
    TreatMissingData: notBreaching
    Actions:
      - SNS: arn:aws:sns:us-east-1:${ACCOUNT_ID}:bolkhata-alerts
  
  - Name: HighAPILatency
    Metric: BolKhata/API/APILatency
    Statistic: Average
    Threshold: 2000  # milliseconds
    EvaluationPeriods: 3
    DatapointsToAlarm: 2
    ComparisonOperator: GreaterThanThreshold
    Actions:
      - SNS: arn:aws:sns:us-east-1:${ACCOUNT_ID}:bolkhata-alerts
  
  - Name: LowAIConfidence
    Metric: BolKhata/Voice/AIConfidenceScore
    Statistic: Average
    Threshold: 0.7
    EvaluationPeriods: 5
    DatapointsToAlarm: 3
    ComparisonOperator: LessThanThreshold
    Actions:
      - SNS: arn:aws:sns:us-east-1:${ACCOUNT_ID}:bolkhata-alerts
  
  - Name: HighDatabaseCPU
    Metric: AWS/RDS/CPUUtilization
    Dimensions:
      DBInstanceIdentifier: bolkhata-db
    Threshold: 80  # percent
    EvaluationPeriods: 3
    DatapointsToAlarm: 2
    ComparisonOperator: GreaterThanThreshold
    Actions:
      - SNS: arn:aws:sns:us-east-1:${ACCOUNT_ID}:bolkhata-alerts
  
  - Name: HighDatabaseConnections
    Metric: AWS/RDS/DatabaseConnections
    Dimensions:
      DBInstanceIdentifier: bolkhata-db
    Threshold: 80
    EvaluationPeriods: 2
    DatapointsToAlarm: 2
    ComparisonOperator: GreaterThanThreshold
    Actions:
      - SNS: arn:aws:sns:us-east-1:${ACCOUNT_ID}:bolkhata-alerts
  
  - Name: LambdaThrottling
    Metric: AWS/Lambda/Throttles
    Statistic: Sum
    Threshold: 10
    EvaluationPeriods: 1
    ComparisonOperator: GreaterThanThreshold
    Actions:
      - SNS: arn:aws:sns:us-east-1:${ACCOUNT_ID}:bolkhata-alerts
  
  - Name: HighMonthlyCost
    Metric: AWS/Billing/EstimatedCharges
    Dimensions:
      Currency: USD
    Threshold: 20  # dollars
    EvaluationPeriods: 1
    ComparisonOperator: GreaterThanThreshold
    Actions:
      - SNS: arn:aws:sns:us-east-1:${ACCOUNT_ID}:bolkhata-cost-alerts
```

#### 3.8.3 CloudWatch Dashboard

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "title": "API Request Count",
        "metrics": [
          ["BolKhata/API", "APIRequestCount", {"stat": "Sum"}]
        ],
        "period": 300,
        "region": "us-east-1"
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "API Latency (p50, p95, p99)",
        "metrics": [
          ["BolKhata/API", "APILatency", {"stat": "p50"}],
          ["...", {"stat": "p95"}],
          ["...", {"stat": "p99"}]
        ],
        "period": 300,
        "region": "us-east-1"
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "Voice Processing Time",
        "metrics": [
          ["BolKhata/Voice", "VoiceProcessingTime", {"stat": "Average"}]
        ],
        "period": 300,
        "region": "us-east-1"
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "AI Confidence Score",
        "metrics": [
          ["BolKhata/Voice", "AIConfidenceScore", {"stat": "Average"}]
        ],
        "period": 300,
        "region": "us-east-1",
        "yAxis": {"left": {"min": 0, "max": 1}}
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "Bedrock vs Regex Usage",
        "metrics": [
          ["BolKhata/Voice", "BedrockUsageCount", {"stat": "Sum", "label": "Bedrock"}],
          [".", "RegexUsageCount", {"stat": "Sum", "label": "Regex"}]
        ],
        "period": 300,
        "region": "us-east-1"
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "Database CPU & Connections",
        "metrics": [
          ["AWS/RDS", "CPUUtilization", {"DBInstanceIdentifier": "bolkhata-db"}],
          [".", "DatabaseConnections", {"DBInstanceIdentifier": "bolkhata-db", "yAxis": "right"}]
        ],
        "period": 300,
        "region": "us-east-1"
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "Lambda Invocations & Errors",
        "metrics": [
          ["AWS/Lambda", "Invocations", {"stat": "Sum"}],
          [".", "Errors", {"stat": "Sum"}],
          [".", "Throttles", {"stat": "Sum"}]
        ],
        "period": 300,
        "region": "us-east-1"
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "Estimated Daily Cost",
        "metrics": [
          ["BolKhata/Cost", "EstimatedDailyCost", {"stat": "Sum"}]
        ],
        "period": 86400,
        "region": "us-east-1"
      }
    }
  ]
}
```

#### 3.8.4 Log Groups and Retention

```yaml
Log Groups:
  - Name: /aws/lambda/bolkhata-banking-service
    Retention: 7 days
    
  - Name: /aws/lambda/bolkhata-voice-service
    Retention: 7 days
    
  - Name: /aws/lambda/bolkhata-auth-service
    Retention: 7 days
    
  - Name: /aws/lambda/bolkhata-transaction-service
    Retention: 7 days
    
  - Name: /aws/lambda/bolkhata-customer-service
    Retention: 7 days
    
  - Name: /aws/apigateway/bolkhata-api
    Retention: 7 days
    
  - Name: /aws/rds/instance/bolkhata-db/postgresql
    Retention: 7 days

Log Insights Queries:
  - Name: Top 10 Slowest API Endpoints
    Query: |
      fields @timestamp, endpoint, latency
      | filter @message like /API_LATENCY/
      | sort latency desc
      | limit 10
  
  - Name: Error Rate by Endpoint
    Query: |
      fields @timestamp, endpoint, error
      | filter @message like /ERROR/
      | stats count() by endpoint
      | sort count desc
  
  - Name: Bedrock Usage and Cost
    Query: |
      fields @timestamp, tokens_used, cost
      | filter @message like /BEDROCK_CALL/
      | stats sum(tokens_used) as total_tokens, sum(cost) as total_cost
```

## 4. Data Models

### 4.1 API Request/Response Formats

#### 4.1.1 Authentication

```json
// POST /api/auth/register
{
  "username": "string (3-50 chars)",
  "password": "string (8-100 chars)",
  "email": "string (optional)",
  "phone": "string (optional)",
  "shopName": "string (optional)"
}

// Response
{
  "success": true,
  "data": {
    "userId": 123,
    "username": "shopkeeper1",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 86400
  }
}

// POST /api/auth/login
{
  "username": "string",
  "password": "string"
}

// Response
{
  "success": true,
  "data": {
    "userId": 123,
    "username": "shopkeeper1",
    "shopName": "Raju Tea Stall",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 86400
  }
}
```

#### 4.1.2 Customers

```json
// GET /api/customers
// Response
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "राजू",
      "phone": "+91-9876543210",
      "address": "Shop 12, Main Market",
      "balance": 150.50,
      "createdAt": "2026-03-01T10:30:00Z",
      "updatedAt": "2026-03-06T15:45:00Z"
    }
  ],
  "count": 1
}

// POST /api/customers
{
  "name": "string (required)",
  "phone": "string (optional)",
  "address": "string (optional)"
}

// Response
{
  "success": true,
  "data": {
    "id": 2,
    "name": "सीता",
    "phone": null,
    "address": null,
    "balance": 0.00,
    "createdAt": "2026-03-06T16:00:00Z"
  }
}
```

#### 4.1.3 Transactions

```json
// POST /api/transactions
{
  "customerId": 1,
  "amount": 100.50,
  "transactionType": "SALE_PAID",
  "description": "Tea and snacks",
  "audioPath": "audio/1/2026/03/1772806304960_673d33eb.mp3",
  "confidenceScore": 0.95
}

// Response
{
  "success": true,
  "data": {
    "id": 456,
    "userId": 123,
    "customerId": 1,
    "customerName": "राजू",
    "amount": 100.50,
    "transactionType": "SALE_PAID",
    "description": "Tea and snacks",
    "audioPath": "audio/1/2026/03/1772806304960_673d33eb.mp3",
    "audioUrl": "https://s3.amazonaws.com/bolkhata-audio-files/...",
    "confidenceScore": 0.95,
    "createdAt": "2026-03-06T16:05:00Z"
  }
}

// GET /api/transactions?startDate=2026-03-01&endDate=2026-03-06&customerId=1
// Response
{
  "success": true,
  "data": [
    {
      "id": 456,
      "customerName": "राजू",
      "amount": 100.50,
      "transactionType": "SALE_PAID",
      "description": "Tea and snacks",
      "audioUrl": "https://...",
      "confidenceScore": 0.95,
      "createdAt": "2026-03-06T16:05:00Z"
    }
  ],
  "count": 1,
  "summary": {
    "totalIncome": 250.00,
    "totalCredit": 150.50,
    "totalPayments": 100.00,
    "netOutstanding": 50.50
  }
}
```

#### 4.1.4 Voice Processing

```json
// POST /voice/process-voice
{
  "audioData": "base64_encoded_audio_data",
  "language": "hindi",
  "userId": 123
}

// Response
{
  "success": true,
  "data": {
    "transcription": "राजू ने 50 रुपये उधार लिए",
    "extraction": {
      "customerName": "राजू",
      "amount": 50.00,
      "transactionType": "SALE_CREDIT",
      "confidence": 0.95,
      "reasoning": "Clear voice, unambiguous intent"
    },
    "audioPath": "audio/123/2026/03/1772806304960_673d33eb.mp3",
    "processingTime": 6.5
  }
}
```

### 4.2 Environment Configuration

```yaml
# .env.production
# API Gateway
API_GATEWAY_URL=https://abc123.execute-api.us-east-1.amazonaws.com/prod

# Database
DB_HOST=bolkhata-db.abc123.us-east-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=bol_khata
DB_USER=${SECRET:db-credentials:username}
DB_PASSWORD=${SECRET:db-credentials:password}
DB_POOL_MIN=5
DB_POOL_MAX=20

# S3
S3_BUCKET=bolkhata-audio-files-123456789
S3_REGION=us-east-1

# Bedrock
BEDROCK_REGION=us-east-1
BEDROCK_MODEL_ID=anthropic.claude-3-haiku-20240307-v1:0
AI_RETRY_ATTEMPTS=3
AI_RETRY_DELAY=1
AI_TIMEOUT=5

# JWT
JWT_SECRET=${SECRET:jwt-secret:value}
JWT_EXPIRATION=86400

# External APIs
SARVAM_API_KEY=${SECRET:api-keys:sarvam}
SARVAM_API_URL=https://api.sarvam.ai/v1

# Monitoring
LOG_LEVEL=INFO
ENABLE_METRICS=true
METRICS_NAMESPACE=BolKhata
```

## 5. Deployment Procedures

### 5.1 Pre-Deployment Checklist

```yaml
Prerequisites:
  - AWS Account with billing enabled
  - IAM User created with deployment permissions
  - AWS CLI installed and configured
  - Docker installed (for Lambda packaging)
  - Node.js 18+ installed
  - Python 3.11+ installed
  - Java 17+ installed
  - Maven installed
  - PostgreSQL client installed

AWS Services Enabled:
  - Amazon Bedrock (with Claude 3 Haiku access)
  - AWS Lambda
  - Amazon API Gateway
  - Amazon RDS
  - Amazon S3
  - AWS Secrets Manager
  - Amazon CloudWatch
  - AWS Amplify

Credentials and Keys:
  - Sarvam AI API key
  - WhatsApp API credentials (optional)
  - Email for SNS notifications
```

### 5.1.1 IAM User Setup

**Step 1: Create IAM User (via Root Account)**

```bash
# Login to AWS Console with root user
# Navigate to IAM → Users → Create User

User Name: bolkhata-deployer
Access Type: Programmatic access + AWS Management Console access
Console Password: Auto-generated or custom
Require password reset: Optional
```

**Step 2: Attach Required Policies**

Attach these AWS managed policies to the IAM user:

```yaml
Required Policies:
  - AdministratorAccess  # Simplest for hackathon (full access)

# OR for more granular control, attach these specific policies:
Granular Policies:
  - AWSLambda_FullAccess
  - AmazonAPIGatewayAdministrator
  - AmazonRDSFullAccess
  - AmazonS3FullAccess
  - SecretsManagerReadWrite
  - CloudWatchFullAccess
  - AWSAmplifyFullAccess
  - IAMFullAccess
  - AmazonVPCFullAccess
  - AmazonBedrockFullAccess
```

**Step 3: Create Access Keys**

```bash
# In IAM Console → Users → bolkhata-deployer → Security Credentials
# Click "Create access key"
# Choose "Command Line Interface (CLI)"
# Download the CSV file with:
#   - Access Key ID
#   - Secret Access Key
```

**Step 4: Configure AWS CLI**

```bash
# Configure AWS CLI with IAM user credentials
aws configure

# Enter the following:
AWS Access Key ID: <YOUR_ACCESS_KEY_ID>
AWS Secret Access Key: <YOUR_SECRET_ACCESS_KEY>
Default region name: us-east-1
Default output format: json

# Verify configuration
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "AIDAXXXXXXXXXXXXXXXXX",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/bolkhata-deployer"
# }
```

**Step 5: Enable Bedrock Model Access (Root User Required)**

```bash
# This step requires root user access temporarily
# Login to AWS Console with root user
# Navigate to Amazon Bedrock → Model access
# Request access to: Claude 3 Haiku
# Wait for approval (usually instant)
# Then switch back to IAM user for deployment
```

**Recommended IAM Policy for Deployment (Custom)**

If you want precise permissions instead of AdministratorAccess:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:*",
        "apigateway:*",
        "rds:*",
        "s3:*",
        "secretsmanager:*",
        "cloudwatch:*",
        "logs:*",
        "amplify:*",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PassRole",
        "iam:GetRole",
        "iam:CreatePolicy",
        "ec2:CreateVpc",
        "ec2:CreateSubnet",
        "ec2:CreateSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "bedrock:InvokeModel",
        "bedrock:ListFoundationModels",
        "sns:CreateTopic",
        "sns:Subscribe",
        "sns:Publish"
      ],
      "Resource": "*"
    }
  ]
}
```

### 5.2 Deployment Steps Summary

```
Phase 1: Infrastructure Setup (30 mins)
  1. Create VPC and subnets
  2. Create security groups
  3. Create RDS PostgreSQL instance
  4. Create S3 buckets
  5. Create Secrets Manager secrets

Phase 2: Database Initialization (15 mins)
  6. Connect to RDS
  7. Run schema creation scripts
  8. Create indexes
  9. Insert seed data

Phase 3: Lambda Deployment (45 mins)
  10. Package banking service
  11. Package voice service
  12. Package auth service
  13. Package transaction service
  14. Package customer service
  15. Deploy all Lambda functions
  16. Configure provisioned concurrency

Phase 4: API Gateway Setup (30 mins)
  17. Create REST API
  18. Configure routes
  19. Set up CORS
  20. Enable caching
  21. Deploy to prod stage

Phase 5: Frontend Deployment (20 mins)
  22. Update API endpoints in frontend
  23. Build frontend assets
  24. Deploy to AWS Amplify
  25. Configure custom domain (optional)

Phase 6: Monitoring Setup (15 mins)
  26. Create CloudWatch dashboard
  27. Configure alarms
  28. Set up SNS notifications
  29. Enable X-Ray tracing

Phase 7: Testing and Validation (30 mins)
  30. Run integration tests
  31. Perform load testing
  32. Validate all features
  33. Check monitoring dashboards

Total Time: ~3 hours
```

The design document is complete and ready for implementation. Would you like me to proceed with creating the implementation tasks?

