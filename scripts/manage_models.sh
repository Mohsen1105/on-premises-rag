#!/bin/bash
# scripts/manage_models.sh

# Pull OpenAI open-source models for oil & gas use case
echo "Pulling OpenAI gpt-oss:20b model..."
docker exec ollama ollama pull gpt-oss:20b

# Keep phi3:mini for quick responses
echo "Pulling phi3:mini for quick responses..."
docker exec ollama ollama pull phi3:mini

# Keep llama3.2:3b for quick responses
echo "Pulling llama3.2:3b for quick responses..."
docker exec ollama ollama pull llama3.2:3b

# Optional: Pull embedding model if needed
# docker exec ollama ollama pull nomic-embed-text

echo "Models pulled successfully!"

# List all available models
echo "Available models:"
docker exec ollama ollama list