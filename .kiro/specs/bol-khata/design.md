# Design Document: Bol-Khata Voice-First Financial Ledger

## Overview

Bol-Khata is a microservices-based voice-first financial ledger system designed for semi-literate street vendors in India. The system consists of two primary microservices:

1. **Voice Service** (Python/FastAPI): Handles speech-to-text transcription and natural language understanding
2. **Banking Service** (Java/Spring Boot): Manages business logic, database operations, and external integrations

The architecture follows a clear separation of concerns: the Voice Service focuses on AI/ML operations (ASR and NLU), while the Banking Service handles all financial logic, data persistence, and customer communications.

## Architecture

### High-Level Architecture

```
┌─────────────┐
│   Mobile/   │
│   Web App   │
└──────┬──────┘
       │ Audio File
       ▼
┌─────────────────────────────────────────┐
│      Voice Service (Python/FastAPI)     │
│  ┌────────────┐      ┌──────────────┐  │
│  │    ASR     │──────▶│     NLU      │  │
│  │ (Sarvam/   │      │  (3-Tier)    │  │
│  │  Bhashini) │      │              │  │
│  └────────────┘      └──────────────┘  │
└──────────────┬──────────────────────────┘
               │ JSON (name, amount, type)
               ▼
┌─────────────────────────────────────────┐
│   Banking Service (Java/Spring Boot)    │
│  ┌──────────┐  ┌──────────┐  ┌───────┐ │
│  │  Fuzzy   │  │ Balance  │  │WhatsApp│ │
│  │  Match   │  │ Manager  │  │ Alert │ │
│  └──────────┘  └──────────┘  └───────┘ │
└──────────────┬──────────────────────────┘
               │
               ▼
         ┌──────────┐
         │  MySQL   │
         │ Database │
         └──────────┘
```

### Service Communication

- Frontend → Voice Service: HTTP POST with multipart/form-data (audio file)
- Voice Service → Banking Service: HTTP POST with JSON payload
- Banking Service → WhatsApp API: HTTP POST for notifications
- Banking Service → MySQL: JDBC connections

### Technology Stack

**Voice Service:**
- Language: Python 3.10+
- Framework: FastAPI
- ASR: Sarvam AI (primary), Bhashini (fallback)
- NLU: Regex + spaCy + OpenAI GPT (fallback)
- Audio Processing: librosa, pydub

**Banking Service:**
- Language: Java 17+
- Framework: Spring Boot 3.x
- Database: MySQL 8.0
- ORM: Spring Data JPA
- WhatsApp: Twilio API or WhatsApp Business API

**Database:**
- MySQL 8.0 with InnoDB engine
- Connection pooling via HikariCP

## Components and Interfaces

### Voice Service Components

#### 1. Audio Handler
**Responsibility:** Receive and validate audio files

**Interface:**
```python
class AudioHandler:
    def validate_audio(file: UploadFile) -> bool:
        """
        Validates audio file format and size.
        Returns True if valid, raises ValueError otherwise.
        """
        pass
    
    def convert_to_wav(file: UploadFile) -> bytes:
        """
        Converts audio to WAV format if needed.
        Returns WAV bytes.
        """
        pass
```

#### 2. ASR Service
**Responsibility:** Transcribe audio to text using external APIs

**Interface:**
```python
class ASRService:
    def transcribe(audio_bytes: bytes, language: str) -> TranscriptionResult:
        """
        Transcribes audio using Sarvam AI (primary) or Bhashini (fallback).
        Returns TranscriptionResult with text and confidence score.
        """
        pass
    
    def transcribe_sarvam(audio_bytes: bytes, language: str) -> TranscriptionResult:
        """Primary ASR using Sarvam AI"""
        pass
    
    def transcribe_bhashini(audio_bytes: bytes, language: str) -> TranscriptionResult:
        """Fallback ASR using Bhashini"""
        pass

class TranscriptionResult:
    text: str
    confidence: float
    language: str
```

#### 3. NLU Service (3-Tier Strategy)
**Responsibility:** Extract entities (name, amount, type) from transcribed text

