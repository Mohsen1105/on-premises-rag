// Neo4j initialization script for RAG system
// This script sets up the graph database schema and constraints

// Create constraints for unique identifiers
CREATE CONSTRAINT doc_id IF NOT EXISTS
  FOR (d:Document) REQUIRE d.id IS UNIQUE;

CREATE CONSTRAINT chunk_id IF NOT EXISTS
  FOR (c:Chunk) REQUIRE c.id IS UNIQUE;

CREATE CONSTRAINT entity_name IF NOT EXISTS
  FOR (e:Entity) REQUIRE e.name IS UNIQUE;

CREATE CONSTRAINT query_id IF NOT EXISTS
  FOR (q:Query) REQUIRE q.id IS UNIQUE;

// Create indexes for performance
CREATE INDEX doc_type IF NOT EXISTS
  FOR (d:Document) ON (d.type);

CREATE INDEX doc_created IF NOT EXISTS
  FOR (d:Document) ON (d.created_at);

CREATE INDEX entity_type IF NOT EXISTS
  FOR (e:Entity) ON (e.type);

CREATE INDEX chunk_embedding IF NOT EXISTS
  FOR (c:Chunk) ON (c.embedding_id);

// Create sample document structure
CREATE (doc:Document {
  id: 'doc_001',
  title: 'Sample Technical Manual',
  type: 'technical_manual',
  created_at: datetime(),
  source: 'uploaded',
  status: 'active'
})
RETURN doc;

// Create sample entities
CREATE (eq:Entity {
  name: 'Equipment_Pump_001',
  type: 'equipment',
  description: 'Main circulation pump',
  status: 'operational'
})
RETURN eq;

CREATE (loc:Entity {
  name: 'Location_Section_A',
  type: 'location',
  description: 'Section A of the facility',
  status: 'active'
})
RETURN loc;

// Create relationships between sample data
MATCH (d:Document {id: 'doc_001'}), (e:Entity {name: 'Equipment_Pump_001'})
CREATE (d)-[:REFERENCES]->(e)
RETURN d, e;

MATCH (e1:Entity {name: 'Equipment_Pump_001'}), (e2:Entity {name: 'Location_Section_A'})
CREATE (e1)-[:LOCATED_IN]->(e2)
RETURN e1, e2;
