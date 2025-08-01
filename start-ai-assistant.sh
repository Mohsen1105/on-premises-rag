#!/bin/bash
# File: start-ai-assistant.sh

echo "Starting AI Assistant..."

# Function to check if NVIDIA GPU is available
check_gpu() {
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            return 0  # GPU available
        fi
    fi
    return 1  # GPU not available
}

# Clean up any existing services
echo "Cleaning up existing services..."
docker-compose down 2>/dev/null

# Check for GPU and start services accordingly
if check_gpu; then
    echo "✅ NVIDIA GPU detected! Starting with GPU support..."
    docker-compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
else
    echo "ℹ️  No NVIDIA GPU detected. Starting with CPU only..."
    docker-compose up -d
fi

# Wait for services to start
echo "Waiting for services to start..."
sleep 10

# Check service status
echo -e "\n📊 Service Status:"
docker-compose ps

# Pull default models
echo -e "\n📦 Pulling default models..."
docker exec ai-ollama ollama pull llama3.2:latest
docker exec ai-ollama ollama pull phi3:mini

echo -e "\n✅ AI Assistant is ready!"
echo "🌐 Open WebUI: http://localhost:8080"
echo "📚 API Docs: http://localhost:8000/docs"
echo "🔍 View logs: docker-compose logs -f"