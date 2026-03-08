# Implementation Tasks: AWS Deployment for Hackathon Submission

## Task Organization

Tasks are organized into phases for systematic deployment. Each task includes acceptance criteria and estimated time.

---

## Phase 1: AWS Account and IAM Setup

### Task 1.1: Create IAM User for Deployment
**Status**: pending
**Priority**: high
**Estimated Time**: 15 minutes

**Description**: Create an IAM user with necessary permissions for deploying all AWS resources.

**Acceptance Criteria**:
- [ ] IAM user "bolkhata-deployer" created via AWS Console
- [ ] AdministratorAccess policy attached (or granular policies)
- [ ] Access keys generated and downloaded
- [ ] AWS CLI configured with IAM user credentials
- [ ] `aws sts get-caller-identity` returns IAM user ARN
- [ ] Amazon Bedrock model access enabled for Claude 3 Haiku

**Commands**:
```bash
# Configure AWS CLI
aws configure

# Verify identity
aws sts get-caller-identity

# Test Bedrock access
aws bedrock list-foundation-models --region us-east-1
```

---

### Task 1.2: Install Required Tools
**Status**: pending
**Priority**: high
**Estimated Time**: 20 minutes

**Description**: Install all required development and deployment tools.

**Acceptance Criteria**:
- [ ] AWS CLI installed and working
- [ ] Docker installed and running
- [ ] Node.js 18+ installed
- [ ] Python 3.11+ installed
- [ ] Java 17+ installed
- [ ] Maven installed
- [ ] PostgreSQL client (psql) installed

**Verification Commands**:
```bash
aws --version
docker --version
node --version
python --version
java --version
mvn --version
psql --version
```

---

## Phase 2: Infrastructure Setup

### Task 2.1: Create VPC and Network Infrastructure
**Status**: pending
**Priority**: high
**Estimated Time**: 20 minutes

**Description**: Set up VPC, subnets, and security groups for the application.

**Acceptance Criteria**:
- [ ] VPC created with CIDR 10.0.0.0/16
- [ ] Public subnet created in us-east-1a (10.0.1.0/24)
- [ ] Private subnet created in us-east-1a (10.0.2.0/24)
- [ ] Private subnet created in us-east-1b (10.0.3.0/24) for Multi-AZ
- [ ] Internet Gateway attached to VPC
- [ ] NAT Gateway created in public subnet
- [ ] Route tables configured
- [ ] Security groups created (sg-lambda-to-rds, sg-rds-from-lambda, sg-lambda-to-internet)

**Script**: Create `scripts/01-create-vpc.sh`

---

### Task 2.2: Create RDS PostgreSQL Instance
**Status**: pending
**Priority**: high
**Estimated Time**: 25 minutes

**Description**: Deploy managed PostgreSQL database with Multi-AZ for high availability.

**Acceptance Criteria**:
- [ ] RDS instance "bolkhata-db" created
- [ ] Engine: PostgreSQL 15.4
- [ ] Instance class: db.t3.micro
- [ ] Storage: 20GB with auto-scaling enabled
- [ ] Multi-AZ deployment enabled
- [ ] Automated backups enabled (7-day retention)
- [ ] Placed in private subnets
- [ ] Security group allows access from Lambda security group
- [ ] Performance Insights enabled
- [ ] Encryption at rest enabled

**Script**: Create `scripts/02-create-rds.sh`

---

### Task 2.3: Create S3 Buckets
**Status**: pending
**Priority**: high
**Estimated Time**: 10 minutes

**Description**: Create S3 buckets for audio storage and backups.

**Acceptance Criteria**:
- [ ] Bucket "bolkhata-audio-files-{account-id}" created
- [ ] Versioning enabled
- [ ] Encryption enabled (AES-256)
- [ ] Lifecycle policy configured (archive after 30 days, delete after 365 days)
- [ ] CORS configured for Amplify domain
- [ ] Public access blocked
- [ ] Event notification configured for Lambda trigger

**Script**: Create `scripts/03-create-s3.sh`

---

### Task 2.4: Create Secrets in Secrets Manager
**Status**: pending
**Priority**: high
**Estimated Time**: 10 minutes

**Description**: Store sensitive credentials securely in AWS Secrets Manager.

**Acceptance Criteria**:
- [ ] Secret "bolkhata/db-credentials" created with RDS credentials
- [ ] Secret "bolkhata/api-keys" created with Sarvam AI key
- [ ] Secret "bolkhata/jwt-secret" created with generated JWT secret
- [ ] All secrets encrypted with AWS KMS
- [ ] Secrets retrievable via AWS CLI

