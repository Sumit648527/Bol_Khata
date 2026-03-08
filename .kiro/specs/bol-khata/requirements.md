# Requirements Document

## Introduction

Bol-Khata is a voice-first financial ledger system designed for 80 million+ semi-literate street vendors in India. The system enables vendors to record credit transactions (udhaar) and payments (jama) by speaking in their local dialect, eliminating the need for typing or literacy. The system uses government-aligned speech recognition technology (Bhashini/Sarvam AI) and provides audio evidence for each transaction.

## Key Features

### 1. Voice-First Transaction Recording
Record credit (udhaar) and payment (jama) transactions by simply speaking in your local dialect - no typing required.

**Visual Suggestion:** Illustration of a street vendor speaking into a mobile phone with speech waves, showing the transformation from voice to text to ledger entry.

### 2. Multi-Dialect Support
Supports Hindi, Tamil, and Bengali dialects, including code-mixed speech (Hinglish, Tanglish).

**Visual Suggestion:** Map of India highlighting the three supported language regions with language icons, or a diagram showing different speech bubbles in different scripts converging into one system.

### 3. Intelligent Customer Recognition
Automatically matches customer names using fuzzy matching, even when pronounced differently.

**Visual Suggestion:** Flowchart showing "Ramesh" → "Ramsh" → "Ramesh Kumar" with similarity scores, demonstrating the fuzzy matching algorithm.

### 4. Audio Evidence for Every Transaction
Every transaction is backed by the original audio recording for dispute resolution.

**Visual Suggestion:** Icon of a microphone with a lock/shield, or a timeline showing transaction → audio file → secure storage.

### 5. Instant Voice Confirmations
Hear transaction confirmations spoken back in your preferred language within 2 seconds.

**Visual Suggestion:** Circular flow diagram: Voice Input → Processing → Voice Confirmation, with a 2-second timer indicator.

### 6. Automatic WhatsApp Alerts
Customers receive instant WhatsApp notifications when payments are recorded, in their preferred language.

**Visual Suggestion:** Mobile phone mockup showing a WhatsApp message with transaction details in Hindi/Tamil/Bengali.

### 7. Real-Time Balance Tracking
Automatic balance calculations with every transaction - always know who owes what.

**Visual Suggestion:** Dashboard mockup showing customer list with color-coded balances (red for outstanding, green for paid).

### 8. Smart 3-Tier Language Processing
Uses regex patterns, keyword mapping, and AI fallback to understand natural speech accurately.

**Visual Suggestion:** Pyramid or layered diagram showing three tiers: Regex (fast) → Keywords (medium) → AI (flexible), with accuracy/speed indicators.

### 9. Government-Aligned Technology
Built on Bhashini and Sarvam AI - government-supported speech recognition platforms.

**Visual Suggestion:** Logo badges or certification icons for Bhashini and Sarvam AI with "Government Aligned" badge.

### 10. Secure & Private
Your customer data is completely private - other shopkeepers cannot access your information.

**Visual Suggestion:** Icon showing multiple user profiles with locks/barriers between them, emphasizing data isolation.

### 11. Handles Edge Cases Gracefully
Manages overpayments, ambiguous names, and low-confidence transcriptions with user verification.

**Visual Suggestion:** Decision tree or flowchart showing how the system handles edge cases with verification checkpoints.

### 12. Scalable Architecture
Microservices-based design can handle millions of concurrent users across India.

**Visual Suggestion:** Architecture diagram showing Voice Service + Banking Service with horizontal scaling arrows, or a map of India with distributed service nodes.

### 13. Offline-First Audio Storage
Audio files stored locally with cloud backup capability for reliability.

**Visual Suggestion:** Diagram showing local storage (phone icon) syncing to cloud storage with bidirectional arrows.

### 14. Fast Performance
2-second end-to-end processing from voice input to confirmation.

**Visual Suggestion:** Timeline graphic showing the journey from voice input to confirmation with time markers at each stage.

### 15. Resilient Error Handling
Continues operating even when external services fail - never lose a transaction.

**Visual Suggestion:** Network diagram showing primary and fallback paths (Sarvam AI → Bhashini fallback) with checkmarks and X marks.