**Interface:**
```python
class NLUService:
    def extract_entities(text: str, language: str) -> EntityExtractionResult:
        """
        Extracts entities using 3-tier strategy:
        1. Regex patterns (fastest)
        2. Keyword mapping (medium)
        3. LLM fallback (slowest, most flexible)
        """
        pass
    
    def extract_with_regex(text: str) -> Optional[EntityExtractionResult]:
        """Tier 1: Pattern-based extraction"""
        pass
    
    def extract_with_keywords(text: str) -> Optional[EntityExtractionResult]:
        """Tier 2: Keyword-based extraction"""
        pass
    
    def extract_with_llm(text: str) -> EntityExtractionResult:
        """Tier 3: LLM-based extraction"""
        pass

class EntityExtractionResult:
    name: str
    amount: float
    transaction_type: str  # "CREDIT" or "PAYMENT"
    confidence: float
```

#### 4. Voice Service API Endpoint

**POST /process-voice**

Request:
```
Content-Type: multipart/form-data
- audio: file (WAV/MP3)
- language: string (hi/ta/bn)
- user_id: string
```

Response:
```json
{
  "name": "Ramesh",
  "amount": 50.0,
  "type": "CREDIT",
  "confidence": 0.95,
  "transcription": "Ramesh ne 50 rupay udhaar liye"
}
```

### Banking Service Components

#### 1. Transaction Controller
**Responsibility:** Handle HTTP requests for transaction logging

**Interface:**
```java
@RestController
@RequestMapping("/api/transactions")
public class TransactionController {
    
    @PostMapping("/log")
    public ResponseEntity<TransactionResponse> logTransaction(
        @RequestBody TransactionRequest request,
        @RequestHeader("X-User-Id") String userId
    ) {
        // Validate request, process transaction, return response
    }
}

class TransactionRequest {
    String name;
    Double amount;
    String type;  // "CREDIT" or "PAYMENT"
    Double confidence;
    String transcription;
    String audioFilePath;
}

class TransactionResponse {
    boolean success;
    String message;
    String responseText;  // For voice synthesis
    Double updatedBalance;
}
```

#### 2. Customer Service
**Responsibility:** Manage customer records with fuzzy matching

**Interface:**
```java
public interface CustomerService {
    
    Customer findOrCreateCustomer(String name, String userId);
    
    Optional<Customer> fuzzyMatchCustomer(String name, String userId);
    
    Customer createCustomer(String name, String userId);
    
    List<Customer> getCustomersByUser(String userId);
}

class Customer {
    Long id;
    String name;
    String mobile;
    String userId;
    Double balance;
    LocalDateTime createdAt;
}
```

**Fuzzy Matching Algorithm:**
- Use Levenshtein distance for string similarity
- Threshold: 0.8 similarity score
- Consider phonetic matching for Indian names (Soundex-like algorithm)
- If multiple matches above threshold, return highest scoring match

#### 3. Transaction Service
**Responsibility:** Create transactions and update balances atomically

**Interface:**
```java
public interface TransactionService {
    
    @Transactional
    Transaction createTransaction(TransactionRequest request, String userId);
    
    void updateCustomerBalance(Long customerId, Double amount, String type);
    
    List<Transaction> getTransactionsByCustomer(Long customerId);
    
    Optional<Transaction> getTransactionById(Long transactionId);
}

class Transaction {
    Long id;
    Long customerId;
    String userId;
    Double amount;
    String type;  // "CREDIT" or "PAYMENT"
    String transcription;
    String audioFilePath;
    Double confidence;
    Boolean verified;
    LocalDateTime timestamp;
}
```

**Balance Update Logic:**
- CREDIT: balance += amount (customer owes more)
- PAYMENT: balance -= amount (customer pays back)
- Balance can go negative (overpayment scenario)

#### 4. WhatsApp Service
**Responsibility:** Send transaction alerts via WhatsApp

**Interface:**
```java
public interface WhatsAppService {
    
    void sendPaymentAlert(Customer customer, Transaction transaction);
    
    String formatMessage(Customer customer, Transaction transaction, String language);
}
```

**Message Templates:**
- Hindi: "Namaste {name}, aapka {amount} rupay ka payment mil gaya. Baaki raashi: {balance} rupay."
- Tamil: "Vanakkam {name}, ungal {amount} rupees payment kidaitthathu. Meedhi: {balance} rupees."
- Bengali: "Namaskar {name}, apnar {amount} taka payment peyechi. Baki: {balance} taka."

#### 5. Audio Storage Service
**Responsibility:** Store and retrieve audio files

**Interface:**
```java
public interface AudioStorageService {
    
    String saveAudio(byte[] audioData, String userId, Long transactionId);
    
    byte[] retrieveAudio(String filePath);
    
    void deleteAudio(String filePath);
}
```

