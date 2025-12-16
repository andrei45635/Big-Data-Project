#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Pipeline Status ===${NC}\n"

# Check services
check_service() {
    if pgrep -f "$1" > /dev/null; then
        echo -e "${GREEN}✓${NC} $2 is running"
    else
        echo -e "${RED}✗${NC} $2 is not running"
    fi
}

echo -e "${YELLOW}WSL2 Services:${NC}"
check_service "kafka.Kafka" "Kafka"
check_service "fetch_programmatic_api.py" "Python API Fetcher"

echo -e "\n${YELLOW}Docker Containers:${NC}"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\n${YELLOW}HDFS Data:${NC}"
sudo docker exec namenode hdfs dfs -du -h /air-quality/historical/ 2>/dev/null || echo "No data yet"

echo -e "\n${YELLOW}Recent Kafka Messages:${NC}"
~/kafka_*/bin/kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic air-quality-historical \
    --from-beginning \
    --max-messages 1 \
    --timeout-ms 5000 2>/dev/null || echo "No messages yet"