## Glossary

- **Bol_Khata_System**: The complete voice-first financial ledger application
- **Voice_Service**: Python microservice handling speech-to-text and intent extraction
- **Banking_Service**: Java microservice handling database operations and business logic
- **Shopkeeper**: A street vendor who uses the system to track customer credit
- **Customer**: A person who buys goods on credit from a shopkeeper
- **Transaction**: A ledger entry recording either credit given or payment received
- **Udhaar**: Hindi term for credit given to a customer
- **Jama**: Hindi term for payment received from a customer
- **ASR**: Automatic Speech Recognition (speech-to-text conversion)
- **NLU**: Natural Language Understanding (intent and entity extraction)
- **Audio_Evidence**: The original audio recording of a transaction
- **Transcription**: Text representation of the spoken audio
- **Confidence_Score**: Numerical measure (0-1) of transcription accuracy
- **Fuzzy_Match**: Approximate string matching for customer names
- **Verification_Status**: Boolean flag indicating if user confirmed the transaction

## Requirements

### Requirement 1: Voice Transaction Recording

**User Story:** As a shopkeeper, I want to record credit transactions by speaking naturally in my dialect, so that I can track customer debts without typing.

#### Acceptance Criteria

1. WHEN a shopkeeper speaks a credit transaction, THE Voice_Service SHALL transcribe the audio into text
2. WHEN the transcription is complete, THE Voice_Service SHALL extract the customer name, amount, and transaction type
3. WHEN extraction succeeds, THE Banking_Service SHALL create a transaction record with the audio evidence
4. WHEN the transaction is recorded, THE Bol_Khata_System SHALL respond with voice confirmation in the shopkeeper's language
5. WHEN a transaction is created, THE Banking_Service SHALL update the customer's outstanding balance
6. THE Voice_Service SHALL support Hindi, Tamil, and Bengali dialects

### Requirement 2: Payment Recording

**User Story:** As a shopkeeper, I want to record payments received by speaking, so that I can update customer balances when they pay their debts.

#### Acceptance Criteria

1. WHEN a shopkeeper speaks a payment transaction, THE Voice_Service SHALL identify it as a PAYMENT type
2. WHEN a payment is processed, THE Banking_Service SHALL reduce the customer's outstanding balance
3. WHEN the balance is updated, THE Banking_Service SHALL send a WhatsApp alert to the customer
4. WHEN the payment amount exceeds the outstanding balance, THE Bol_Khata_System SHALL handle the overpayment gracefully
5. WHEN a payment is recorded, THE Bol_Khata_System SHALL respond with the updated balance via voice

### Requirement 3: Speech Recognition and Transcription

**User Story:** As a shopkeeper, I want the system to understand my local dialect accurately, so that my transactions are recorded correctly.

#### Acceptance Criteria

1. THE Voice_Service SHALL accept audio files in WAV and MP3 formats
2. WHEN transcribing audio, THE Voice_Service SHALL use Sarvam AI as the primary ASR provider
3. WHERE Sarvam AI is unavailable, THE Voice_Service SHALL fall back to Bhashini API
4. WHEN transcription completes, THE Voice_Service SHALL return a confidence score between 0 and 1
5. WHEN the confidence score is below 0.7, THE Bol_Khata_System SHALL request user verification
6. THE Voice_Service SHALL process typical transactions within 2 seconds
7. THE Voice_Service SHALL achieve transcription accuracy above 95% for common transaction phrases

### Requirement 4: Natural Language Understanding

**User Story:** As a shopkeeper, I want the system to extract transaction details from my natural speech, so that I don't need to follow rigid command formats.

#### Acceptance Criteria

1. WHEN processing transcribed text, THE Voice_Service SHALL extract customer name, amount, and transaction type
2. THE Voice_Service SHALL use a three-tier extraction strategy: regex patterns, keyword mapping, then LLM fallback
3. WHEN regex patterns match, THE Voice_Service SHALL extract entities without invoking the LLM
4. WHEN regex fails and keywords are detected, THE Voice_Service SHALL use keyword mapping for extraction
5. WHEN both regex and keywords fail, THE Voice_Service SHALL invoke an LLM for entity extraction
6. WHEN extraction fails completely, THE Voice_Service SHALL return an error with confidence score 0
7. THE Voice_Service SHALL return extracted data as JSON with name, amount, type, and confidence fields