**Storage Strategy:**
- File path pattern: `/audio/{userId}/{year}/{month}/{transactionId}.wav`
- Store in local filesystem initially (can migrate to S3/Cloud Storage later)
- Record file path in transactions table

## Data Models

### Database Schema

**users table:**
```sql
CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    shop_name VARCHAR(255) NOT NULL,
    mobile VARCHAR(15) UNIQUE NOT NULL,
    language VARCHAR(10) DEFAULT 'hi',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_mobile (mobile)
);
```

**customers table:**
```sql
CREATE TABLE customers (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    mobile VARCHAR(15),
    user_id BIGINT NOT NULL,
    balance DECIMAL(10, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_user_name (user_id, name)
);
```

**transactions table:**
```sql
CREATE TABLE transactions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    customer_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    type ENUM('CREDIT', 'PAYMENT') NOT NULL,
    transcription TEXT,
    audio_file_path VARCHAR(500),
    confidence DECIMAL(3, 2),
    verified BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_customer (customer_id),
    INDEX idx_user_timestamp (user_id, timestamp)
);
```

### Entity Relationships

- One User has many Customers (one-to-many)
- One User has many Transactions (one-to-many)
- One Customer has many Transactions (one-to-many)
- Each Transaction belongs to one Customer and one User

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*


### Core System Properties

**Property 1: Audio Transcription Completeness**
*For any* valid audio file in WAV or MP3 format, the Voice Service should produce a non-empty transcription with a confidence score between 0 and 1.
**Validates: Requirements 1.1, 3.4**

**Property 2: Entity Extraction Completeness**
*For any* transcribed text containing transaction information, the NLU Service should extract all three required fields (customer name, amount, transaction type) or return an error with confidence score 0.
**Validates: Requirements 1.2, 4.1, 4.7**

**Property 3: Transaction Creation with Audio Evidence**
*For any* valid entity extraction result, the Banking Service should create a transaction record that includes the audio file path and transcription text.
**Validates: Requirements 1.3, 6.1, 6.2, 15.1**

**Property 4: Balance Invariant**
*For any* customer, their balance should always equal the sum of all their CREDIT transactions minus the sum of all their PAYMENT transactions.
**Validates: Requirements 1.5, 6.4, 6.5, 11.6**

**Property 5: Multi-Language Support**
*For any* supported language (Hindi, Tamil, Bengali), the Voice Service should successfully process audio and the Banking Service should generate responses in that language.
**Validates: Requirements 1.6, 8.1, 8.3, 8.5**

**Property 6: Transaction Type Classification**
*For any* transaction phrase, the NLU Service should classify it as either CREDIT or PAYMENT based on linguistic markers (udhaar/liye vs jama/mil gaye).
**Validates: Requirements 2.1**

**Property 7: Payment Balance Reduction**
*For any* PAYMENT transaction, the customer's balance after the transaction should be less than or equal to their balance before the transaction by exactly the payment amount.
**Validates: Requirements 2.2**

**Property 8: WhatsApp Alert Triggering**
*For any* PAYMENT transaction where the customer has a mobile number, a WhatsApp alert should be sent (or attempted) with the transaction amount and updated balance.
**Validates: Requirements 2.3, 7.1, 7.2**

**Property 9: Audio Format Validation**
*For any* uploaded file, the Voice Service should accept WAV and MP3 formats and reject all other formats with an appropriate error.
**Validates: Requirements 3.1, 10.6**

**Property 10: Low Confidence Verification**
*For any* transcription or extraction result with confidence score below 0.7, the system should flag the transaction for user verification.
**Validates: Requirements 3.5**

**Property 11: Three-Tier NLU Strategy Order**
*For any* transcribed text, the NLU Service should attempt regex extraction first, then keyword mapping if regex fails, and finally LLM extraction if both fail.
**Validates: Requirements 4.2, 4.3, 4.4, 4.5**

**Property 12: Fuzzy Customer Matching**
*For any* extracted customer name, the Banking Service should perform fuzzy matching and link to an existing customer if similarity exceeds 0.8, otherwise create a new customer.
**Validates: Requirements 5.1, 5.2, 5.3**

**Property 13: New Customer Initialization**
*For any* newly created customer, their initial balance should be exactly 0.00.
**Validates: Requirements 5.6**

**Property 14: Transaction Persistence Completeness**
*For any* created transaction, all required fields (customer_id, user_id, amount, type, transcription, audio_file_path, confidence, verified, timestamp) should be persisted and retrievable from the database.
**Validates: Requirements 6.3, 6.6**

