#!/bin/bash
# k8s-hybrid/scripts/health-check.sh

echo "🏥 AI Assistant Health Check"
echo "=========================="

# Function to check service health
check_service() {
    local service=$1
    local port=$2
    local endpoint=$3
    
    echo -n "Checking $service... "
    
    if kubectl -n ai-assistant exec -it $(kubectl -n ai-assistant get pod -l app=$service -o name | head -1 | cut -d/ -f2) -- wget -q -O- http://localhost:$port$endpoint &>/dev/null; then
        echo "✅ OK"
        return 0
    else
        echo "❌ Failed"
        return 1
    fi
}

# Check all services
echo ""
echo "Service Health:"
echo "--------------"
check_service "api" "8000" "/health"
check_service "open-webui" "8080" "/"
check_service "chromadb" "8000" "/api/v1"
check_service "redis" "6379" ""

# Check Ollama instances
echo ""
echo "Ollama Instances:"
echo "----------------"

# GPU instances
echo "GPU Nodes:"
for pod in $(kubectl -n ai-assistant get pods -l app=ollama-gpu -o name | cut -d/ -f2); do
    echo -n "  $pod: "
    if kubectl -n ai-assistant exec $pod -- ollama list &>/dev/null; then
        models=$(kubectl -n ai-assistant exec $pod -- ollama list | tail -n +2 | wc -l)
        echo "✅ OK ($models models)"
    else
        echo "❌ Failed"
    fi
done

# CPU instances
echo "CPU Nodes:"
for pod in $(kubectl -n ai-assistant get pods -l app=ollama-cpu -o name | cut -d/ -f2); do
    echo -n "  $pod: "
    if kubectl -n ai-assistant exec $pod -- ollama list &>/dev/null; then
        models=$(kubectl -n ai-assistant exec $pod -- ollama list | tail -n +2 | wc -l)
        echo "✅ OK ($models models)"
    else
        echo "❌ Failed"
    fi
done

# Check resource usage
echo ""
echo "Resource Usage:"
echo "--------------"
kubectl -n ai-assistant top pods --containers

# Check persistent volumes
echo ""
echo "Storage Status:"
echo "--------------"
kubectl -n ai-assistant get pvc

# Test model inference
echo ""
echo "Model Inference Test:"
echo "--------------------"

# Test small model on CPU
echo -n "Testing CPU inference (phi3:mini)... "
if kubectl -n ai-assistant exec -it $(kubectl -n ai-assistant get pod -l app=ollama-cpu -o name | head -1 | cut -d/ -f2) -- \
    curl -s http://localhost:11434/api/generate -d '{"model":"phi3:mini","prompt":"Hello","stream":false}' | grep -q response; then
    echo "✅ OK"
else
    echo "❌ Failed"
fi

# Test large model on GPU (if available)
if [ $(kubectl get nodes -l ai-assistant/gpu-available=true -o name | wc -l) -gt 0 ]; then
    echo -n "Testing GPU inference (llama3.2:latest)... "
    if kubectl -n ai-assistant exec -it $(kubectl -n ai-assistant get pod -l app=ollama-gpu -o name | head -1 | cut -d/ -f2) -- \
        curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:latest","prompt":"Hello","stream":false}' | grep -q response; then
        echo "✅ OK"
    else
        echo "❌ Failed"
    fi
fi

echo ""
echo "Health check complete!"