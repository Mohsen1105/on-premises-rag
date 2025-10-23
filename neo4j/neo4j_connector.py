"""
Neo4j Connector for n8n Integration
Provides utilities for interacting with Neo4j graph database
"""

from neo4j import GraphDatabase, basic_auth
from typing import List, Dict, Any, Optional
import logging
from contextlib import contextmanager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class Neo4jConnector:
    """Neo4j database connector with connection pooling"""

    def __init__(
        self,
        uri: str = "bolt://neo4j:7687",
        user: str = "neo4j",
        password: str = "your-password-here",
        encrypted: bool = False
    ):
        """
        Initialize Neo4j connector

        Args:
            uri: Connection URI (default: bolt://neo4j:7687)
            user: Username (default: neo4j)
            password: Password
            encrypted: Enable encryption (default: False for local)
        """
        self.driver = GraphDatabase.driver(
            uri,
            auth=basic_auth(user, password),
            encrypted=encrypted
        )
        self.uri = uri
        self.user = user
        logger.info(f"Connected to Neo4j at {uri}")

    def close(self):
        """Close database connection"""
        self.driver.close()

    @contextmanager
    def session(self):
        """Context manager for Neo4j sessions"""
        session = self.driver.session()
        try:
            yield session
        finally:
            session.close()

    def execute_query(self, query: str, params: Dict[str, Any] = None) -> List[Dict]:
        """
        Execute Cypher query and return results

        Args:
            query: Cypher query string
            params: Query parameters

        Returns:
            List of result dictionaries
        """
        try:
            with self.session() as session:
                result = session.run(query, params or {})
                return [record.data() for record in result]
        except Exception as e:
            logger.error(f"Query execution error: {e}")
            raise

    def create_document(self, doc_id: str, title: str, doc_type: str, **kwargs) -> Dict:
        """Create a document node"""
        query = """
        CREATE (d:Document {
            id: $id,
            title: $title,
            type: $type,
            created_at: datetime(),
            source: $source,
            status: 'active'
        })
        RETURN d
        """
        params = {
            "id": doc_id,
            "title": title,
            "type": doc_type,
            "source": kwargs.get("source", "uploaded")
        }
        return self.execute_query(query, params)

    def create_chunk(
        self,
        chunk_id: str,
        doc_id: str,
        text: str,
        embedding_id: Optional[str] = None,
        **kwargs
    ) -> Dict:
        """Create a document chunk node and link to document"""
        query = """
        MATCH (d:Document {id: $doc_id})
        CREATE (c:Chunk {
            id: $id,
            text: $text,
            embedding_id: $embedding_id,
            page: $page,
            position: $position,
            created_at: datetime()
        })
        CREATE (d)-[:CONTAINS]->(c)
        RETURN c
        """
        params = {
            "id": chunk_id,
            "doc_id": doc_id,
            "text": text,
            "embedding_id": embedding_id,
            "page": kwargs.get("page", 0),
            "position": kwargs.get("position", 0)
        }
        return self.execute_query(query, params)

    def create_entity(
        self,
        name: str,
        entity_type: str,
        description: Optional[str] = None,
        **kwargs
    ) -> Dict:
        """Create an entity node (equipment, location, process, etc.)"""
        query = """
        CREATE (e:Entity {
            name: $name,
            type: $type,
            description: $description,
            status: $status,
            created_at: datetime()
        })
        RETURN e
        """
        params = {
            "name": name,
            "type": entity_type,
            "description": description,
            "status": kwargs.get("status", "active")
        }
        return self.execute_query(query, params)

    def link_chunk_to_entity(self, chunk_id: str, entity_name: str) -> Dict:
        """Create a relationship between a chunk and an entity"""
        query = """
        MATCH (c:Chunk {id: $chunk_id})
        MATCH (e:Entity {name: $entity_name})
        CREATE (c)-[:MENTIONS]->(e)
        RETURN c, e
        """
        params = {"chunk_id": chunk_id, "entity_name": entity_name}
        return self.execute_query(query, params)

    def search_documents(self, query_text: str, limit: int = 10) -> List[Dict]:
        """Full-text search on documents"""
        query = """
        MATCH (d:Document)
        WHERE d.title CONTAINS $search_text OR d.type CONTAINS $search_text
        RETURN d
        LIMIT $limit
        """
        params = {"search_text": query_text, "limit": limit}
        return self.execute_query(query, params)

    def find_related_chunks(self, entity_name: str, limit: int = 5) -> List[Dict]:
        """Find chunks related to a specific entity"""
        query = """
        MATCH (c:Chunk)-[:MENTIONS]->(e:Entity {name: $entity_name})
        RETURN c, e
        LIMIT $limit
        """
        params = {"entity_name": entity_name, "limit": limit}
        return self.execute_query(query, params)

    def get_entity_context(self, entity_name: str) -> Dict:
        """Get all relationships and context for an entity"""
        query = """
        MATCH (e:Entity {name: $entity_name})
        OPTIONAL MATCH (e)-[r1]->(related)
        OPTIONAL MATCH (chunk:Chunk)-[:MENTIONS]->(e)
        RETURN e, collect({type: type(r1), node: related}) as relationships, collect(chunk) as mentions
        """
        params = {"entity_name": entity_name}
        return self.execute_query(query, params)

    def create_query_log(self, query_id: str, query_text: str, result_ids: List[str]) -> Dict:
        """Log a query and its results for analytics"""
        query = """
        CREATE (q:Query {
            id: $query_id,
            text: $text,
            timestamp: datetime(),
            result_count: $result_count
        })
        RETURN q
        """
        params = {
            "query_id": query_id,
            "text": query_text,
            "result_count": len(result_ids)
        }
        return self.execute_query(query, params)

    def get_stats(self) -> Dict[str, Any]:
        """Get database statistics"""
        query = """
        MATCH (n)
        WITH labels(n) as labels, count(*) as count
        RETURN labels, count
        UNION ALL
        MATCH ()-[r]->()
        RETURN [type(r)] as labels, count(*) as count
        """
        return self.execute_query(query)


# n8n Integration Helper Functions

def format_for_n8n(data: Any) -> Dict:
    """Format Neo4j results for n8n workflow consumption"""
    if isinstance(data, list):
        return {"items": data, "count": len(data)}
    return {"item": data, "count": 1}


def neo4j_query_node(uri: str, user: str, password: str, cypher_query: str, params: Dict = None) -> List[Dict]:
    """
    Standalone function for n8n nodes
    Usage in n8n: $json = require('neo4j_connector').neo4j_query_node(...)
    """
    connector = Neo4jConnector(uri, user, password)
    try:
        results = connector.execute_query(cypher_query, params or {})
        return results
    finally:
        connector.close()