**Script**: Create `scripts/04-create-secrets.sh`

---

## Phase 3: Database Initialization

### Task 3.1: Initialize Database Schema
**Status**: pending
**Priority**: high
**Estimated Time**: 15 minutes

**Description**: Connect to RDS and create database schema with tables, indexes, and triggers.

**Acceptance Criteria**:
- [ ] Connected to RDS instance successfully
- [ ] Database "bol_khata" created
- [ ] Tables created: users, customers, transactions
- [ ] Indexes created on all foreign keys and frequently queried columns
- [ ] Triggers created for balance updates and timestamp updates
- [ ] Schema verified with `\dt` and `\di` commands

**Script**: Create `scripts/05-init-database.sql`

---

### Task 3.2: Migrate Existing Data
**Status**: pending
**Priority**: medium
**Estimated Time**: 15 minutes

**Description**: Export data from local PostgreSQL and import to RDS.

**Acceptance Criteria**:
- [ ] Local data exported to SQL dump
- [ ] Data imported to RDS successfully
- [ ] Record counts match between local and RDS
- [ ] Customer balances calculated correctly
- [ ] No foreign key constraint violations

**Script**: Create `scripts/06-migrate-data.sh`

---

## Phase 4: Lambda Functions Development

### Task 4.1: Create Lambda Handler for Banking Service
**Status**: pending
**Priority**: high
**Estimated Time**: 30 minutes

**Description**: Modify Java Spring Boot application to work as Lambda function using AWS Lambda Web Adapter.

**Acceptance Criteria**:
- [ ] Lambda handler class created
- [ ] Environment variables configured for RDS connection
- [ ] Connection pooling implemented
- [ ] Retry logic added for database operations
- [ ] Health check endpoint added
- [ ] Dockerfile created for Lambda container image
- [ ] Local testing successful

**Files to Modify**:
- `banking-service/src/main/java/com/bolkhata/StreamLambdaHandler.java` (NEW)
- `banking-service/Dockerfile` (NEW)
- `banking-service/pom.xml` (add AWS SDK dependencies)

---

### Task 4.2: Create Lambda Handler for Voice Service
**Status**: pending
**Priority**: high
**Estimated Time**: 45 minutes

**Description**: Modify Python FastAPI voice service to work as Lambda function with Bedrock integration.

**Acceptance Criteria**:
- [ ] Lambda handler function created
- [ ] Bedrock client initialized
- [ ] Smart NLU with regex-first approach implemented
- [ ] Retry logic with exponential backoff added
- [ ] Enhanced regex fallback implemented
- [ ] S3 integration for audio files added
- [ ] Connection pooling for database added
- [ ] requirements.txt updated with AWS SDK
- [ ] Local testing successful

**Files to Modify**:
- `voice-service/lambda_handler.py` (NEW)
- `voice-service/app/services/bedrock_service.py` (NEW)
- `voice-service/app/services/nlu_service.py` (MODIFY - add Bedrock)
- `voice-service/requirements.txt` (add boto3, psycopg2-binary)
- `voice-service/Dockerfile` (NEW)

---

### Task 4.3: Create Auth Lambda Function
**Status**: pending
**Priority**: high
**Estimated Time**: 30 minutes

**Description**: Create standalone Lambda function for authentication (login/register).

**Acceptance Criteria**:
- [ ] Lambda function handles /api/auth/login
- [ ] Lambda function handles /api/auth/register
- [ ] Password hashing with bcrypt implemented
- [ ] JWT token generation implemented
- [ ] Database connection pooling added
- [ ] Input validation added
- [ ] Error handling with proper HTTP status codes
- [ ] Local testing successful

**Files to Create**:
- `lambda-functions/auth/handler.py`
- `lambda-functions/auth/requirements.txt`
- `lambda-functions/auth/Dockerfile`

---

### Task 4.4: Create Transaction Lambda Function
**Status**: pending
**Priority**: high
**Estimated Time**: 30 minutes

**Description**: Create standalone Lambda function for transaction operations.

**Acceptance Criteria**:
- [ ] Lambda function handles GET /api/transactions
- [ ] Lambda function handles POST /api/transactions
- [ ] Lambda function handles GET /api/transactions/{id}
- [ ] Database queries optimized with indexes
- [ ] Connection pooling implemented
- [ ] Retry logic added
- [ ] Input validation added
- [ ] Local testing successful

