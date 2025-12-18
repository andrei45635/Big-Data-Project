#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Stopping Air Quality Data Pipeline ===${NC}\n"

PROJECT_DIR="/mnt/c/users/gigabyte/onedrive/desktop/master/semestrul 3/big data/"
PYTHON_SCRIPT="fetch_programmatic_api.py"

# 1. Stop Python API Fetcher
echo -e "${YELLOW}[1/5] Stopping Python API fetcher...${NC}"
pkill -f "$PYTHON_SCRIPT"
echo -e "${GREEN}✓ Python API fetcher stopped${NC}"

# 2. Stop Spark Streaming Job
echo -e "\n${YELLOW}[2/5] Stopping Spark Streaming job...${NC}"
sudo docker exec spark-master pkill -f "kafka_to_hdfs.py" 2>/dev/null
echo -e "${GREEN}✓ Spark Streaming job stopped${NC}"

# 3. Stop MongoDB sync job (if running)
echo -e "\n${YELLOW}[3/5] Stopping MongoDB sync job...${NC}"
pkill -f "sync_to_mongodb.sh" 2>/dev/null
sudo docker exec spark-master pkill -f "hdfs_to_mongodb.py" 2>/dev/null
echo -e "${GREEN}✓ MongoDB sync job stopped${NC}"

# 3a. Stop PostgreSQL sync job (if running)
echo -e "\n${YELLOW}[3/5] Stopping PostgreSQL sync job...${NC}"
pkill -f "sync_to_postgres.sh" 2>/dev/null
sudo docker exec spark-master pkill -f "hdfs_to_postgres.py" 2>/dev/null
echo -e "${GREEN}✓ PostgreSQL sync job stopped${NC}"

# 4. Stop Kafka
echo -e "\n${YELLOW}[4/5] Stopping Kafka...${NC}"
pkill -f "kafka.Kafka"
sleep 3
echo -e "${GREEN}✓ Kafka stopped${NC}"

# 5. Stop Docker Containers
echo -e "\n${YELLOW}[5/5] Stopping Docker containers...${NC}"
cd "$PROJECT_DIR/hadoop-cluster"
sudo docker-compose down
echo -e "${GREEN}✓ Docker containers stopped${NC}"

echo -e "\n${GREEN}=== Pipeline Stopped ===${NC}"
echo -e "${YELLOW}Note: Data in HDFS and MongoDB is preserved in Docker volumes${NC}"