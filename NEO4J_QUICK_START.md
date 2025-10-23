# Neo4j Quick Start Guide

## Status
✅ Neo4j is now running and integrated with n8n

## Access Neo4j

### Web Browser UI
- **URL:** http://localhost:7474
- **Username:** neo4j
- **Password:** Mohsen1105$

### Command Line (Cypher Shell)
```bash
docker exec -it ai-neo4j cypher-shell -u neo4j -p Mohsen1105$
```

### Bolt Connection (for applications)
```
bolt://localhost:7687
Username: neo4j
Password: Mohsen1105$
```

## Verify Connection from n8n

In n8n, you can test the Neo4j connection using an HTTP node or by running Cypher queries directly.

### Using HTTP (Bolt over HTTP)
```bash
curl -u neo4j:Mohsen1105$ \
  -X POST http://localhost:7687 \
  -H "Content-Type: application/json" \
  -d '{"statements":[{"statement":"RETURN 1"}]}'
```

## Next Steps

1. **Access Neo4j Browser:** Open http://localhost:7474
2. **Login:** Use credentials above
3. **Create sample data:** Run the initialization script from `neo4j/init/01-init.cypher`
4. **Create n8n workflows:** Use the examples in `NEO4J_SETUP.md`

## Sample Cypher Queries

### Create a test document
```cypher
CREATE (d:Document {
  id: 'test_doc_001',
  title: 'Test Document',
  type: 'test',
  created_at: datetime(),
  status: 'active'
})
RETURN d;
```

### Create a test entity
```cypher
CREATE (e:Entity {
  name: 'Test_Equipment',
  type: 'equipment',
  description: 'A test equipment node',
  status: 'operational'
})
RETURN e;
```

### Check all nodes
```cypher
MATCH (n) RETURN n LIMIT 25;
```

### Database stats
```cypher
MATCH (n)
WITH labels(n) as labels, count(*) as count
RETURN labels, count
ORDER BY count DESC;
```

## Useful Resources

- **Neo4j Documentation:** https://neo4j.com/docs/
- **Cypher Cheat Sheet:** https://neo4j.com/docs/cypher-manual/current/
- **Full Setup Guide:** See `NEO4J_SETUP.md`

## Troubleshooting

### Connection refused?
```bash
# Check if Neo4j is running
docker-compose ps neo4j

# View logs
docker-compose logs neo4j
```

### Can't login to browser?
1. Verify password: `Mohsen1105$`
2. Make sure ports are exposed: `docker-compose ps`
3. Try clearing browser cache

### Need to reset Neo4j?
```bash
# Stop and remove Neo4j
docker-compose down neo4j

# Remove data volumes (WARNING: deletes all data)
docker volume rm on-premises-rag_neo4j-data on-premises-rag_neo4j-logs

# Restart
docker-compose up -d neo4j
```

## Integration with n8n

n8n can now access Neo4j using:
- **Environment variables:** `NEO4J_HOST`, `NEO4J_PORT`, `NEO4J_USER`, `NEO4J_PASSWORD`
- **Python driver:** `pip install neo4j`
- **HTTP requests:** POST to Bolt endpoint
- **Connector class:** Use `neo4j/neo4j_connector.py`

See `NEO4J_SETUP.md` for detailed workflow examples.
