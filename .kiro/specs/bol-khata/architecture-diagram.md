# Bol-Khata Architecture Diagrams

## High-Level System Architecture

```mermaid
graph TB
    User[Street Vendor<br/>Mobile/Web App]
    
    subgraph Voice["Voice Service (Python/FastAPI)"]
        Audio[Audio Handler]
        ASR[ASR Service<br/>Sarvam AI / Bhashini]
        NLU[3-Tier NLU<br/>Regex → Keywords → LLM]
    end
    
    subgraph Banking["Banking Service (Java/Spring Boot)"]
        API[Transaction Controller]
        Customer[Customer Service<br/>Fuzzy Matching]
        Transaction[Transaction Service]
        WhatsApp[WhatsApp Service]
        Storage[Audio Storage]
    end
    
    DB[(MySQL Database)]
    WA[WhatsApp Business API]
    
    User -->|Audio File| Audio
    Audio --> ASR
    ASR --> NLU
    NLU -->|JSON: name, amount, type| API
    API --> Customer
    Customer --> Transaction
    Transaction --> DB
    Transaction --> Storage
    Transaction --> WhatsApp
    WhatsApp --> WA
    WA -->|Payment Alert| User
    API -->|Voice Confirmation| User
```

## Detailed Voice Service Flow

```mermaid
graph LR
    Input[Audio Input<br/>WAV/MP3]
    
    subgraph ASR["Speech Recognition"]
        Sarvam[Sarvam AI<br/>Primary]
        Bhashini[Bhashini<br/>Fallback]
    end
    
    subgraph NLU["Natural Language Understanding"]
        Tier1[Tier 1: Regex<br/>Fast Pattern Match]
        Tier2[Tier 2: Keywords<br/>Medium Speed]
        Tier3[Tier 3: LLM<br/>Flexible AI]
    end
    
    Output[JSON Output<br/>name, amount, type, confidence]
    
    Input --> Sarvam
    Sarvam -.Timeout/Error.-> Bhashini
    Sarvam --> Tier1
    Bhashini --> Tier1
    Tier1 -.Fail.-> Tier2
    Tier2 -.Fail.-> Tier3
    Tier1 --> Output
    Tier2 --> Output
    Tier3 --> Output
```

## Banking Service Transaction Flow

```mermaid
sequenceDiagram
    participant VS as Voice Service
    participant API as Transaction API
    participant CS as Customer Service
    participant TS as Transaction Service
    participant DB as MySQL Database
    participant WA as WhatsApp Service
    participant Cust as Customer
    
    VS->>API: POST /api/transactions/log<br/>{name, amount, type}
    API->>CS: findOrCreateCustomer(name, userId)
    CS->>CS: Fuzzy Match (0.8 threshold)
    CS->>DB: Query/Insert Customer
    DB-->>CS: Customer Record
    CS-->>API: Customer ID
    
    API->>TS: createTransaction(data)
    TS->>DB: BEGIN TRANSACTION
    TS->>DB: INSERT transaction
    TS->>DB: UPDATE customer balance
    TS->>DB: COMMIT
    DB-->>TS: Success
    
    alt Payment Transaction
        TS->>WA: sendPaymentAlert(customer)
        WA->>Cust: WhatsApp Message
    end
    
    TS-->>API: Transaction Response
    API-->>VS: {success, message, balance}
```

## Customer Fuzzy Matching Algorithm

```mermaid
graph TD
    Start[Extract Customer Name]
    Query[Query Existing Customers<br/>for User]
    
    Match{Fuzzy Match<br/>Score > 0.8?}
    Multiple{Multiple<br/>Matches?}
    
    UseExisting[Link to Existing Customer]
    CreateNew[Create New Customer]
    AskUser[Request User Clarification]
    
    Start --> Query
    Query --> Match
    Match -->|Yes| Multiple
    Match -->|No| CreateNew
    Multiple -->|Single| UseExisting
    Multiple -->|Many| AskUser
    AskUser --> UseExisting
```

