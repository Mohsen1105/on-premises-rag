#!/bin/bash
# k8s-simple/scripts/deploy.sh

echo "🚀 Deploying AI Assistant (CPU-only)"

# Apply the manifest
echo "📦 Creating resources..."
kubectl apply -f manifests/ai-assistant.yaml

# Wait for deployments
echo "⏳ Waiting for pods to be ready..."
kubectl -n ai-assistant wait --for=condition=available --timeout=300s deployment --all

# Pull CPU-optimized models
echo "📥 Loading CPU-optimized models..."
kubectl -n ai-assistant exec -it $(kubectl -n ai-assistant get pod -l app=ollama -o jsonpath='{.items[0].metadata.name}') -- bash -c "
ollama pull phi3:mini
ollama pull llama3.2:1b
ollama pull llama3.2:3b-instruct-q4_0
"

# Show status
echo "✅ Deployment complete!"
echo ""
kubectl -n ai-assistant get all
echo ""
echo "🌐 Access Open WebUI at: http://ai.company.local"
echo "📚 API Docs at: http://ai.company.local/api/docs"