**Files to Create**:
- `lambda-functions/transaction/handler.py`
- `lambda-functions/transaction/requirements.txt`
- `lambda-functions/transaction/Dockerfile`

---

### Task 4.5: Create Customer Lambda Function
**Status**: pending
**Priority**: high
**Estimated Time**: 25 minutes

**Description**: Create standalone Lambda function for customer management.

**Acceptance Criteria**:
- [ ] Lambda function handles GET /api/customers
- [ ] Lambda function handles POST /api/customers
- [ ] Lambda function handles GET /api/customers/{id}
- [ ] Lambda function handles PUT /api/customers/{id}
- [ ] Database operations with retry logic
- [ ] Connection pooling implemented
- [ ] Input validation added
- [ ] Local testing successful

**Files to Create**:
- `lambda-functions/customer/handler.py`
- `lambda-functions/customer/requirements.txt`
- `lambda-functions/customer/Dockerfile`

---

## Phase 5: Lambda Deployment

### Task 5.1: Package and Deploy Banking Lambda
**Status**: pending
**Priority**: high
**Estimated Time**: 20 minutes

**Description**: Build Docker image and deploy banking service as Lambda function.

**Acceptance Criteria**:
- [ ] Docker image built successfully
- [ ] Image pushed to Amazon ECR
- [ ] Lambda function created from ECR image
- [ ] Environment variables configured
- [ ] VPC configuration added
- [ ] Memory set to 1024MB
- [ ] Timeout set to 15s
- [ ] Provisioned concurrency set to 2
- [ ] Reserved concurrency set to 50
- [ ] Function invocable via AWS CLI

**Script**: Create `scripts/07-deploy-banking-lambda.sh`

---

### Task 5.2: Package and Deploy Voice Lambda
**Status**: pending
**Priority**: high
**Estimated Time**: 20 minutes

**Description**: Build Docker image and deploy voice service as Lambda function.

**Acceptance Criteria**:
- [ ] Docker image built successfully
- [ ] Image pushed to Amazon ECR
- [ ] Lambda function created from ECR image
- [ ] Environment variables configured (including Bedrock settings)
- [ ] VPC configuration added
- [ ] IAM role includes Bedrock permissions
- [ ] Memory set to 1024MB
- [ ] Timeout set to 30s
- [ ] Provisioned concurrency set to 2
- [ ] Reserved concurrency set to 20
- [ ] Function invocable via AWS CLI

**Script**: Create `scripts/08-deploy-voice-lambda.sh`

---

### Task 5.3: Deploy Auth Lambda
**Status**: pending
**Priority**: high
**Estimated Time**: 15 minutes

**Description**: Package and deploy authentication Lambda function.

**Acceptance Criteria**:
- [ ] Lambda function deployed
- [ ] Environment variables configured
- [ ] VPC configuration added
- [ ] Memory set to 512MB
- [ ] Timeout set to 10s
- [ ] Provisioned concurrency set to 1
- [ ] Function invocable via AWS CLI

**Script**: Create `scripts/09-deploy-auth-lambda.sh`

---

### Task 5.4: Deploy Transaction Lambda
**Status**: pending
**Priority**: high
**Estimated Time**: 15 minutes

**Description**: Package and deploy transaction Lambda function.

**Acceptance Criteria**:
- [ ] Lambda function deployed
- [ ] Environment variables configured
- [ ] VPC configuration added
- [ ] Memory set to 512MB
- [ ] Timeout set to 15s
- [ ] Provisioned concurrency set to 2
- [ ] Reserved concurrency set to 30
- [ ] Function invocable via AWS CLI

**Script**: Create `scripts/10-deploy-transaction-lambda.sh`

---

### Task 5.5: Deploy Customer Lambda
**Status**: pending
**Priority**: high
**Estimated Time**: 15 minutes

**Description**: Package and deploy customer Lambda function.

**Acceptance Criteria**:
- [ ] Lambda function deployed
- [ ] Environment variables configured
- [ ] VPC configuration added
- [ ] Memory set to 512MB
- [ ] Timeout set to 15s
- [ ] Provisioned concurrency set to 1
- [ ] Reserved concurrency set to 20
- [ ] Function invocable via AWS CLI

**Script**: Create `scripts/11-deploy-customer-lambda.sh`

---

## Phase 6: API Gateway Setup

### Task 6.1: Create REST API
**Status**: pending
**Priority**: high
**Estimated Time**: 30 minutes

**Description**: Create API Gateway REST API with all routes and integrations.