**Property 15: WhatsApp Message Localization**
*For any* WhatsApp alert, the message should be formatted in the customer's preferred language with appropriate templates.
**Validates: Requirements 7.5, 8.4**

**Property 16: WhatsApp Failure Resilience**
*For any* PAYMENT transaction, if WhatsApp delivery fails, the transaction should still complete successfully and the failure should be logged.
**Validates: Requirements 7.4**

**Property 17: User Language Preference Persistence**
*For any* shopkeeper registration, their language preference should be stored and used for all subsequent voice responses.
**Validates: Requirements 8.2, 8.3**

**Property 18: Confirmation Message Completeness**
*For any* successful transaction, the Banking Service should generate a confirmation message containing the customer name, transaction amount, and updated balance.
**Validates: Requirements 9.1, 9.2, 9.3**

**Property 19: Error Message Generation**
*For any* failed transaction, the Banking Service should generate a descriptive error message in the user's preferred language.
**Validates: Requirements 9.4, 13.6**

**Property 20: API Response Format Consistency**
*For any* request to /process-voice, the Voice Service should return JSON containing name, amount, type, confidence, and transcription fields.
**Validates: Requirements 10.2**

**Property 21: API Response Format Consistency (Banking)**
*For any* request to /api/transactions/log, the Banking Service should return JSON containing success, message, responseText, and updatedBalance fields.
**Validates: Requirements 10.4**

**Property 22: Input Validation**
*For any* request to the Banking Service, if required fields (user_id, name, amount, type) are missing or invalid, the request should be rejected with an appropriate error.
**Validates: Requirements 10.7**

**Property 23: Transaction Atomicity**
*For any* transaction creation attempt, either all database operations (transaction insert, balance update, audio storage path) succeed together or all are rolled back together.
**Validates: Requirements 11.2, 11.3, 13.3**

**Property 24: File Path Recording**
*For any* transaction with audio evidence, the audio file path should be recorded in the transactions table and the file should be retrievable using that path.
**Validates: Requirements 11.5, 15.3, 15.4**

**Property 25: User Data Isolation**
*For any* authenticated user, queries for customers and transactions should return only records associated with that user's user_id.
**Validates: Requirements 12.2, 12.3, 12.4**

**Property 26: Authorization Enforcement**
*For any* request with invalid or missing user_id, the Banking Service should reject the request with a 401 or 403 status code.
**Validates: Requirements 12.5**

**Property 27: Transcription Error Handling**
*For any* audio transcription failure, the Voice Service should return an error response with a descriptive message rather than throwing an unhandled exception.
**Validates: Requirements 13.1**

**Property 28: External Service Degradation**
*For any* external service failure (Sarvam AI, Bhashini, WhatsApp), the system should continue operating with degraded functionality rather than completely failing.
**Validates: Requirements 13.4**

**Property 29: Error Logging**
*For any* error condition, the system should create a log entry with sufficient detail for debugging (timestamp, error type, stack trace, context).
**Validates: Requirements 13.5**

**Property 30: Unique Audio Filenames**
*For any* two transactions, their audio file paths should be unique to prevent file collisions.
**Validates: Requirements 15.2**

**Property 31: Audio Storage Resilience**
*For any* transaction, if audio file storage fails, the transaction should still be created with a flag indicating missing audio evidence.
**Validates: Requirements 15.6**

### Edge Cases

The following edge cases should be handled by the property tests through appropriate test data generation:

- **Overpayment Scenario** (2.4): Generate payments exceeding customer balance, verify negative balances are handled
- **Ambiguous Customer Matching** (5.4): Generate similar customer names, verify clarification is requested
- **Extraction Failure** (4.6, 13.2): Generate unintelligible text, verify confidence score 0 and error handling

## Error Handling

### Voice Service Error Handling

**Audio Validation Errors:**
- Invalid file format → 400 Bad Request with message "Unsupported audio format. Please use WAV or MP3."
- File too large (>10MB) → 413 Payload Too Large
- Corrupted audio file → 422 Unprocessable Entity

**Transcription Errors:**
- Sarvam AI timeout → Automatic fallback to Bhashini
- Both ASR services fail → 503 Service Unavailable with message "Speech recognition services temporarily unavailable"
- Empty/silent audio → 422 Unprocessable Entity with message "No speech detected in audio"

**Extraction Errors:**
- No entities extracted → 200 OK with confidence: 0.0 and error message
- Ambiguous entities → 200 OK with low confidence score (<0.7)
- Invalid amount (negative, non-numeric) → 422 Unprocessable Entity

