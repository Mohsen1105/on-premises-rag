
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

<!-- Quick Start Commands -->
<!-- For CPU-only systems (like macOS): -->
bashdocker-compose up -d
<!-- For systems with NVIDIA GPU: -->
bashdocker-compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
<!-- Or use the smart script: -->
./start-ai-assistant.sh


# Test Ollama API
curl http://localhost:11434/api/tags

# Test from inside Open WebUI container
docker exec ai-webui curl http://ollama:11434/api/tags

# Check logs
docker-compose logs -f ollama
docker-compose logs -f open-webui



