# api/main.py
from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from contextlib import asynccontextmanager
import uvicorn
from typing import List, Optional
from pydantic import BaseModel
import chromadb
from redis import Redis
import ollama
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize clients
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    app.state.chroma_client = chromadb.HttpClient(host="chromadb", port=8000)
    app.state.redis_client = Redis(host="redis", port=6379, decode_responses=True)
    app.state.ollama_client = ollama.Client(host="http://localhost:11434")
    
    yield
    
    # Shutdown
    app.state.redis_client.close()

app = FastAPI(title="Enterprise AI Assistant API", lifespan=lifespan)
security = HTTPBearer()

# Models
class QueryRequest(BaseModel):
    query: str
    collection: Optional[str] = "default"
    use_rag: bool = True
    model: str = "llama3.2:latest"

class Document(BaseModel):
    content: str
    metadata: dict
    collection: str = "default"

# Authentication middleware
async def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    # Implement your authentication logic here
    # For production, integrate with LDAP/AD
    if token != "your-secret-token":
        raise HTTPException(status_code=403, detail="Invalid authentication")
    return token

# Endpoints
@app.post("/api/query")
async def query_assistant(
    request: QueryRequest,
    token: str = Depends(verify_token)
):
    """Query the AI assistant with RAG capabilities"""
    
    # Check cache first
    cache_key = f"query:{request.model}:{request.query}"
    cached_response = app.state.redis_client.get(cache_key)
    
    if cached_response and not request.use_rag:
        return {"response": cached_response, "cached": True}
    
    context = ""
    
    # RAG retrieval
    if request.use_rag:
        collection = app.state.chroma_client.get_or_create_collection(request.collection)
        
        # Search for relevant documents
        results = collection.query(
            query_texts=[request.query],
            n_results=5
        )
        
        if results['documents']:
            context = "\n\n".join(results['documents'][0])
    
    # Generate response
    prompt = f"""Context information:
{context}

User question: {request.query}

Please provide a detailed and accurate answer based on the context provided. If the context doesn't contain relevant information, please state that clearly."""
    
    try:
        response = app.state.ollama_client.chat(
            model=request.model,
            messages=[
                {
                    'role': 'system',
                    'content': 'You are a helpful AI assistant for an oil and gas company. Provide accurate, professional responses based on the provided context.'
                },
                {
                    'role': 'user',
                    'content': prompt
                }
            ]
        )
        
        result = response['message']['content']
        
        # Cache the response
        app.state.redis_client.setex(cache_key, 3600, result)
        
        return {
            "response": result,
            "model": request.model,
            "context_used": bool(context),
            "cached": False
        }
        
    except Exception as e:
        logger.error(f"Error generating response: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/documents/upload")
async def upload_document(
    document: Document,
    token: str = Depends(verify_token)
):
    """Upload and index a document"""
    
    try:
        collection = app.state.chroma_client.get_or_create_collection(document.collection)
        
        # Generate embedding and store
        collection.add(
            documents=[document.content],
            metadatas=[document.metadata],
            ids=[f"doc_{document.metadata.get('filename', 'unknown')}_{hash(document.content)}"]
        )
        
        return {"status": "success", "message": "Document indexed successfully"}
        
    except Exception as e:
        logger.error(f"Error uploading document: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/models")
async def list_models(token: str = Depends(verify_token)):
    """List available LLM models"""
    
    try:
        models = app.state.ollama_client.list()
        return {"models": [model['name'] for model in models['models']]}
    except Exception as e:
        logger.error(f"Error listing models: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)