### Banking Service Error Handling

**Validation Errors:**
- Missing required fields → 400 Bad Request with field-specific error messages
- Invalid user_id → 401 Unauthorized
- Invalid transaction type → 400 Bad Request

**Business Logic Errors:**
- Customer not found and creation fails → 500 Internal Server Error
- Balance calculation overflow → 422 Unprocessable Entity
- Duplicate transaction detection → 409 Conflict

**Database Errors:**
- Connection failure → 503 Service Unavailable with retry-after header
- Transaction rollback → 500 Internal Server Error with rollback confirmation
- Constraint violation → 409 Conflict

**External Service Errors:**
- WhatsApp API failure → Log error, continue transaction (non-blocking)
- Audio storage failure → Log error, flag transaction, continue (non-blocking)

### Error Response Format

All errors follow a consistent JSON structure:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      "field": "Additional context"
    }
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Retry Strategy

- **Transient failures** (network timeouts, temporary service unavailability): Exponential backoff with 3 retries
- **Permanent failures** (validation errors, authentication failures): No retry, immediate error response
- **External service failures**: Circuit breaker pattern with 5-minute cooldown

## Testing Strategy

### Dual Testing Approach

The Bol-Khata system requires both unit tests and property-based tests for comprehensive coverage:

**Unit Tests** focus on:
- Specific examples of transaction phrases and expected extractions
- Edge cases (overpayment, ambiguous names, extraction failures)
- Integration points between Voice Service and Banking Service
- Error conditions and exception handling
- API contract validation

**Property-Based Tests** focus on:
- Universal properties that hold for all inputs (balance invariants, data persistence)
- Comprehensive input coverage through randomization
- Invariant validation across many scenarios
- Round-trip properties (serialization, database persistence)

### Property-Based Testing Configuration

**Python (Voice Service):**
- Library: Hypothesis
- Minimum iterations: 100 per property
- Tag format: `# Feature: bol-khata, Property {number}: {property_text}`

**Java (Banking Service):**
- Library: jqwik
- Minimum iterations: 100 per property
- Tag format: `// Feature: bol-khata, Property {number}: {property_text}`

### Test Coverage Requirements

**Voice Service Tests:**
1. Audio validation and format conversion
2. ASR integration with Sarvam AI and Bhashini (mocked)
3. Three-tier NLU strategy execution order
4. Entity extraction for various transaction phrases
5. Confidence score calculation
6. Error handling for transcription failures

**Banking Service Tests:**
1. Fuzzy customer matching algorithm
2. Balance calculation and updates
3. Transaction atomicity and rollback
4. WhatsApp alert triggering (mocked)
5. Audio file storage and retrieval
6. User data isolation and authorization
7. Multi-language response generation

### Integration Tests

**End-to-End Flow:**
1. Submit audio file → Voice Service → Banking Service → Database
2. Verify transaction created with correct balance update
3. Verify WhatsApp alert sent (mocked)
4. Verify audio evidence stored and retrievable

**Service Communication:**
1. Voice Service → Banking Service API contract
2. Error propagation between services
3. Timeout and retry behavior

### Test Data Generation

**For Property-Based Tests:**
- Generate random audio files (synthesized speech)
- Generate random transaction phrases in Hindi, Tamil, Bengali
- Generate random customer names with varying similarity scores
- Generate random amounts (including edge cases: 0, negative, very large)
- Generate random user_ids and customer_ids

**For Unit Tests:**
- Curated set of common transaction phrases
- Known edge cases (overpayment, ambiguous names)
- Specific error scenarios (invalid formats, missing fields)

### Mocking Strategy

**External Services to Mock:**
- Sarvam AI ASR API
- Bhashini ASR API
- WhatsApp Business API
- File system operations (for audio storage)

**Database:**
- Use H2 in-memory database for Java tests
- Use SQLite in-memory database for Python tests (if needed)

### Performance Testing

While not part of unit/property tests, the following performance tests should be conducted separately:

- Load testing: 100+ concurrent requests to Voice Service
- Load testing: 500+ concurrent requests to Banking Service
- Response time validation: <2 seconds end-to-end
- Database query optimization: <100ms for balance calculations

### Test Execution

**Continuous Integration:**
- Run all unit tests on every commit
- Run property-based tests on every pull request
- Run integration tests before deployment
- Generate code coverage reports (target: >80%)

**Local Development:**
- Fast unit tests run in <10 seconds
- Property tests run in <60 seconds
- Integration tests run in <2 minutes