### Requirement 5: Customer Management

**User Story:** As a shopkeeper, I want the system to recognize my customers even when I pronounce their names slightly differently, so that transactions are linked to the correct person.

#### Acceptance Criteria

1. WHEN a customer name is extracted, THE Banking_Service SHALL perform fuzzy matching against existing customers
2. WHEN fuzzy match confidence exceeds 0.8, THE Banking_Service SHALL link the transaction to the matched customer
3. WHEN no match is found, THE Banking_Service SHALL create a new customer record
4. WHEN multiple customers match with similar confidence, THE Banking_Service SHALL request user clarification
5. THE Banking_Service SHALL store customer records with name, mobile number, and shopkeeper association
6. WHEN a new customer is created, THE Banking_Service SHALL initialize their balance to zero

### Requirement 6: Transaction Ledger Management

**User Story:** As a shopkeeper, I want all transactions stored with audio evidence, so that I can verify past transactions if disputes arise.

#### Acceptance Criteria

1. WHEN a transaction is created, THE Banking_Service SHALL store the original audio file
2. WHEN storing a transaction, THE Banking_Service SHALL record the transcription text
3. WHEN a transaction is saved, THE Banking_Service SHALL include timestamp, customer ID, amount, type, and verification status
4. THE Banking_Service SHALL maintain a running balance for each customer
5. WHEN calculating balances, THE Banking_Service SHALL treat CREDIT transactions as positive and PAYMENT transactions as negative
6. THE Banking_Service SHALL persist all transaction data to MySQL database

### Requirement 7: WhatsApp Notifications

**User Story:** As a customer, I want to receive WhatsApp alerts when payments are recorded, so that I have confirmation of my payment.

#### Acceptance Criteria

1. WHEN a PAYMENT transaction is recorded, THE Banking_Service SHALL send a WhatsApp message to the customer
2. WHEN sending WhatsApp alerts, THE Banking_Service SHALL include transaction amount and updated balance
3. WHERE a customer has no mobile number, THE Banking_Service SHALL skip the WhatsApp alert
4. WHEN WhatsApp delivery fails, THE Banking_Service SHALL log the failure but complete the transaction
5. THE Banking_Service SHALL format WhatsApp messages in the customer's preferred language

### Requirement 8: Multi-Language Support

**User Story:** As a shopkeeper, I want to interact with the system in my preferred language, so that I can use it comfortably.

#### Acceptance Criteria

1. THE Bol_Khata_System SHALL support Hindi, Tamil, and Bengali dialects
2. WHEN a shopkeeper registers, THE Banking_Service SHALL store their language preference
3. WHEN generating voice responses, THE Bol_Khata_System SHALL use the shopkeeper's preferred language
4. WHEN formatting WhatsApp messages, THE Banking_Service SHALL use the customer's preferred language
5. THE Voice_Service SHALL handle code-mixed speech (Hinglish, Tanglish)

### Requirement 9: Voice Response Generation

**User Story:** As a shopkeeper, I want to hear transaction confirmations spoken back to me, so that I know the system understood correctly without looking at the screen.

#### Acceptance Criteria

1. WHEN a transaction is successfully recorded, THE Banking_Service SHALL generate a confirmation message
2. WHEN generating confirmations, THE Banking_Service SHALL include customer name, amount, and updated balance
3. THE Banking_Service SHALL return the confirmation text to be converted to speech
4. WHEN a transaction fails, THE Banking_Service SHALL generate an error message explaining the failure
5. THE Bol_Khata_System SHALL deliver voice responses within 2 seconds of receiving audio input

### Requirement 10: API Integration Between Services

**User Story:** As a system architect, I want clear API contracts between the Python and Java services, so that they can be developed and scaled independently.

#### Acceptance Criteria

