# api/gpu_optimizer.py
import torch
import gc
from typing import Dict, Any

class GPUOptimizer:
    def __init__(self, max_memory_gb: int = 11):  # RTX 3060 has 12GB
        self.max_memory = max_memory_gb * 1024 * 1024 * 1024
        self.current_models = {}
    
    def check_memory(self) -> Dict[str, Any]:
        """Check current GPU memory usage"""
        if torch.cuda.is_available():
            allocated = torch.cuda.memory_allocated()
            reserved = torch.cuda.memory_reserved()
            free = self.max_memory - allocated
            
            return {
                "allocated_gb": allocated / 1024**3,
                "reserved_gb": reserved / 1024**3,
                "free_gb": free / 1024**3,
                "utilization": (allocated / self.max_memory) * 100
            }
        return {"error": "CUDA not available"}
    
    def optimize_memory(self):
        """Free up GPU memory"""
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            gc.collect()
    
    def can_load_model(self, model_size_gb: float) -> bool:
        """Check if model can be loaded"""
        memory_status = self.check_memory()
        return memory_status.get("free_gb", 0) >= model_size_gb * 1.2  # 20% buffer