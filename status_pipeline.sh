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
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "namenode|datanode|spark|postgres|cassandra|grafana"

# Spark Applications
echo -e "\n${BLUE}Spark Applications:${NC}"
SPARK_APPS=$(curl -s http://localhost:8081/json/ 2>/dev/null | python3 -c "import sys, json; apps = json.load(sys.stdin).get('activeapps', []); print(', '.join([a['name'] for a in apps]))" 2>/dev/null)
if [ -n "$SPARK_APPS" ]; then
    echo -e "${GREEN}✓${NC} Running: $SPARK_APPS"
else
    echo -e "${RED}✗${NC} No Spark applications running"
fi

# HDFS Data (Batch Layer)
echo -e "\n${BLUE}HDFS Storage (Batch Layer):${NC}"
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

# PostgreSQL Data (Serving Layer)
echo -e "\n${BLUE}PostgreSQL Storage (Serving Layer):${NC}"
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

# Cassandra Data (Speed Layer)
echo -e "\n${BLUE}Cassandra Storage (Speed Layer):${NC}"
CASS_LATEST=$(sudo docker exec cassandra cqlsh -e "SELECT COUNT(*) FROM air_quality.latest_readings;" 2>/dev/null | grep -oE '[0-9]+' | tail -1)
CASS_HOURLY=$(sudo docker exec cassandra cqlsh -e "SELECT COUNT(*) FROM air_quality.hourly_metrics;" 2>/dev/null | grep -oE '[0-9]+' | tail -1)

if [ -n "$CASS_LATEST" ] && [ "$CASS_LATEST" != "0" ]; then
    echo -e "${GREEN}✓${NC} Latest readings: $CASS_LATEST"
    echo -e "${GREEN}✓${NC} Hourly windows: $CASS_HOURLY"

    echo -e "\n${BLUE}Recent Time Windows:${NC}"
    sudo docker exec cassandra cqlsh -e "
        SELECT city_name, window_start, avg_aqi, record_count
        FROM air_quality.hourly_metrics
        LIMIT 5;" 2>/dev/null | grep -v "^$" | tail -7
else
    echo -e "${YELLOW}⚠${NC}  No data in Cassandra yet (may need time to accumulate)"
fi

# Kafka Topics
echo -e "\n${BLUE}Kafka Topics:${NC}"
if pgrep -f "kafka.Kafka" > /dev/null; then
    cd ~/kafka_* 2>/dev/null

    # Historical topic
    HIST_OFFSET=$(bin/kafka-get-offsets.sh --bootstrap-server localhost:9092 --topic air-quality-historical 2>/dev/null | grep -oE '[0-9]+$' | tail -1)
    if [ -n "$HIST_OFFSET" ]; then
        echo -e "${GREEN}✓${NC} air-quality-historical: $HIST_OFFSET messages"
    fi

    # Realtime topic
    RT_OFFSET=$(bin/kafka-get-offsets.sh --bootstrap-server localhost:9092 --topic air-quality-realtime 2>/dev/null | grep -oE '[0-9]+$' | tail -1)
    if [ -n "$RT_OFFSET" ]; then
        echo -e "${GREEN}✓${NC} air-quality-realtime: $RT_OFFSET messages"
    fi
fi

# Web Interfaces
echo -e "\n${BLUE}Web Interfaces:${NC}"
echo -e "  Spark Master:   http://localhost:8081"
echo -e "  Hadoop HDFS:    http://localhost:9870"
echo -e "  Grafana:        http://localhost:3000"

# Lambda Architecture Summary
echo -e "\n${BLUE}Lambda Architecture Status:${NC}"
if [ -n "$HDFS_SIZE" ]; then
    echo -e "  ${GREEN}✓${NC} Batch Layer:  HDFS operational"
else
    echo -e "  ${RED}✗${NC} Batch Layer:  No HDFS data"
fi

if [ -n "$CASS_LATEST" ] && [ "$CASS_LATEST" != "0" ]; then
    echo -e "  ${GREEN}✓${NC} Speed Layer:  Cassandra operational"
else
    echo -e "  ${YELLOW}⚠${NC}  Speed Layer:  Cassandra waiting for data"
fi

if [ -n "$PG_COUNT" ] && [ "$PG_COUNT" != "0" ]; then
    echo -e "  ${GREEN}✓${NC} Serving Layer: PostgreSQL ready"
else
    echo -e "  ${YELLOW}⚠${NC}  Serving Layer: Run sync_to_postgres.sh"
fi

echo -e "\n${YELLOW}Quick Commands:${NC}"
echo -e "  Sync to PostgreSQL:     ${GREEN}./sync_to_postgres.sh${NC}"
echo -e "  Check Cassandra:        ${GREEN}./check_cassandra.sh${NC}"
echo -e "  Stop pipeline:          ${GREEN}./stop_pipeline.sh${NC}"