**Acceptance Criteria**:
- [ ] REST API "bolkhata-api" created
- [ ] All routes configured (auth, customers, transactions, voice, statistics)
- [ ] Lambda integrations configured for each route
- [ ] Request validation enabled
- [ ] CORS enabled for all routes
- [ ] Rate limiting configured (10000 req/min, 5000 burst)
- [ ] Response caching enabled (300s TTL)
- [ ] API deployed to "prod" stage
- [ ] API Gateway URL obtained

**Script**: Create `scripts/12-create-api-gateway.sh`

---

### Task 6.2: Configure API Gateway Logging and Monitoring
**Status**: pending
**Priority**: medium
**Estimated Time**: 15 minutes

**Description**: Enable CloudWatch logging and metrics for API Gateway.

**Acceptance Criteria**:
- [ ] Access logging enabled
- [ ] Execution logging enabled
- [ ] Log level set to INFO
- [ ] CloudWatch log group created
- [ ] Metrics enabled
- [ ] X-Ray tracing enabled

**Script**: Create `scripts/13-configure-api-logging.sh`

---

## Phase 7: Frontend Deployment

### Task 7.1: Update Frontend Configuration
**Status**: pending
**Priority**: high
**Estimated Time**: 20 minutes

**Description**: Update frontend code to use API Gateway endpoints.

**Acceptance Criteria**:
- [ ] API_BASE_URL updated to API Gateway URL
- [ ] VOICE_API_URL updated to API Gateway URL
- [ ] Service worker added for offline capability
- [ ] Error handling improved with retry logic
- [ ] Optimistic UI updates implemented
- [ ] Local testing with API Gateway successful

**Files to Modify**:
- `web-ui/app-final.js` (update API endpoints)
- `web-ui/service-worker.js` (NEW - offline support)
- `web-ui/app-final.html` (register service worker)

---

### Task 7.2: Deploy to AWS Amplify
**Status**: pending
**Priority**: high
**Estimated Time**: 20 minutes

**Description**: Deploy frontend to AWS Amplify for CDN-backed hosting.

**Acceptance Criteria**:
- [ ] Amplify app created
- [ ] Frontend files uploaded
- [ ] HTTPS enabled automatically
- [ ] CDN distribution active
- [ ] Custom domain configured (optional)
- [ ] Application accessible via Amplify URL
- [ ] All pages load correctly
- [ ] API calls work from Amplify domain

**Script**: Create `scripts/14-deploy-amplify.sh`

---

## Phase 8: Monitoring and Alarms

### Task 8.1: Create CloudWatch Dashboard
**Status**: pending
**Priority**: medium
**Estimated Time**: 20 minutes

**Description**: Create comprehensive CloudWatch dashboard for monitoring.

**Acceptance Criteria**:
- [ ] Dashboard "BolKhata-Production" created
- [ ] Widgets added for API request count
- [ ] Widgets added for API latency (p50, p95, p99)
- [ ] Widgets added for Lambda invocations and errors
- [ ] Widgets added for RDS CPU and connections
- [ ] Widgets added for Bedrock usage
- [ ] Widgets added for estimated costs
- [ ] Dashboard accessible via AWS Console

**Script**: Create `scripts/15-create-dashboard.sh`

---

### Task 8.2: Configure CloudWatch Alarms
**Status**: pending
**Priority**: high
**Estimated Time**: 20 minutes

**Description**: Set up alarms for critical metrics with SNS notifications.

**Acceptance Criteria**:
- [ ] SNS topic created for alerts
- [ ] Email subscription configured
- [ ] Alarm created for high API error rate (>5%)
- [ ] Alarm created for high API latency (>2s)
- [ ] Alarm created for low AI confidence (<0.7)
- [ ] Alarm created for high database CPU (>80%)
- [ ] Alarm created for Lambda throttling
- [ ] Alarm created for high monthly cost (>$20)
- [ ] Test alarm triggered successfully

**Script**: Create `scripts/16-create-alarms.sh`

---

## Phase 9: Testing and Validation

### Task 9.1: Integration Testing
**Status**: pending
**Priority**: high
**Estimated Time**: 30 minutes

**Description**: Test all features end-to-end on deployed infrastructure.

**Acceptance Criteria**:
- [ ] User registration works
- [ ] User login works and returns JWT token
- [ ] Customer creation works
- [ ] Customer list retrieval works
- [ ] Manual transaction entry works
- [ ] Voice transaction recording works
- [ ] Voice processing completes within 8 seconds
- [ ] Bedrock NLU extraction works
- [ ] Regex fallback works when Bedrock fails
- [ ] Transaction list retrieval works
- [ ] Statistics dashboard loads
- [ ] Passbook generation works
- [ ] PDF download works
- [ ] Audio playback works
- [ ] WhatsApp buttons render correctly
- [ ] Language toggle works

