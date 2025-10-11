
# If Ollama is NOT in Docker
<!-- 1. Make sure Ollama is listening on all interfaces: -->
        # Set environment variable before starting Ollama
        export OLLAMA_HOST=0.0.0.0:11434
        # Or start with:
        ollama serve

<!-- 2. Update docker-compose.yml: -->
        open-webui:
        environment:
            # For Linux
            - OLLAMA_BASE_URL=http://host.docker.internal:11434
            # If that doesn't work, use your actual IP
            # - OLLAMA_BASE_URL=http://172.17.0.1:11434  # Docker bridge IP
        extra_hosts:
            - "host.docker.internal:host-gateway"  # This helps with host resolution


docker-compose up -d

# Open-web ui
user : mohsen110561@gmail.com
pass : 12345678

# n8n 
Email : mohsen110561@gmail.com
User : Moaiedipour
pass : M12345678

# n8n / postgres
Host : postgres
Database : n8n
User : root
pass : 123

# download models inside the ollama
docker exec ollama ollama pull gpt-oss:20b

# Check if Ollama API is accessible and returns models
curl -s http://localhost:11434/api/tags | jq .



## Supabase Vector Store Configuration

### Quick Start
All services are pre-configured. Simply run:
```bash
docker-compose up -d
```

### Connection Details for n8n Supabase Vector Store Node

**Method 1: Using Environment Variables (Recommended)**
- **Host**: `postgres` or `postgres:5432`
- **Service Role Secret**: `Mf7fNdtyz1SHZVNHdnntdr/SnfPRc9eUKheCpK7DAGU=`
- **Embedding Batch Size**: `100`

**Method 2: Direct PostgreSQL Connection**
- **Host**: `postgres`
- **Port**: `5432`
- **Database**: `n8n`
- **User**: `root`
- **Password**: `123`
- **Schema**: `vectors`
- **Table**: `documents`

### Vector Store Features
- ✅ **pgvector Extension**: v0.8.1 enabled
- ✅ **Embedding Dimensions**: 3072 (text-embedding-3-large compatible)
- ✅ **Schema**: Automatically created on first run
- ✅ **Environment Variables**: Pre-configured in docker-compose.yml

### Important Notes
1. **No Index for >2000 Dimensions**: pgvector doesn't support indexes for embeddings >2000 dimensions
   - Searches use sequential scan (acceptable for moderate datasets)
   - For better performance with large datasets, consider text-embedding-3-small (1536 dimensions)

2. **Connection String**:
   ```
   postgresql://root:123@postgres:5432/n8n
   ```

3. **All services have access to Supabase environment variables**:
   - `SUPABASE_HOST=postgres:5432`
   - `SUPABASE_SERVICE_ROLE_KEY=Mf7fNdtyz1SHZVNHdnntdr/SnfPRc9eUKheCpK7DAGU=`
   - `SUPABASE_CONNECTION_STRING=postgresql://root:123@postgres:5432/n8n`

### Testing the Setup
```bash
# Verify pgvector extension
docker exec on-premises-rag-postgres-1 psql -U root -d n8n -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';"

# Check table structure
docker exec on-premises-rag-postgres-1 psql -U root -d n8n -c "\d vectors.documents"

# Verify environment variables in n8n
docker exec ai-n8n env | grep SUPABASE
```
