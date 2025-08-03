#!/bin/bash
# k8s-simple/scripts/load-models.sh

set -e

echo "🚀 AI Assistant Model Loader"
echo "=========================="

# CPU-optimized models
CPU_MODELS=(
    "phi3:mini"
    "llama3.2:1b"
    "llama3.2:3b-instruct-q4_0"
    "gemma2:2b"
)

# Function to load models on a specific pod
load_models_on_pod() {
    local pod=$1
    echo "📦 Loading models on $pod..."
    
    for model in "${CPU_MODELS[@]}"; do
        echo "  📥 Pulling $model..."
        kubectl -n ai-assistant exec $pod -- ollama pull $model || {
            echo "  ⚠️  Failed to pull $model, continuing..."
        }
    done
    
    echo "  ✅ Models loaded on $pod"
}

# Function to check if models are already loaded
check_existing_models() {
    local pod=$1
    echo "🔍 Checking existing models on $pod..."
    kubectl -n ai-assistant exec $pod -- ollama list || echo "No models found"
}

# Main execution
main() {
    echo "⏳ Waiting for Ollama pods to be ready..."
    kubectl -n ai-assistant wait --for=condition=ready pod -l app=ollama --timeout=300s
    
    # Get all Ollama pods
    OLLAMA_PODS=$(kubectl -n ai-assistant get pods -l app=ollama -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$OLLAMA_PODS" ]; then
        echo "❌ No Ollama pods found!"
        exit 1
    fi
    
    echo "📋 Found Ollama pods: $OLLAMA_PODS"
    echo ""
    
    # Option to load on all pods or specific one
    if [ "$1" == "--all" ]; then
        echo "Loading models on all pods..."
        for pod in $OLLAMA_PODS; do
            check_existing_models $pod
            load_models_on_pod $pod
            echo ""
        done
    elif [ "$1" == "--primary" ]; then
        echo "Loading models on primary pod only..."
        PRIMARY_POD=$(echo $OLLAMA_PODS | cut -d' ' -f1)
        check_existing_models $PRIMARY_POD
        load_models_on_pod $PRIMARY_POD
    else
        echo "Usage: $0 [--all|--primary]"
        echo "  --all      Load models on all Ollama pods"
        echo "  --primary  Load models on primary pod only (ollama-0)"
        echo ""
        echo "Available pods:"
        for pod in $OLLAMA_PODS; do
            echo "  - $pod"
        done
        exit 1
    fi
    
    echo ""
    echo "✅ Model loading complete!"
    echo ""
    echo "📊 Final model status:"
    for pod in $OLLAMA_PODS; do
        echo "Pod: $pod"
        kubectl -n ai-assistant exec $pod -- ollama list | sed 's/^/  /'
        echo ""
    done
}

# Run main function with arguments
main "$@"