# Neo4j Integration with n8n

This guide explains how to set up and use Neo4j graph database with n8n in your on-premises RAG system.

## Overview

Neo4j is a graph database that stores data as nodes and relationships. It's perfect for:
- Linking documents to entities (equipment, locations, processes)
- Creating knowledge graphs from your documentation
- Finding related information through graph traversal
- Enhancing RAG with structured relationships

## Architecture

```
n8n (Port 5678) ──┬──> Neo4j (Port 7687 - Bolt)
                   └──> Neo4j (Port 7474 - Web UI)
```

## Setup Instructions

### 1. Update docker-compose.yml

The configuration has been updated with:
- **Neo4j service** with APOC plugins enabled
- **Environment variables** for Neo4j credentials
- **Health checks** to ensure Neo4j is ready before n8n starts
- **Volumes** for persistent data and logs

### 2. Start the Services

```bash
# Pull latest images
docker-compose pull

# Start all services
docker-compose up -d

# Verify Neo4j is running
docker-compose logs neo4j
```

### 3. Access Neo4j

**Web Browser (Browser UI):**
- URL: http://localhost:7474
- Default credentials:
  - Username: `neo4j`
  - Password: `Mohsen1105$` (change in docker-compose.yml)

**Cypher Shell:**
```bash
docker exec -it ai-neo4j cypher-shell -u neo4j -p your-password-here
```

## Configuration


### Neo4j Environment Variables

In `docker-compose.yml`, Neo4j uses:

```yaml
environment:
  - NEO4J_AUTH=neo4j/Mohsen1105$     # Change this password!
  - NEO4J_PLUGINS=["apoc"]                   # Advanced procedures
  - NEO4J_dbms_security_procedures_unrestricted=apoc.*
  - NEO4J_dbms_memory_heap_initial_size=512m
  - NEO4J_dbms_memory_heap_max_size=2G
```

### n8n Connection Variables

n8n can access Neo4j via environment variables:

```yaml
- NEO4J_HOST=neo4j          # Docker network hostname
- NEO4J_PORT=7687          # Bolt protocol port
- NEO4J_USER=neo4j
- NEO4J_PASSWORD=your-password-here
```

## Schema Design

### Node Types

**Document**
- Properties: `id`, `title`, `type`, `created_at`, `source`, `status`
- Example: Technical manuals, operational reports

**Chunk**
- Properties: `id`, `text`, `embedding_id`, `page`, `position`, `created_at`
- Represents portions of documents for RAG

**Entity**
- Properties: `name`, `type`, `description`, `status`, `created_at`
- Types: `equipment`, `location`, `process`, `person`, `system`

**Query**
- Properties: `id`, `text`, `timestamp`, `result_count`
- For analytics and query tracking

### Relationship Types

| Relationship | From | To | Purpose |
|---|---|---|---|
| `CONTAINS` | Document | Chunk | Document structure |
| `MENTIONS` | Chunk | Entity | Text mentions entity |
| `REFERENCES` | Document | Entity | Document references entity |
| `LOCATED_IN` | Entity | Entity | Location relationships |
| `PART_OF` | Entity | Entity | Hierarchical relationships |
| `USED_BY` | Entity | Entity | Usage relationships |

## Using Neo4j with n8n

### Method 1: Native Cypher Queries

Create an n8n workflow node using HTTP request:

```json
{
  "method": "POST",
  "url": "http://neo4j:7687",
  "headers": {
    "Authorization": "Basic bmVvNGo6eW91ci1wYXNzd29yZC1oZXJl",
    "Content-Type": "application/json"
  },
  "body": {
    "statements": [
      {
        "statement": "MATCH (d:Document) WHERE d.type = 'technical_manual' RETURN d LIMIT 10"
      }
    ]
  }
}
```

### Method 2: Python Script Node

Use the Neo4j Python driver in n8n Code nodes:

```python
# Install in n8n: pip install neo4j

from neo4j import GraphDatabase

driver = GraphDatabase.driver("bolt://neo4j:7687", auth=("neo4j", "your-password-here"))

with driver.session() as session:
    result = session.run("MATCH (n:Document) RETURN n LIMIT 5")
    documents = [record.data() for record in result]

# Return to n8n
return documents
```

### Method 3: Using the Connector Class

Create documents and entities from your RAG system:

```python
from neo4j_connector import Neo4jConnector

connector = Neo4jConnector(
    uri="bolt://neo4j:7687",
    user="neo4j",
    password="your-password-here"
)

# Create a document
connector.create_document(
    doc_id="doc_001",
    title="Equipment Manual",
    doc_type="technical_manual",
    source="uploaded"
)

# Create entities
connector.create_entity(
    name="Pump_A1",
    entity_type="equipment",
    description="Main circulation pump"
)

# Link them
connector.link_chunk_to_entity("chunk_001", "Pump_A1")

connector.close()
```

