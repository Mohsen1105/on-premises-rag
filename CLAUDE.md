# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is an on-premises RAG (Retrieval-Augmented Generation) system designed for oil and gas companies. The system provides AI-powered assistance for technical documentation, operational reports, and correspondence management using local LLMs through Ollama.

## Common Development Commands

### Starting the system
```bash
docker-compose up -d
```

### Stopping the system
```bash
docker-compose down
```

### Managing models
```bash
# Pull and setup models
./scripts/manage_models.sh

# View available models
ollama list
```

### Backup and restore
```bash
# Create backup
./scripts/backup.sh

# Restore from backup
cd /backup/ai-assistant/[timestamp]
./restore.sh
```

### Development workflow
```bash
# API development (FastAPI with hot reload)
docker-compose restart api

# View logs
docker-compose logs -f api
docker-compose logs -f ollama
```

## Architecture Overview

### Core Components
- **FastAPI Backend** (`api/`) - Main API service with RAG capabilities
- **Ollama** - Local LLM runtime for inference
- **ChromaDB** - Vector database for document embeddings
- **Redis** - Caching layer for responses
- **Open WebUI** - User interface for interacting with models
- **Nginx** - Reverse proxy and SSL termination

### Key Services
- **api** (port 8000) - FastAPI backend with RAG endpoints
- **ollama** (port 11434) - LLM inference service
- **chromadb** (port 8001) - Vector database
- **redis** (port 6379) - Cache service
- **open-webui** (port 8080) - User interface
- **nginx** (ports 80/443) - Reverse proxy

### Document Processing Pipeline
1. **DocumentProcessor** (`api/document_processor.py`) - Handles PDF, DOCX, and Excel files
2. **Text Chunking** - Uses RecursiveCharacterTextSplitter (1000 chars, 200 overlap)
3. **Embeddings** - Sentence Transformers (all-MiniLM-L6-v2)
4. **Vector Storage** - ChromaDB collections

### Use Cases
- **Technical Manual Assistant** (`api/use_cases/technical_manual.py`) - Equipment documentation queries
- **Report Summarizer** (`api/use_cases/report_summarizer.py`) - Daily operational report summaries
- **Correspondence Assistant** (`api/use_cases/correspondence.py`) - Email/letter drafting

## Model Configuration

### Available Models (defined in `models/models.yml`)
- **llama3.2:latest** - General purpose (3.5GB RAM, 4K context)
- **mistral:7b-instruct** - Technical documentation (5GB RAM, 8K context)
- **codellama:7b** - Code generation (5GB RAM, 16K context)
- **phi3:mini** - Quick responses (2.5GB RAM, 4K context)

### Model Selection Strategy
- Use `mistral:7b-instruct` for technical queries and correspondence
- Use `llama3.2:latest` for general queries and summaries
- Use `codellama:7b` for SQL generation and scripting
- Use `phi3:mini` for high-volume, quick responses

## Database Integration

### Supported Databases
- **SQL Server** - Primary operational database
- **Oracle** - Legacy system integration

### Database Connectors
- Connection strings via environment variables
- Context managers for connection pooling
- Pandas integration for data processing

## Security Considerations
- Token-based authentication (implement LDAP/AD integration)
- Environment variables for sensitive data
- SSL/TLS termination at nginx level
- No model training data leaves the premises

## Environment Variables
```bash
# Required
WEBUI_SECRET_KEY=your-secret-key
DATABASE_URL=your-database-url
ORACLE_DSN=your-oracle-dsn

# Optional
SQL_SERVER_CONN_STRING=your-sql-server-connection
ORACLE_USER=your-oracle-user
ORACLE_PASSWORD=your-oracle-password
```

## Development Notes

### API Endpoints
- `POST /api/query` - RAG-enabled queries
- `POST /api/documents/upload` - Document indexing
- `GET /api/models` - Available models

### ChromaDB Collections
- `default` - General documents
- `technical_manuals` - Equipment documentation
- `correspondence_history` - Past correspondence examples
- `knowledge_base` - Company knowledge base

### GPU Requirements
- NVIDIA GPU required for optimal performance
- GPU access configured in docker-compose.yml
- Ollama configured for GPU acceleration

### Performance Optimization
- Redis caching for frequent queries
- Configurable model loading (max 2 models, 30m keep-alive)
- Parallel processing support (4 concurrent requests)

## File Structure
```
api/
├── main.py                 # FastAPI application
├── document_processor.py   # Document handling
├── database_connectors.py  # Database integration
├── auth.py                 # Authentication
├── gpu_optimizer.py        # GPU optimization
├── health_check.py         # Health monitoring
└── use_cases/             # Domain-specific assistants
    ├── technical_manual.py
    ├── report_summarizer.py
    └── correspondence.py
```