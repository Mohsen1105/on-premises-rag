#!/bin/bash
# k8s-simple/scripts/deploy-with-models.sh

set -e

echo "🚀 Deploying AI Assistant with Model Loading"
echo "=========================================="

# Deploy the manifest
echo "📦 Applying Kubernetes manifest..."
kubectl apply -f manifests/ai-assistant.yaml

# Wait for StatefulSets to be ready
echo "⏳ Waiting for StatefulSets..."
kubectl -n ai-assistant rollout status statefulset/ollama --timeout=300s
kubectl -n ai-assistant rollout status statefulset/chromadb --timeout=300s

# Wait for Deployments
echo "⏳ Waiting for Deployments..."
kubectl -n ai-assistant wait --for=condition=available deployment --all --timeout=300s

# Show status
echo ""
echo "📊 Current status:"
kubectl -n ai-assistant get pods

# Load models
echo ""
echo "📥 Loading models..."
./scripts/load-models.sh --primary

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🌐 Access points:"
echo "  - Open WebUI: http://ai.company.local"
echo "  - API Docs: http://ai.company.local/api/docs"
echo ""
echo "💡 Tips:"
echo "  - First user to sign up becomes admin"
echo "  - Models are loaded on ollama-0"
echo "  - To load models on all pods: ./scripts/load-models.sh --all"