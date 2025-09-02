
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
