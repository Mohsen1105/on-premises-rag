# api/use_cases/technical_manual.py
from typing import List, Dict
import asyncio
from document_processor import DocumentProcessor
from database_connectors import DatabaseConnector

class TechnicalManualAssistant:
    def __init__(self, chroma_client, ollama_client):
        self.chroma_client = chroma_client
        self.ollama_client = ollama_client
        self.processor = DocumentProcessor()
        self.db_connector = DatabaseConnector()
    
    async def load_technical_manuals(self, manual_paths: List[str]):
        """Load and index technical manuals"""
        collection = self.chroma_client.get_or_create_collection(
            "technical_manuals",
            metadata={"type": "technical_documentation"}
        )
        
        for path in manual_paths:
            if path.endswith('.pdf'):
                chunks = self.processor.process_pdf(path)
            elif path.endswith('.docx'):
                chunks = self.processor.process_docx(path)
            else:
                continue
            
            # Index with enhanced metadata
            for chunk in chunks:
                chunk['metadata']['document_type'] = 'technical_manual'
                chunk['metadata']['department'] = 'engineering'
            
            self.processor.index_documents(chunks, "technical_manuals")
    
    async def query_manual(self, query: str, equipment_id: str = None) -> Dict:
        """Query technical manuals with optional equipment context"""
        
        # If equipment ID provided, get additional context from database
        equipment_context = ""
        if equipment_id:
            equipment_data = self.db_connector.query_sql_server(
                f"SELECT * FROM equipment_specs WHERE equipment_id = '{equipment_id}'"
            )
            if not equipment_data.empty:
                equipment_context = f"Equipment Details:\n{equipment_data.to_string()}\n\n"
        
        # Search technical manuals
        collection = self.chroma_client.get_collection("technical_manuals")
        results = collection.query(
            query_texts=[query],
            n_results=5,
            where={"document_type": "technical_manual"}
        )
        
        # Build context
        context = equipment_context
        if results['documents']:
            context += "Relevant Manual Sections:\n"
            context += "\n---\n".join(results['documents'][0])
        
        # Generate response
        response = self.ollama_client.chat(
            model="mistral:7b-instruct",
            messages=[
                {
                    "role": "system",
                    "content": "You are a technical expert assistant for oil and gas operations. Provide detailed, accurate responses based on technical manuals and equipment specifications."
                },
                {
                    "role": "user",
                    "content": f"Context:\n{context}\n\nQuestion: {query}"
                }
            ],
            options={
                "temperature": 0.3,  # Lower temperature for factual accuracy
                "top_p": 0.9
            }
        )
        
        return {
            "answer": response['message']['content'],
            "sources": results['metadatas'][0] if results['documents'] else [],
            "equipment_context_used": bool(equipment_id)
        }