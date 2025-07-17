# Add to api/health_check.py
async def check_model_health():
    try:
        models = ollama_client.list()
        return {
            "status": "healthy",
            "models": [m['name'] for m in models['models']],
            "count": len(models['models'])
        }
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)}