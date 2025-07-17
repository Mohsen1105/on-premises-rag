#!/bin/bash
# scripts/backup.sh

# Backup script for AI Assistant
BACKUP_DIR="/backup/ai-assistant"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$DATE"

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Backup Docker volumes
echo "Backing up Docker volumes..."
docker run --rm -v ollama-data:/source:ro -v "$BACKUP_PATH":/backup alpine tar -czf /backup/ollama-data.tar.gz -C /source .
docker run --rm -v open-webui-data:/source:ro -v "$BACKUP_PATH":/backup alpine tar -czf /backup/open-webui-data.tar.gz -C /source .
docker run --rm -v chroma-data:/source:ro -v "$BACKUP_PATH":/backup alpine tar -czf /backup/chroma-data.tar.gz -C /source .
docker run --rm -v redis-data:/source:ro -v "$BACKUP_PATH":/backup alpine tar -czf /backup/redis-data.tar.gz -C /source .

# Backup configuration files
echo "Backing up configuration..."
tar -czf "$BACKUP_PATH/config.tar.gz" docker-compose.yml .env nginx/ api/

# Create restore script
cat > "$BACKUP_PATH/restore.sh" << 'EOF'
#!/bin/bash
# Restore AI Assistant from backup

echo "Stopping services..."
docker-compose down

echo "Restoring volumes..."
docker run --rm -v ollama-data:/target -v "$(pwd)":/backup alpine tar -xzf /backup/ollama-data.tar.gz -C /target
docker run --rm -v open-webui-data:/target -v "$(pwd)":/backup alpine tar -xzf /backup/open-webui-data.tar.gz -C /target
docker run --rm -v chroma-data:/target -v "$(pwd)":/backup alpine tar -xzf /backup/chroma-data.tar.gz -C /target
docker run --rm -v redis-data:/target -v "$(pwd)":/backup alpine tar -xzf /backup/redis-data.tar.gz -C /target

echo "Restoring configuration..."
tar -xzf config.tar.gz

echo "Starting services..."
docker-compose up -d

echo "Restore complete!"
EOF

chmod +x "$BACKUP_PATH/restore.sh"

# Clean old backups (keep last 7 days)
find "$BACKUP_DIR" -type d -mtime +7 -exec rm -rf {} +

echo "Backup completed: $BACKUP_PATH"
