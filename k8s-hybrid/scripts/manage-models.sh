#!/bin/bash
# k8s-hybrid/scripts/manage-models.sh

set -e

# Model configurations
GPU_MODELS=(
    "llama3.2:latest"
    "mistral:7b-instruct"
    "codellama:7b"
    "llama3.1:8b"
)

CPU_MODELS=(
    "phi3:mini"
    "llama3.2:1b"
    "llama3.2:3b-instruct-q4_0"
    "gemma2:2b"
    "qwen2.5:0.5b"
)

# Function to manage models
manage_models() {
    local action=$1
    local model_type=$2
    local model_name=$3
    
    case $action in
        "pull")
            pull_model $model_type $model_name
            ;;
        "remove")
            remove_model $model_type $model_name
            ;;
        "list")
            list_models $model_type
            ;;
        *)
            echo "Usage: $0 {pull|remove|list} {gpu|cpu|all} [model_name]"
            exit 1
            ;;
    esac
}

# Pull model function
pull_model() {
    local type=$1
    local model=$2
    
    if [ "$type" == "gpu" ] || [ "$type" == "all" ]; then
        echo "📥 Pulling $model on GPU nodes..."
        for pod in $(kubectl -n ai-assistant get pods -l app=ollama-gpu -o name | cut -d/ -f2); do
            echo "  Pulling on $pod..."
            kubectl -n ai-assistant exec $pod -- ollama pull $model
        done
    fi
    
    if [ "$type" == "cpu" ] || [ "$type" == "all" ]; then
        echo "📥 Pulling $model on CPU nodes..."
        for pod in $(kubectl -n ai-assistant get pods -l app=ollama-cpu -o name | cut -d/ -f2); do
            echo "  Pulling on $pod..."
            kubectl -n ai-assistant exec $pod -- ollama pull $model
        done
    fi
}

# Remove model function
remove_model() {
    local type=$1
    local model=$2
    
    if [ "$type" == "gpu" ] || [ "$type" == "all" ]; then
        echo "🗑️ Removing $model from GPU nodes..."
        for pod in $(kubectl -n ai-assistant get pods -l app=ollama-gpu -o name | cut -d/ -f2); do
            kubectl -n ai-assistant exec $pod -- ollama rm $model || true
        done
    fi
    
    if [ "$type" == "cpu" ] || [ "$type" == "all" ]; then
        echo "🗑️ Removing $model from CPU nodes..."
        for pod in $(kubectl -n ai-assistant get pods -l app=ollama-cpu -o name | cut -d/ -f2); do
            kubectl -n ai-assistant exec $pod -- ollama rm $model || true
        done
    fi
}

# List models function
list_models() {
    local type=$1
    
    echo "📋 Installed Models:"
    echo "==================="
    
    if [ "$type" == "gpu" ] || [ "$type" == "all" ]; then
        echo ""
        echo "GPU Nodes:"
        for pod in $(kubectl -n ai-assistant get pods -l app=ollama-gpu -o name | cut -d/ -f2); do
            echo "  $pod:"
            kubectl -n ai-assistant exec $pod -- ollama list | sed 's/^/    /'
        done
    fi
    
    if [ "$type" == "cpu" ] || [ "$type" == "all" ]; then
        echo ""
        echo "CPU Nodes:"
        for pod in $(kubectl -n ai-assistant get pods -l app=ollama-cpu -o name | cut -d/ -f2); do
            echo "  $pod:"
            kubectl -n ai-assistant exec $pod -- ollama list | sed 's/^/    /'
        done
    fi
}

# Interactive menu
if [ $# -eq 0 ]; then
    echo "🤖 AI Assistant Model Manager"
    echo "============================"
    echo ""
    echo "1) Pull recommended models"
    echo "2) Pull specific model"
    echo "3) Remove model"
    echo "4) List all models"
    echo "5) Exit"
    echo ""
    read -p "Select option: " option
    
    case $option in
        1)
            echo "Pulling recommended models..."
            for model in "${GPU_MODELS[@]}"; do
                pull_model "gpu" $model
            done
            for model in "${CPU_MODELS[@]}"; do
                pull_model "cpu" $model
            done
            ;;
        2)
            read -p "Enter model name: " model
            read -p "Deploy to (gpu/cpu/all): " type
            pull_model $type $model
            ;;
        3)
            read -p "Enter model name: " model
            read -p "Remove from (gpu/cpu/all): " type
            remove_model $type $model
            ;;
        4)
            list_models "all"
            ;;
        5)
            exit 0
            ;;
    esac
else
    manage_models "$@"
fi