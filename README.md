# 🎤 BolKhata - Voice-First Financial Ledger

[![Live Demo](https://img.shields.io/badge/Live%20Demo-bolkhata.com-blue?style=for-the-badge)](https://bolkhata.com)
[![Deployment](https://img.shields.io/badge/Deployment-Vercel%20%2B%20Render-black?style=for-the-badge)](https://vercel.com)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

> A modern, voice-enabled financial ledger application designed for small shop owners in India. Record transactions using natural language in Hindi, Tamil, Bengali, Gujarati, or English!

## 🌟 Live Application

- **Primary**: [https://bolkhata.com](https://bolkhata.com)
- **WWW**: [https://www.bolkhata.com](https://www.bolkhata.com)
- **Vercel fallback**: `https://bol-khata.vercel.app`

### 🔗 Live Service URLs (Render)

- **Banking API (Spring Boot)**: `https://bolkhata-banking.onrender.com`
- **Voice API (FastAPI)**: `https://bolkhata-voice.onrender.com`

## 📖 Overview

BolKhata (बोल-खाता) means "Speak Your Ledger" in Hindi. It's a revolutionary financial management system that allows shopkeepers to record transactions using voice commands in their native language, eliminating the need for traditional paper ledgers.

### 🎯 Problem Statement

- 70% of small businesses in India still use paper ledgers
- Time-consuming manual bookkeeping
- High error rates in calculations
- Difficulty tracking outstanding payments
- Language barriers with English-only software

### ✨ Solution

BolKhata provides:
- 🎤 **Voice-First Interface** - Record transactions by speaking naturally
- 🌐 **Multi-Language Support** - Hindi, Tamil, Bengali, Gujarati, English
- 🤖 **AI-Powered** - Sarvam AI for speech recognition and NLU
- 📊 **Real-Time Analytics** - Dashboard with charts and insights
- 💰 **Smart Tracking** - Automatic balance calculations
- 📱 **Mobile-Friendly** - Works on any device
- ☁️ **Cloud-Based** - Accessible from anywhere

## 🚀 Features

### 1. Voice Entry
- Record transactions using natural speech
- Supports multiple Indian languages
- AI extracts customer name, amount, and transaction type
- Stores audio for future reference
- Real-time transcription and translation

### 2. Manual Entry
- Quick form-based transaction logging
- Three transaction types:
  - **Sale Paid** - Customer bought and paid immediately
  - **Sale on Credit** - Customer took goods on credit
  - **Payment Received** - Customer paid back previous credit

### 3. Dashboard
- Total customers count
- Total credit given
- Total payments received
- Outstanding balance
- Revenue trend charts (7/30/90 days)
- Transaction type distribution
- Recent transactions list
- Top customers by outstanding balance

### 4. Customer Management
- Complete customer database
- Outstanding balance tracking
- Risk scoring (Low/Medium/High)
- Edit customer details
- WhatsApp reminder integration
- Transaction history per customer

### 5. Transactions
- Complete audit trail
- Date/time stamps
- Customer names
- Transaction types with color-coded badges
- Audio playback for voice entries
- Search and filter capabilities

### 6. Passbook
- Customer-wise transaction history
- Running balance calculation
- Print/export functionality
- Traditional passbook format

## 🏗️ Architecture

### Tech Stack

**Frontend:**
- HTML5, CSS3, JavaScript (Vanilla)
- Chart.js for data visualization
- Responsive design (mobile-first)

**Backend:**
- Java 17 with Spring Boot 3.2.0
- RESTful API architecture
- Maven for dependency management

**Voice Service:**
- Python 3.11 with FastAPI
- Sarvam AI for speech-to-text
- Custom NLU for entity extraction
- Multi-language translation

**Database:**
- PostgreSQL (managed)
- Optimized schema with indexes
- pg_trgm extension for fuzzy search

**Infrastructure:**
- **Vercel** (frontend hosting)
- **Render** (banking-service + voice-service)
- **Domain**: registered in AWS Route 53 (registrar), DNS hosted on Cloudflare (free tier)

### System Architecture

```
┌─────────────┐
│   Browser   │
│  (HTTPS)    │
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│      Vercel      │
│  Static Frontend │
└───────┬──────────┘
        │
        ▼
┌──────────────────┐      ┌──────────────────┐
│ Render: Banking  │      │  Render: Voice   │
│ Spring Boot API  │      │    FastAPI       │
└────────┬─────────┘      └────────┬─────────┘
         │                          │
         ▼                          ▼
     PostgreSQL                 Sarvam AI
```

## 📦 Installation

### Prerequisites

- Java 17+
- Python 3.11+
- PostgreSQL 15+
- Maven 3.8+
- Node.js (optional, for development)

### Local Development Setup

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/bolkhata.git
cd bolkhata
```

2. **Setup Database**
```bash
# Create database
createdb bol_khata

# Run schema
psql -d bol_khata -f database/init-schema.sql
```

3. **Configure Banking Service**
```bash
cd banking-service
cp src/main/resources/application.properties.example src/main/resources/application.properties
# Edit application.properties with your database credentials
```

4. **Configure Voice Service**
```bash
cd voice-service
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your Sarvam AI API key
```

5. **Run Services**

Terminal 1 - Banking Service:
```bash
cd banking-service
mvn spring-boot:run
```

Terminal 2 - Voice Service:
```bash
cd voice-service
uvicorn app.main:app --reload --port 8000
```

Terminal 3 - Frontend (optional):
```bash
cd web-ui
python -m http.server 8081
```

6. **Access Application**
- Frontend: http://localhost:8081
- Banking API: http://localhost:8080/api
- Voice API: http://localhost:8000

## 🚀 Deployment (Current: Vercel + Render)

### Frontend (Vercel)

- Deploy the static UI from `web-ui/`
- Configure the Banking API base URL and Voice API base URL as:
  - **Banking**: `https://bolkhata-banking.onrender.com/api`
  - **Voice**: `https://bolkhata-voice.onrender.com`

### Backend (Render)

- Deploy `banking-service` (Spring Boot) as a Render Web Service
- Deploy `voice-service` (FastAPI) as a Render Web Service

### Custom domain

- Domain registered in **Route 53**
- DNS hosted on **Cloudflare Free**
- Domain routed to Vercel via:
  - `A @ -> 76.76.21.21`
  - `CNAME www -> cname.vercel-dns.com`

## 🚀 AWS Deployment (Legacy)

This repo previously supported an AWS-based deployment (EC2/RDS/S3/Nginx/Route53). If you want to reproduce that setup, keep using the existing scripts and docs.

### Quick Deploy

```bash
# 1. Create AWS resources
./scripts/01-create-vpc.sh
./scripts/02-create-s3-bucket.sh
./scripts/04-initialize-database.sh
./scripts/07-create-ec2-instance.sh

# 2. Deploy application
./scripts/08-deploy-to-ec2.sh

# 3. Setup domain and HTTPS
./scripts/17-setup-route53-domain.sh
./scripts/19-setup-https.sh
```

## 📚 API Documentation

### Banking Service Endpoints

**Authentication:**
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - User login

**Transactions:**
- `GET /api/transactions` - Get all transactions
- `POST /api/transactions/log` - Create transaction
- `GET /api/transactions/customers` - Get customers (legacy helper)

**Customers:**
- `GET /api/customers` - Get all customers
- `PUT /api/customers/{id}` - Update customer

**Statistics:**
- `GET /api/statistics` - Get dashboard statistics

**Audio:**
- `GET /api/audio/{userId}/{year}/{month}/{filename}` - Stream audio file

### Voice Service Endpoints

- `GET /health` - Health check
- `POST /process-voice` - Process voice recording
- `POST /process-text` - Process text input (testing)

## 🎤 Voice Commands Examples

**English:**
- "Rahul gave 500 rupees"
- "Priya took 300 rupees on credit"
- "Amit paid 200 rupees cash"

**Hindi:**
- "राहुल ने 500 रुपये दिए"
- "प्रिया ने 300 रुपये उधार लिए"

**Tamil:**
- "ராகுல் 500 ரூபாய் கொடுத்தார்"

## 🔒 Security

- HTTPS (Vercel/Render managed)
- Password hashing (planned; see code notes)
- SQL injection prevention
- CORS configuration
- Input validation and sanitization
- Secure session management

## 🧪 Testing

```bash
# Backend tests
cd banking-service
mvn test

# Voice service tests
cd voice-service
pytest
```

## 📊 Performance

- Average response time: <200ms
- Voice processing: 2-3 seconds
- Supports 100+ concurrent users
- Uptime depends on the current hosting provider (Vercel/Render)

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Team

- **Developer:** Sumit Mondal
- **Email:** mondalsumit648@gmail.com
- **GitHub:** [@yourusername](https://github.com/yourusername)

## 🙏 Acknowledgments

- [Sarvam AI](https://www.sarvam.ai/) for speech recognition API
- [Spring Boot](https://spring.io/projects/spring-boot) for backend framework
- [FastAPI](https://fastapi.tiangolo.com/) for voice service
- [Vercel](https://vercel.com/) and [Render](https://render.com/) for hosting

## 📞 Support

For issues, questions, or suggestions:
- 📧 Email: mondalsumit648@gmail.com
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/bolkhata/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/yourusername/bolkhata/discussions)

## 🗺️ Roadmap

- [ ] Mobile apps (Android/iOS)
- [ ] WhatsApp bot integration
- [ ] SMS notifications
- [ ] Multi-shop support
- [ ] Inventory management
- [ ] GST compliance
- [ ] Export to Tally
- [ ] Offline mode with sync
- [ ] Advanced analytics
- [ ] Payment gateway integration

## 📸 Screenshots

### Dashboard
![Dashboard](docs/screenshots/dashboard.png)

### Voice Entry
![Voice Entry](docs/screenshots/voice-entry.png)

### Customer Management
![Customers](docs/screenshots/customers.png)

---

**Made with ❤️ for small businesses in India**

**Live Demo:** [https://bolkhata.com](https://bolkhata.com)
