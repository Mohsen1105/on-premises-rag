# api/use_cases/correspondence.py
from typing import Dict, List, Optional
import json

class CorrespondenceAssistant:
    def __init__(self, ollama_client, chroma_client):
        self.ollama_client = ollama_client
        self.chroma_client = chroma_client
        
        # Load templates
        self.templates = self.load_templates()
    
    def load_templates(self) -> Dict:
        """Load correspondence templates"""
        return {
            "safety_incident": {
                "tone": "formal",
                "structure": ["incident_summary", "immediate_actions", "investigation", "preventive_measures", "closure"]
            },
            "project_update": {
                "tone": "professional",
                "structure": ["summary", "progress", "challenges", "next_steps", "timeline"]
            },
            "technical_consultation": {
                "tone": "technical",
                "structure": ["problem_statement", "analysis", "recommendations", "risks", "conclusion"]
            },
            "vendor_communication": {
                "tone": "business",
                "structure": ["purpose", "requirements", "expectations", "timeline", "next_actions"]
            }
        }
    
    async def draft_correspondence(
        self,
        correspondence_type: str,
        key_points: List[str],
        recipient_info: Dict,
        additional_context: Optional[str] = None
    ) -> Dict:
        """Draft correspondence based on type and requirements"""
        
        template = self.templates.get(correspondence_type, self.templates["project_update"])
        
        # Search for similar past correspondence
        collection = self.chroma_client.get_or_create_collection("correspondence_history")
        similar_docs = collection.query(
            query_texts=[" ".join(key_points)],
            n_results=3,
            where={"type": correspondence_type}
        )
        
        # Build context
        context = f"Correspondence Type: {correspondence_type}\n"
        context += f"Recipient: {recipient_info.get('name', 'Unknown')} ({recipient_info.get('role', 'Unknown')})\n"
        context += f"Key Points:\n" + "\n".join([f"- {point}" for point in key_points])
        
        if additional_context:
            context += f"\n\nAdditional Context:\n{additional_context}"
        
        if similar_docs['documents']:
            context += "\n\nSimilar Past Correspondence Examples:\n"
            context += "\n---\n".join(similar_docs['documents'][0][:2])
        
        # Generate correspondence
        prompt = f"""
        Create a {template['tone']} {correspondence_type} with the following structure:
        {', '.join(template['structure'])}
        
        Context:
        {context}
        
        Please draft a complete, professional correspondence that addresses all key points.
        """
        
        response = self.ollama_client.chat(
            model="mistral:7b-instruct",
            messages=[
                {
                    "role": "system",
                    "content": f"You are a professional correspondence writer for an oil and gas company. Write in a {template['tone']} tone."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            options={"temperature": 0.7}
        )
        
        # Save to history
        collection.add(
            documents=[response['message']['content']],
            metadatas=[{
                "type": correspondence_type,
                "recipient": recipient_info.get('name', 'Unknown'),
                "date": datetime.now().isoformat(),
                "key_points": json.dumps(key_points)
            }],
            ids=[f"corr_{datetime.now().timestamp()}"]
        )
        
        return {
            "correspondence": response['message']['content'],
            "type": correspondence_type,
            "tone": template['tone'],
            "similar_examples_found": len(similar_docs['documents'][0]) if similar_docs['documents'] else 0
        }
    
    async def provide_consultation(
        self,
        topic: str,
        specific_questions: List[str],
        technical_level: str = "medium"  # low, medium, high
    ) -> Dict:
        """Provide consultation on specific topics"""
        
        # Search knowledge base
        kb_collection = self.chroma_client.get_or_create_collection("knowledge_base")
        relevant_docs = kb_collection.query(
            query_texts=[topic] + specific_questions,
            n_results=10
        )
        
        # Build consultation response
        context = ""
        if relevant_docs['documents']:
            context = "Relevant Information:\n"
            context += "\n---\n".join(relevant_docs['documents'][0])
        
        # Adjust model and temperature based on technical level
        model_config = {
            "low": {"model": "llama3.2:latest", "temperature": 0.8},
            "medium": {"model": "mistral:7b-instruct", "temperature": 0.6},
            "high": {"model": "mistral:7b-instruct", "temperature": 0.4}
        }
        
        config = model_config.get(technical_level, model_config["medium"])
        
        consultation_prompt = f"""
        Topic: {topic}
        Technical Level: {technical_level}
        
        Questions:
        {chr(10).join([f"{i+1}. {q}" for i, q in enumerate(specific_questions)])}
        
        {f"Context:{chr(10)}{context}" if context else ""}
        
        Please provide a comprehensive consultation addressing each question with appropriate technical depth.
        """
        
        response = self.ollama_client.chat(
            model=config["model"],
            messages=[
                {
                    "role": "system",
                    "content": f"You are a senior technical consultant in the oil and gas industry. Provide clear, actionable advice at a {technical_level} technical level."
                },
                {
                    "role": "user",
                    "content": consultation_prompt
                }
            ],
            options={"temperature": config["temperature"]}
        )
        
        return {
            "consultation": response['message']['content'],
            "topic": topic,
            "questions_addressed": len(specific_questions),
            "technical_level": technical_level,
            "sources_used": len(relevant_docs['documents'][0]) if relevant_docs['documents'] else 0
        }