1. THE Voice_Service SHALL expose a POST /process-voice endpoint accepting multipart audio files
2. WHEN the Voice_Service processes audio, it SHALL return JSON with name, amount, type, confidence, and transcription
3. THE Banking_Service SHALL expose a POST /api/transactions/log endpoint accepting JSON transaction data
4. WHEN the Banking_Service logs a transaction, it SHALL return JSON with success status and response message
5. WHEN API calls fail, both services SHALL return appropriate HTTP status codes and error messages
6. THE Voice_Service SHALL validate audio file format before processing
7. THE Banking_Service SHALL validate required fields (user_id, name, amount, type) before creating transactions

### Requirement 11: Data Persistence and Integrity

**User Story:** As a system administrator, I want all financial data stored reliably in MySQL, so that no transactions are lost.

#### Acceptance Criteria

1. THE Banking_Service SHALL use MySQL as the single source of truth for all data
2. WHEN a transaction is created, THE Banking_Service SHALL persist it within a database transaction
3. WHEN database operations fail, THE Banking_Service SHALL roll back changes and return an error
4. THE Banking_Service SHALL maintain referential integrity between users, customers, and transactions tables
5. WHEN storing audio files, THE Banking_Service SHALL save file paths in the transactions table
6. THE Banking_Service SHALL ensure balance calculations are atomic and consistent

### Requirement 12: User Authentication and Authorization

**User Story:** As a shopkeeper, I want my transaction data to be private, so that other shopkeepers cannot see my customer information.

#### Acceptance Criteria

1. WHEN accessing the system, THE Bol_Khata_System SHALL require user authentication
2. WHEN a shopkeeper logs a transaction, THE Banking_Service SHALL associate it with their user_id
3. WHEN retrieving customer data, THE Banking_Service SHALL filter by the authenticated shopkeeper's user_id
4. WHEN querying transactions, THE Banking_Service SHALL return only transactions belonging to the authenticated user
5. THE Banking_Service SHALL reject requests with invalid or missing user_id

### Requirement 13: Error Handling and Recovery

**User Story:** As a shopkeeper, I want clear error messages when something goes wrong, so that I know what to do next.

#### Acceptance Criteria

1. WHEN audio transcription fails, THE Voice_Service SHALL return an error with a descriptive message
2. WHEN entity extraction fails, THE Voice_Service SHALL return confidence score 0 and suggest re-recording
3. WHEN database operations fail, THE Banking_Service SHALL return an error without partial updates
4. WHEN external services (Sarvam AI, Bhashini, WhatsApp) are unavailable, THE Bol_Khata_System SHALL degrade gracefully
5. WHEN errors occur, THE Bol_Khata_System SHALL log detailed error information for debugging
6. THE Bol_Khata_System SHALL provide voice error messages in the user's preferred language

### Requirement 14: Performance and Scalability

**User Story:** As a system administrator, I want the system to handle thousands of concurrent users, so that it can serve the target market of 80 million vendors.

#### Acceptance Criteria

1. THE Voice_Service SHALL process audio files within 2 seconds for typical transactions
2. THE Banking_Service SHALL respond to transaction logging requests within 500 milliseconds
3. WHEN load increases, THE Bol_Khata_System SHALL scale horizontally by adding service instances
4. THE Voice_Service SHALL handle at least 100 concurrent audio processing requests
5. THE Banking_Service SHALL handle at least 500 concurrent transaction requests
6. WHEN services are under load, THE Bol_Khata_System SHALL maintain response times within acceptable limits

### Requirement 15: Audio Evidence Storage

**User Story:** As a shopkeeper, I want to replay the original audio of any transaction, so that I can resolve disputes with customers.

#### Acceptance Criteria

1. WHEN a transaction is created, THE Banking_Service SHALL store the audio file in persistent storage
2. THE Banking_Service SHALL generate unique filenames for audio files to prevent collisions
3. WHEN storing audio, THE Banking_Service SHALL record the file path in the transactions table
4. THE Banking_Service SHALL support retrieval of audio files by transaction ID
5. THE Banking_Service SHALL retain audio files for at least 1 year
6. WHEN audio storage fails, THE Banking_Service SHALL still create the transaction but flag missing audio