## Data Model Relationships

```mermaid
erDiagram
    USERS ||--o{ CUSTOMERS : "has many"
    USERS ||--o{ TRANSACTIONS : "creates"
    CUSTOMERS ||--o{ TRANSACTIONS : "has many"
    
    USERS {
        bigint id PK
        string shop_name
        string mobile UK
        string language
        timestamp created_at
    }
    
    CUSTOMERS {
        bigint id PK
        string name
        string mobile
        bigint user_id FK
        decimal balance
        timestamp created_at
    }
    
    TRANSACTIONS {
        bigint id PK
        bigint customer_id FK
        bigint user_id FK
        decimal amount
        enum type
        text transcription
        string audio_file_path
        decimal confidence
        boolean verified
        timestamp timestamp
    }
```

## Multi-Language Support Flow

```mermaid
graph LR
    Vendor[Shopkeeper<br/>Preferred Language]
    
    subgraph Input
        Hindi[Hindi Audio]
        Tamil[Tamil Audio]
        Bengali[Bengali Audio]
    end
    
    ASR[Language-Aware ASR]
    NLU[Multi-lingual NLU]
    
    subgraph Output
        HindiResp[Hindi Response]
        TamilResp[Tamil Response]
        BengaliResp[Bengali Response]
    end
    
    Vendor --> Hindi
    Vendor --> Tamil
    Vendor --> Bengali
    
    Hindi --> ASR
    Tamil --> ASR
    Bengali --> ASR
    
    ASR --> NLU
    
    NLU --> HindiResp
    NLU --> TamilResp
    NLU --> BengaliResp
    
    HindiResp --> Vendor
    TamilResp --> Vendor
    BengaliResp --> Vendor
```

## Error Handling & Fallback Strategy

```mermaid
graph TD
    Start[Receive Audio]
    
    Sarvam{Sarvam AI<br/>Available?}
    Bhashini{Bhashini<br/>Available?}
    
    Transcribe[Transcribe Audio]
    Extract[Extract Entities]
    
    LowConf{Confidence<br/>> 0.7?}
    
    Process[Process Transaction]
    Verify[Request User Verification]
    Error[Return Error<br/>Ask to Re-record]
    
    Start --> Sarvam
    Sarvam -->|Yes| Transcribe
    Sarvam -->|No| Bhashini
    Bhashini -->|Yes| Transcribe
    Bhashini -->|No| Error
    
    Transcribe --> Extract
    Extract --> LowConf
    LowConf -->|Yes| Process
    LowConf -->|No| Verify
    Verify --> Process
```

## Deployment Architecture (Future)

```mermaid
graph TB
    subgraph Internet
        Users[80M+ Street Vendors]
    end
    
    subgraph LoadBalancing
        LB[Load Balancer]
    end
    
    subgraph VoiceCluster["Voice Service Cluster"]
        VS1[Voice Service 1]
        VS2[Voice Service 2]
        VS3[Voice Service N]
    end
    
    subgraph BankingCluster["Banking Service Cluster"]
        BS1[Banking Service 1]
        BS2[Banking Service 2]
        BS3[Banking Service N]
    end
    
    subgraph Database
        Primary[(MySQL Primary)]
        Replica1[(MySQL Replica 1)]
        Replica2[(MySQL Replica 2)]
    end
    
    subgraph Storage
        S3[Audio Files<br/>S3/Cloud Storage]
    end
    
    Users --> LB
    LB --> VS1
    LB --> VS2
    LB --> VS3
    
    VS1 --> BS1
    VS2 --> BS2
    VS3 --> BS3
    
    BS1 --> Primary
    BS2 --> Primary
    BS3 --> Primary
    
    Primary --> Replica1
    Primary --> Replica2
    
    BS1 --> S3
    BS2 --> S3
    BS3 --> S3
```
