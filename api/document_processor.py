# api/document_processor.py
import os
from typing import List, Dict, Any
import PyPDF2
import docx
import pandas as pd
from langchain.text_splitter import RecursiveCharacterTextSplitter
import chromadb
from chromadb.utils import embedding_functions

class DocumentProcessor:
    def __init__(self, chroma_host: str = "chromadb", chroma_port: int = 8000):
        self.client = chromadb.HttpClient(host=chroma_host, port=chroma_port)
        self.text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200,
            length_function=len,
            separators=["\n\n", "\n", " ", ""]
        )
        
        # Use Sentence Transformers for embeddings
        self.embedding_function = embedding_functions.SentenceTransformerEmbeddingFunction(
            model_name="all-MiniLM-L6-v2"
        )
    
    def process_pdf(self, file_path: str) -> List[Dict[str, Any]]:
        """Extract text from PDF files"""
        chunks = []
        
        with open(file_path, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            text = ""
            
            for page_num in range(len(pdf_reader.pages)):
                page = pdf_reader.pages[page_num]
                text += page.extract_text() + "\n"
            
            # Split into chunks
            text_chunks = self.text_splitter.split_text(text)
            
            for i, chunk in enumerate(text_chunks):
                chunks.append({
                    "content": chunk,
                    "metadata": {
                        "source": file_path,
                        "page": i,
                        "type": "pdf"
                    }
                })
        
        return chunks
    
    def process_docx(self, file_path: str) -> List[Dict[str, Any]]:
        """Extract text from DOCX files"""
        chunks = []
        doc = docx.Document(file_path)
        text = ""
        
        for paragraph in doc.paragraphs:
            text += paragraph.text + "\n"
        
        # Split into chunks
        text_chunks = self.text_splitter.split_text(text)
        
        for i, chunk in enumerate(text_chunks):
            chunks.append({
                "content": chunk,
                "metadata": {
                    "source": file_path,
                    "chunk": i,
                    "type": "docx"
                }
            })
        
        return chunks
    
    def process_excel(self, file_path: str) -> List[Dict[str, Any]]:
        """Extract data from Excel files"""
        chunks = []
        
        # Read all sheets
        excel_file = pd.ExcelFile(file_path)
        
        for sheet_name in excel_file.sheet_names:
            df = pd.read_excel(file_path, sheet_name=sheet_name)
            
            # Convert dataframe to text representation
            text = f"Sheet: {sheet_name}\n"
            text += df.to_string()
            
            # Split into chunks
            text_chunks = self.text_splitter.split_text(text)
            
            for i, chunk in enumerate(text_chunks):
                chunks.append({
                    "content": chunk,
                    "metadata": {
                        "source": file_path,
                        "sheet": sheet_name,
                        "chunk": i,
                        "type": "excel"
                    }
                })
        
        return chunks
    
    def index_documents(self, chunks: List[Dict[str, Any]], collection_name: str = "default"):
        """Index document chunks in ChromaDB"""
        collection = self.client.get_or_create_collection(
            name=collection_name,
            embedding_function=self.embedding_function
        )
        
        documents = [chunk["content"] for chunk in chunks]
        metadatas = [chunk["metadata"] for chunk in chunks]
        ids = [f"{collection_name}_{i}_{hash(doc)}" for i, doc in enumerate(documents)]
        
        collection.add(
            documents=documents,
            metadatas=metadatas,
            ids=ids
        )
        
        return len(chunks)