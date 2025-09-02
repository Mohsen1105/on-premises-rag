## ############################################################################################
## 1. Prerequisites
# Install required tools
curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# For GPU nodes, install NVIDIA device plugin
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml





## ############################################################################################
## 2. Deploy
# Clone or create the structure
cd k8s-hybrid

# Make scripts executable
chmod +x scripts/*.sh

# Deploy the hybrid setup
./scripts/deploy-hybrid.sh

# Check health
./scripts/health-check.sh

# Load recommended models
./scripts/manage-models.sh





## ############################################################################################
## 3. Verify Deployment

# Check all pods are running
kubectl -n ai-assistant get pods

# Check node labels
kubectl get nodes --show-labels | grep ai-assistant

# Test inference
kubectl -n ai-assistant exec -it $(kubectl -n ai-assistant get pod -l app=ollama-cpu -o name | head -1 | cut -d/ -f2) -- \
  ollama run phi3:mini "Hello, how are you?"





## ############################################################################################
4. Access Services

Open WebUI: http://ai-assistant.company.local
API Documentation: http://ai-assistant.company.local/api/docs
HAProxy Stats: http://ai-monitor.company.local
Grafana (if deployed): http://grafana.company.local

Key Features of This Hybrid Deployment

Automatic Node Detection: Labels nodes as GPU/CPU automatically
Smart Load Balancing: Routes models to appropriate nodes
Model Affinity: Large models prefer GPU, small models prefer CPU
Fallback Support: CPU nodes can handle GPU models if needed
Horizontal Scaling: Both GPU and CPU pods can scale independently
Unified Interface: Single endpoint for all models
Resource Optimization: Efficient use of both GPU and CPU resources
High Availability: Multiple replicas across node types
Monitoring: Built-in metrics and health checks
Easy Management: Scripts for deployment, health checks, and model management