**Script**: Create `scripts/17-integration-tests.sh`

---

### Task 9.2: Performance Testing
**Status**: pending
**Priority**: medium
**Estimated Time**: 20 minutes

**Description**: Validate performance targets are met.

**Acceptance Criteria**:
- [ ] Frontend loads within 500ms
- [ ] API authentication responds within 1s
- [ ] API transaction queries respond within 1s
- [ ] Voice processing completes within 8s
- [ ] Database queries execute within 100ms
- [ ] No cold starts observed (provisioned concurrency working)
- [ ] System handles 50 concurrent users without degradation
- [ ] No throttling errors observed

**Script**: Create `scripts/18-performance-tests.sh`

---

### Task 9.3: Cost Validation
**Status**: pending
**Priority**: medium
**Estimated Time**: 15 minutes

**Description**: Verify deployment costs are within budget.

**Acceptance Criteria**:
- [ ] Cost Explorer shows daily costs
- [ ] Estimated monthly cost is $10-15
- [ ] Free tier usage maximized
- [ ] Bedrock token usage tracked
- [ ] No unexpected charges
- [ ] Cost alarms configured and working

**Script**: Create `scripts/19-validate-costs.sh`

---

## Phase 10: Documentation and Submission

### Task 10.1: Create Deployment Documentation
**Status**: pending
**Priority**: high
**Estimated Time**: 30 minutes

**Description**: Document the deployment for hackathon submission.

**Acceptance Criteria**:
- [ ] README.md updated with deployment instructions
- [ ] Architecture diagram created
- [ ] AWS services list documented
- [ ] AI value proposition clearly explained
- [ ] Deployed URL documented
- [ ] Test credentials provided
- [ ] Cost breakdown documented
- [ ] Screenshots of working application added

**Files to Create**:
- `DEPLOYMENT.md`
- `ARCHITECTURE.md`
- `AI_VALUE_PROPOSITION.md`

---

### Task 10.2: Create Demo Video
**Status**: pending
**Priority**: high
**Estimated Time**: 30 minutes

**Description**: Record video demonstration of key features.

**Acceptance Criteria**:
- [ ] Video shows user registration/login
- [ ] Video shows voice transaction recording
- [ ] Video shows manual transaction entry
- [ ] Video shows passbook generation
- [ ] Video shows PDF download
- [ ] Video shows language toggle
- [ ] Video shows WhatsApp buttons
- [ ] Video shows AI confidence indicators
- [ ] Video highlights AWS services used
- [ ] Video explains AI value proposition
- [ ] Video uploaded and link added to submission

---

### Task 10.3: Final Submission Checklist
**Status**: pending
**Priority**: high
**Estimated Time**: 15 minutes

**Description**: Complete final checks before hackathon submission.

**Acceptance Criteria**:
- [ ] Application accessible via HTTPS URL
- [ ] All features working without errors
- [ ] Amazon Bedrock actively used and logged
- [ ] Multiple AWS services integrated (Lambda, API Gateway, RDS, S3, Amplify, Bedrock, Secrets Manager, CloudWatch)
- [ ] Documentation complete
- [ ] Test credentials provided
- [ ] Demo video uploaded
- [ ] Monthly cost within $10-15
- [ ] Performance targets met
- [ ] Mobile responsiveness verified
- [ ] Submission form completed

---

## Summary

**Total Tasks**: 33
**Estimated Total Time**: 8-9 hours
**Critical Path**: Tasks 1.1 → 2.1 → 2.2 → 3.1 → 4.1-4.5 → 5.1-5.5 → 6.1 → 7.1 → 7.2 → 9.1

**Phases**:
1. AWS Account and IAM Setup: 35 minutes
2. Infrastructure Setup: 65 minutes
3. Database Initialization: 30 minutes
4. Lambda Functions Development: 160 minutes
5. Lambda Deployment: 85 minutes
6. API Gateway Setup: 45 minutes
7. Frontend Deployment: 40 minutes
8. Monitoring and Alarms: 40 minutes
9. Testing and Validation: 65 minutes
10. Documentation and Submission: 75 minutes

**Next Steps**: Start with Phase 1 (IAM setup) and proceed sequentially through each phase.
