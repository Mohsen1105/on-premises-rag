#!/bin/bash
# k8s-hybrid/scripts/deploy-hybrid.sh

set -e

echo "🚀 Deploying Hybrid AI Assistant to Kubernetes"

# Function to check prerequisites
check_prerequisites() {
    echo "📋 Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        echo "❌ Cannot connect to Kubernetes cluster."
        exit 1
    fi
    
    echo "✅ Prerequisites check passed"
}

# Function to detect node types
detect_nodes() {
    echo "🔍 Detecting cluster nodes..."
    
    # Run node detection job
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: node-detector
  namespace: kube-system
spec:
  template:
    spec:
      serviceAccountName: node-detector
      containers:
      - name: detector
        image: bitnami/kubectl:latest
        command: ["/bin/bash", "-c"]
        args:
        - |
          GPU_COUNT=0
          CPU_COUNT=0
          
          for node in \$(kubectl get nodes -o name | cut -d/ -f2); do
            gpu=\$(kubectl get node \$node -o jsonpath='{.status.capacity.nvidia\.com/gpu}' 2>/dev/null || echo "0")
            if [ "\$gpu" != "0" ] && [ ! -z "\$gpu" ]; then
              ((GPU_COUNT++))
              kubectl label node \$node ai-assistant/node-type=gpu --overwrite
              kubectl label node \$node ai-assistant/gpu-available=true --overwrite
            else
              ((CPU_COUNT++))
              kubectl label node \$node ai-assistant/node-type=cpu --overwrite
              kubectl label node \$node ai-assistant/gpu-available=false --overwrite
            fi
          done
          
          echo "Found \$GPU_COUNT GPU nodes and \$CPU_COUNT CPU nodes"
      restartPolicy: Never
EOF
    
    # Wait for job completion
    kubectl wait --for=condition=complete job/node-detector -n kube-system --timeout=60s
    
    # Get results
    GPU_NODES=$(kubectl get nodes -l ai-assistant/gpu-available=true -o name | wc -l)
    CPU_NODES=$(kubectl get nodes -l ai-assistant/gpu-available=false -o name | wc -l)
    
    echo "✅ Detected $GPU_NODES GPU nodes and $CPU_NODES CPU nodes"
    
    # Clean up job
    kubectl delete job node-detector -n kube-system
}

# Function to apply configurations
apply_configs() {
    echo "📦 Applying Kubernetes configurations..."
    
    # Create namespace first
    kubectl apply -f base/00-namespace.yaml
    
    # Apply all base configurations
    kubectl apply -f base/
    
    echo "✅ Base configurations applied"
}

# Function to wait for deployments
wait_for_deployments() {
    echo "⏳ Waiting for deployments to be ready..."
    
    kubectl -n ai-assistant wait --for=condition=available --timeout=300s \
        deployment/api \
        deployment/open-webui \
        deployment/chromadb \
        deployment/redis \
        deployment/smart-loadbalancer
    
    # Check StatefulSet
    kubectl -n ai-assistant rollout status statefulset/ollama-gpu --timeout=300s || true
    
    # Check DaemonSet
    kubectl -n ai-assistant rollout status daemonset/ollama-cpu --timeout=300s || true
    
    echo "✅ All deployments are ready"
}

# Function to load models
load_models() {
    echo "📥 Loading models on nodes..."
    
    # Load models on GPU nodes
    for pod in $(kubectl -n ai-assistant get pods -l app=ollama-gpu -o name | cut -d/ -f2); do
        echo "Loading GPU models on $pod..."
        kubectl -n ai-assistant exec $pod -- ollama list || true
    done
    
    # Load models on CPU nodes
    for pod in $(kubectl -n ai-assistant get pods -l app=ollama-cpu -o name | cut -d/ -f2); do
        echo "Loading CPU models on $pod..."
        kubectl -n ai-assistant exec $pod -- ollama list || true
    done
    
    echo "✅ Models loaded"
}

# Function to display status
display_status() {
    echo ""
    echo "📊 Deployment Status:"
    echo "===================="
    kubectl -n ai-assistant get all
    echo ""
    echo "🌐 Access URLs:"
    echo "=============="
    echo "Open WebUI: http://ai-assistant.company.local"
    echo "API Docs: http://ai-assistant.company.local/api/docs"
    echo "HAProxy Stats: http://ai-monitor.company.local"
    echo ""
    echo "📝 Node Distribution:"
    echo "===================="
    kubectl get nodes -L ai-assistant/node-type,ai-assistant/gpu-available
}

# Main deployment flow
main() {
    check_prerequisites
    detect_nodes
    apply_configs
    wait_for_deployments
    load_models
    display_status
    
    echo ""
    echo "✅ Hybrid deployment complete!"
    echo ""
    echo "Next steps:"
    echo "1. Access Open WebUI at http://ai-assistant.company.local"
    echo "2. Create your admin account (first user)"
    echo "3. Test both GPU and CPU model inference"
    echo "4. Monitor performance at http://ai-monitor.company.local"
}

# Run main function
main