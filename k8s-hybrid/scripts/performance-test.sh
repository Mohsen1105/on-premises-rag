#!/bin/bash
# k8s-hybrid/scripts/performance-test.sh

echo "🚀 AI Assistant Performance Test"
echo "==============================="

# Test endpoints
API_URL="http://ai-assistant.company.local/api"
OLLAMA_URL="http://ai-assistant.company.local/ollama"

# Test configurations
MODELS=("phi3:mini" "llama3.2:1b" "llama3.2:latest" "mistral:7b-instruct")
PROMPTS=(
    "What is 2+2?"
    "Write a short poem about clouds"
    "Explain quantum computing in simple terms"
    "Generate a Python function to calculate fibonacci numbers"
)

# Function to test model performance
test_model() {
    local model=$1
    local prompt=$2
    local start_time=$(date +%s.%N)
    
    response=$(curl -s -X POST $API_URL/query \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$model\",\"prompt\":\"$prompt\",\"stream\":false}" \
        2>/dev/null)
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    if echo "$response" | grep -q "response"; then
        echo "✅ $model: ${duration}s"
    else
        echo "❌ $model: Failed"
    fi
}

# Run tests
echo ""
echo "Testing model inference times..."
echo "-------------------------------"

for model in "${MODELS[@]}"; do
    echo ""
    echo "Model: $model"
    for i in {0..3}; do
        echo -n "  Test $((i+1)): "
        test_model "$model" "${PROMPTS[$i]}"
    done
done

# Load test
echo ""
echo "Running load test..."
echo "-------------------"

# Concurrent requests test
echo "Testing concurrent requests (10 parallel)..."
for i in {1..10}; do
    curl -s -X POST $API_URL/query \
        -H "Content-Type: application/json" \
        -d '{"model":"phi3:mini","prompt":"Hello","stream":false}' \
        >/dev/null 2>&1 &
done
wait

echo "✅ Load test completed"

# Check pod distribution
echo ""
echo "Pod Distribution:"
echo "----------------"
kubectl -n ai-assistant get pods -o wide | grep -E "(ollama|api|webui)"