## n8n Workflow Examples

### Example 1: Ingest Documents into Neo4j

```cypher
# Trigger: File uploaded
# Node 1: Extract document metadata
# Node 2: Create Document node in Neo4j

MATCH (n) WHERE n.id = $doc_id RETURN n
  -- If doesn't exist:
CREATE (d:Document {
  id: $doc_id,
  title: $title,
  type: $type,
  created_at: datetime(),
  source: 'n8n_upload',
  status: 'active'
})
RETURN d
```

### Example 2: Find Related Documentation

```cypher
# Trigger: User searches for "Pump A1"
# Query Neo4j for related chunks

MATCH (chunk:Chunk)-[:MENTIONS]->(e:Entity {name: 'Pump_A1'})
MATCH (chunk)<-[:CONTAINS]-(doc:Document)
RETURN doc, chunk
LIMIT 10
```

### Example 3: Build Knowledge Graph Relationships

```cypher
# Create relationships between entities based on document mentions

MATCH (c:Chunk)-[:MENTIONS]->(e1:Entity)
WITH c, collect(e1) as entities
UNWIND entities as entity1
UNWIND entities as entity2
WHERE entity1.name < entity2.name
CREATE (entity1)-[:CO_MENTIONED {in_chunk: c.id}]->(entity2)
```

## Monitoring and Maintenance

### Check Database Health

```bash
# Via n8n HTTP node or terminal:
curl -u neo4j:your-password-here http://localhost:7474/db/neo4j/metrics/memory
```

### View Database Statistics

In Neo4j Browser:
```cypher
MATCH (n)
WITH labels(n) as labels, count(*) as count
RETURN labels, count
ORDER BY count DESC
```

### Backup Neo4j Data

```bash
# Backup to local directory
docker exec ai-neo4j neo4j-admin database dump neo4j > neo4j_backup.dump

# Restore from backup
docker exec ai-neo4j neo4j-admin database load neo4j < neo4j_backup.dump
```

### Clear All Data (Development Only)

```bash
# In Neo4j Browser:
MATCH (n) DETACH DELETE n;
```

## Common Cypher Queries

### Search for equipment
```cypher
MATCH (e:Entity {type: 'equipment'})
RETURN e.name, e.description
```

### Find documents mentioning an entity
```cypher
MATCH (d:Document)-[:CONTAINS]->(c:Chunk)-[:MENTIONS]->(e:Entity {name: 'Pump_A1'})
RETURN DISTINCT d.title, count(c) as mention_count
```

### Get entity context (relationships)
```cypher
MATCH (e:Entity {name: 'Pump_A1'})
OPTIONAL MATCH (e)-[r]->(related)
RETURN e, collect({type: type(r), target: related.name})
```

### Most mentioned entities
```cypher
MATCH (c:Chunk)-[:MENTIONS]->(e:Entity)
RETURN e.name, count(c) as mention_count
ORDER BY mention_count DESC
LIMIT 10
```

## Troubleshooting

### Neo4j won't start

```bash
# Check logs
docker-compose logs neo4j

# Verify password syntax
docker-compose exec neo4j cypher-shell -u neo4j -p "your-password-here"
```

### Connection refused from n8n

1. Verify Neo4j is healthy: `docker-compose ps`
2. Check port is exposed: `netstat -an | grep 7687`
3. Verify network: `docker network inspect ai-network`

### Out of memory errors

Increase heap size in docker-compose.yml:
```yaml
- NEO4J_dbms_memory_heap_max_size=4G
```

### Performance issues

Add indexes for frequently queried properties:
```cypher
CREATE INDEX entity_type IF NOT EXISTS
FOR (e:Entity) ON (e.type);

CREATE INDEX doc_type IF NOT EXISTS
FOR (d:Document) ON (d.type);
```

## Security Notes

1. **Change default password** in docker-compose.yml before production
2. **Enable encryption** for remote connections
3. **Restrict APOC procedures** if not needed
4. **Use environment variables** for credentials
5. **Enable authentication** in Neo4j configuration

## Performance Tips

1. **Use indexes** for frequently searched properties
2. **Batch operations** when loading large datasets
3. **Monitor memory** usage in Neo4j Browser
4. **Set appropriate heap size** based on your data volume
5. **Use pagination** in large result sets
6. **Create constraints** for data integrity

## Resources

- [Neo4j Documentation](https://neo4j.com/docs/)
- [Cypher Query Language](https://neo4j.com/docs/cypher-manual/current/)
- [APOC Procedures](https://neo4j.com/labs/apoc/)
- [n8n Integration Examples](https://docs.n8n.io/)

## Next Steps

1. Change `your-password-here` to a secure password in docker-compose.yml
2. Start services: `docker-compose up -d`
3. Access Neo4j Browser: http://localhost:7474
4. Run initialization script in Neo4j Browser
5. Create n8n workflows that use Neo4j
