-- Initialize PostgreSQL with pgvector extension for Supabase-compatible vector storage
-- This script runs automatically when the PostgreSQL container first starts

-- Create the pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create a schema for vector storage (optional, for organization)
CREATE SCHEMA IF NOT EXISTS vectors;

-- Create documents table for text-embedding-3-large (3072 dimensions)
CREATE TABLE IF NOT EXISTS vectors.documents (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    metadata JSONB,
    embedding vector(3072),  -- text-embedding-3-large uses 3072 dimensions
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Note: Indexes are not created for embeddings with >2000 dimensions
-- pgvector limitation: HNSW and IVFFlat indexes support max 2000 dimensions
-- Searches will use sequential scan, which is acceptable for moderate datasets
-- For better performance, consider:
--   1. Using a smaller embedding model (e.g., text-embedding-3-small: 1536 dimensions)
--   2. Implementing filtering on metadata before vector search
--   3. Partitioning the table by document type or date

-- Grant permissions to the PostgreSQL user
GRANT ALL PRIVILEGES ON SCHEMA vectors TO current_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA vectors TO current_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA vectors TO current_user;

-- Function to perform similarity search
CREATE OR REPLACE FUNCTION vectors.similarity_search(
    query_embedding vector(3072),
    match_threshold float DEFAULT 0.7,
    match_count int DEFAULT 5
)
RETURNS TABLE (
    id integer,
    content text,
    metadata jsonb,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.id,
        e.content,
        e.metadata,
        1 - (e.embedding <=> query_embedding) as similarity
    FROM vectors.documents e
    WHERE 1 - (e.embedding <=> query_embedding) > match_threshold
    ORDER BY e.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;
