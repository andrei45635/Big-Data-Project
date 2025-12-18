#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=== Air Quality Pipeline Status ===${NC}\n"

# Check services
check_service() {
    if pgrep -f "$1" > /dev/null; then
        echo -e "${GREEN}✓${NC} $2 is running"
        return 0
    else
        echo -e "${RED}✗${NC} $2 is not running"
        return 1
    fi
}

# WSL2 Services
echo -e "${BLUE}WSL2 Services:${NC}"
check_service "kafka.Kafka" "Kafka"
check_service "fetch_programmatic_api.py" "Python API Fetcher"

# Docker Containers
echo -e "\n${BLUE}Docker Containers:${NC}"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -1
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "namenode|datanode|spark|mongodb|grafana"

# Spark Applications
echo -e "\n${BLUE}Spark Applications:${NC}"
SPARK_APPS=$(curl -s http://localhost:8081/json/ 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
if [ -n "$SPARK_APPS" ]; then
    echo -e "${GREEN}✓${NC} Running: $SPARK_APPS"
else
    echo -e "${RED}✗${NC} No Spark applications running"
fi

# HDFS Data
echo -e "\n${BLUE}HDFS Storage:${NC}"
HDFS_SIZE=$(sudo docker exec namenode hdfs dfs -du -h /air-quality/historical/ 2>/dev/null | tail -1)
if [ -n "$HDFS_SIZE" ]; then
    echo -e "${GREEN}✓${NC} Data size: $HDFS_SIZE"

    # Count files per city
    echo -e "\n${BLUE}Files by City:${NC}"
    for city in Bucharest Beijing London; do
        FILE_COUNT=$(sudo docker exec namenode hdfs dfs -ls /air-quality/historical/city_name=$city/ 2>/dev/null | grep -c "\.parquet")
        if [ $FILE_COUNT -gt 0 ]; then
            echo -e "  ${GREEN}$city${NC}: $FILE_COUNT parquet files"
        fi
    done
else
    echo -e "${RED}✗${NC} No data in HDFS yet"
fi

# MongoDB Data
echo -e "\n${BLUE}MongoDB Storage:${NC}"
MONGO_COUNT=$(sudo docker exec mongodb mongosh --quiet --eval "db.getSiblingDB('air_quality').measurements.countDocuments()" 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$MONGO_COUNT" ] && [ "$MONGO_COUNT" != "0" ]; then
    echo -e "${GREEN}✓${NC} Documents: $MONGO_COUNT"

    # Show records per city
    echo -e "\n${BLUE}Records by City:${NC}"
    sudo docker exec mongodb mongosh --quiet --eval "
        db.getSiblingDB('air_quality').measurements.aggregate([
            { \$group: { _id: '\$city_name', count: { \$sum: 1 }, avg_aqi: { \$avg: '\$aqi' } } },
            { \$sort: { count: -1 } }
        ]).forEach(doc => print('  ' + doc._id + ': ' + doc.count + ' records (avg AQI: ' + Math.round(doc.avg_aqi) + ')'))
    " 2>/dev/null
else
    echo -e "${YELLOW}⚠${NC}  No data in MongoDB yet (run ./sync_to_mongodb.sh)"
fi

# PostgreSQL Data
echo -e "\n${BLUE}PostgreSQL Storage:${NC}"
PG_COUNT=$(sudo docker exec postgres psql -U postgres -d air_quality -t -c "SELECT COUNT(*) FROM air_quality_data" 2>/dev/null | tr -d ' ')
if [ $? -eq 0 ] && [ -n "$PG_COUNT" ] && [ "$PG_COUNT" != "0" ]; then
    echo -e "${GREEN}✓${NC} Records: $PG_COUNT"

    echo -e "\n${BLUE}Records by City:${NC}"
    sudo docker exec postgres psql -U postgres -d air_quality -t -c "
        SELECT '  ' || city_name || ': ' || COUNT(*) || ' records (avg AQI: ' || ROUND(AVG(aqi)) || ')'
        FROM air_quality_data
        GROUP BY city_name
        ORDER BY COUNT(*) DESC
    " 2>/dev/null
else
    echo -e "${YELLOW}⚠${NC}  No data in PostgreSQL yet (run ./sync_to_postgres.sh)"
fi

# Kafka Topics
echo -e "\n${BLUE}Kafka Topics:${NC}"
if pgrep -f "kafka.Kafka" > /dev/null; then
    cd ~/kafka_* 2>/dev/null
    TOPIC_INFO=$(bin/kafka-topics.sh --describe --bootstrap-server localhost:9092 --topic air-quality-historical 2>/dev/null | grep "PartitionCount")
    if [ -n "$TOPIC_INFO" ]; then
        echo -e "${GREEN}✓${NC} air-quality-historical: $TOPIC_INFO"
    fi

    # Check recent messages
    RECENT_MSG=$(bin/kafka-console-consumer.sh \
        --bootstrap-server localhost:9092 \
        --topic air-quality-historical \
        --from-beginning \
        --max-messages 1 \
        --timeout-ms 3000 2>/dev/null | head -c 100)

    if [ -n "$RECENT_MSG" ]; then
        echo -e "${GREEN}✓${NC} Recent messages available"
    else
        echo -e "${YELLOW}⚠${NC}  No messages in topic yet"
    fi
fi

# Web Interfaces
echo -e "\n${BLUE}Web Interfaces:${NC}"
echo -e "  Spark Master:   http://localhost:8081"
echo -e "  Hadoop HDFS:    http://localhost:9870"
echo -e "  Grafana:        http://localhost:3000"

# Log Files
echo -e "\n${BLUE}Recent Log Entries:${NC}"
if [ -f /tmp/api-fetcher.log ]; then
    LAST_FETCH=$(tail -1 /tmp/api-fetcher.log 2>/dev/null)
    echo -e "  API Fetcher: ${LAST_FETCH:0:100}..."
fi

echo -e "\n${YELLOW}Tip: Use './sync_to_mongodb.sh' to sync HDFS data to MongoDB for Grafana${NC}"
echo -e "\n${YELLOW}Another tip: Use './sync_to_postgres.sh' to sync HDFS data to PostgreSQL for Grafana${NC}"