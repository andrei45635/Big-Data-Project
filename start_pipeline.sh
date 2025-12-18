#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Air Quality Data Pipeline Startup ===${NC}\n"

# Configuration
KAFKA_DIR="$HOME/kafka_2.13-4.1.1"  # Adjust to your Kafka directory
PROJECT_DIR="/mnt/c/users/gigabyte/onedrive/desktop/master/semestrul 3/big data/"  # Adjust to your project path
PYTHON_SCRIPT="fetch_programmatic_api.py"

# Function to check if a service is running
check_service() {
    if pgrep -f "$1" > /dev/null; then
        echo -e "${GREEN}✓${NC} $2 is running"
        return 0
    else
        echo -e "${RED}✗${NC} $2 is not running"
        return 1
    fi
}

# Function to wait for service
wait_for_service() {
    echo -e "${YELLOW}Waiting for $1...${NC}"
    sleep $2
}

# 1. Start Docker Compose (Hadoop, Spark, MongoDB, Grafana)
echo -e "${YELLOW}[1/6] Starting Docker containers...${NC}"
cd "$PROJECT_DIR/hadoop-cluster"
sudo docker-compose up -d

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Docker containers started${NC}"
    wait_for_service "Docker services" 30
else
    echo -e "${RED}✗ Failed to start Docker containers${NC}"
    exit 1
fi

# 2. Start Kafka
echo -e "\n${YELLOW}[2/6] Starting Kafka...${NC}"
if ! check_service "kafka" "Kafka"; then
    cd "$KAFKA_DIR"
    nohup bin/kafka-server-start.sh config/server.properties > /tmp/kafka.log 2>&1 &
    wait_for_service "Kafka" 15

    if check_service "kafka" "Kafka"; then
        echo -e "${GREEN}✓ Kafka started successfully${NC}"
    else
        echo -e "${RED}✗ Failed to start Kafka. Check /tmp/kafka.log${NC}"
        exit 1
    fi
fi

# 3. Verify Kafka topics
echo -e "\n${YELLOW}[3/6] Verifying Kafka topics...${NC}"
cd "$KAFKA_DIR"
TOPICS=$(bin/kafka-topics.sh --list --bootstrap-server localhost:9092 2>/dev/null)

if echo "$TOPICS" | grep -q "air-quality-historical"; then
    echo -e "${GREEN}✓ Kafka topics exist${NC}"
else
    echo -e "${YELLOW}Creating Kafka topics...${NC}"
    bin/kafka-topics.sh --create --topic air-quality-historical \
        --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 2>/dev/null
    bin/kafka-topics.sh --create --topic air-quality-realtime \
        --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 2>/dev/null
    echo -e "${GREEN}✓ Kafka topics created${NC}"
fi

# 4. Install pymongo in Spark container (if not already installed)
echo -e "\n${YELLOW}[4/6] Setting up Spark dependencies...${NC}"
sudo docker exec -u root spark-master pip install pymongo --quiet 2>/dev/null
echo -e "${GREEN}✓ Spark dependencies ready${NC}"

# 4.a Check PostgreSQL
echo -e "\n${YELLOW}Verifying PostgreSQL...${NC}"
sleep 5
if sudo docker exec postgres psql -U postgres -d air_quality -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
else
    echo -e "${YELLOW}⚠ PostgreSQL starting up...${NC}"
fi

# 5. Start Spark Streaming Job (Kafka → HDFS)
echo -e "\n${YELLOW}[5/6] Starting Spark Streaming job (Kafka → HDFS)...${NC}"
sudo docker exec -u root -d spark-master bash -c "nohup /opt/spark/bin/spark-submit \
    --master spark://spark-master:7077 \
    --total-executor-cores 8 \
    --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.3 \
    /opt/spark-apps/kafka_to_hdfs.py > /tmp/spark-streaming.log 2>&1 &"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Spark Streaming job submitted${NC}"
    wait_for_service "Spark job initialization" 10
else
    echo -e "${RED}✗ Failed to submit Spark job${NC}"
    exit 1
fi

# 6. Start Python API Fetcher
echo -e "\n${YELLOW}[6/6] Starting Python API fetcher...${NC}"
cd "$PROJECT_DIR"
if ! check_service "$PYTHON_SCRIPT" "Python API fetcher"; then
    nohup python3 "$PYTHON_SCRIPT" > /tmp/api-fetcher.log 2>&1 &
    wait_for_service "API fetcher" 5

    if check_service "$PYTHON_SCRIPT" "Python API fetcher"; then
        echo -e "${GREEN}✓ Python API fetcher started${NC}"
    else
        echo -e "${RED}✗ Failed to start API fetcher. Check /tmp/api-fetcher.log${NC}"
        exit 1
    fi
fi

# Summary
echo -e "\n${GREEN}=== Pipeline Started Successfully ===${NC}"
echo -e "\n${YELLOW}Service Status:${NC}"
check_service "kafka" "Kafka"
check_service "$PYTHON_SCRIPT" "Python API Fetcher"
echo ""
sudo docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "namenode|datanode|spark|mongodb|grafana"

echo -e "\n${YELLOW}Useful URLs:${NC}"
echo -e "  Spark Master UI:    http://localhost:8081"
echo -e "  Hadoop NameNode UI: http://localhost:9870"
echo -e "  HDFS Explorer:      http://localhost:9870/explorer.html#/air-quality/historical"
echo -e "  Grafana Dashboard:  http://localhost:3000 (admin/admin)"

echo -e "\n${YELLOW}Log files:${NC}"
echo -e "  Kafka:           /tmp/kafka.log"
echo -e "  API Fetcher:     /tmp/api-fetcher.log"
echo -e "  Spark Streaming: (check with: sudo docker exec spark-master cat /tmp/spark-streaming.log)"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "  1. Wait 5-10 minutes for data to accumulate in HDFS"
echo -e "  2. Run sync script to push data to PostgreSQL:"
echo -e "     ${GREEN}./sync_to_postgres.sh${NC}"
echo -e "  3. Configure Grafana data source and create dashboards"

echo -e "\n${YELLOW}To stop the pipeline, run: ./stop_pipeline.sh${NC}"