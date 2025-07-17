#!/bin/bash
# scripts/manage_models.sh

# Pull recommended models for oil & gas use case
# ollama pull llama3.2:latest          # General purpose, 3B parameters
# ollama pull mistral:7b-instruct      # Good for technical content
# ollama pull codellama:7b             # For code/script generation
# ollama pull phi3:medium              # Microsoft's model, good for documents
ollama pull llama2:7b 
ollama pull mistral:7b 

# Optional: Pull embedding model
ollama pull nomic-embed-text         # For document embeddings

echo "Models pulled successfully!"

# List all available models
echo "Available models:"
ollama list