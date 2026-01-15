#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Starting Cassandra Speed Layer ===${NC}\n"

# Make sure Cassandra is running
if ! sudo docker ps | grep -q cassandra; then
    echo -e "${YELLOW}Starting Cassandra container...${NC}"
    sudo docker start cassandra
    sleep 60
fi

# Start Spark job
echo -e "${YELLOW}Starting Spark streaming job...${NC}"
sudo docker exec -u root -d spark-master bash -c "nohup /opt/spark/bin/spark-submit \
    --master spark://spark-master:7077 \
    --total-executor-cores 4 \
    --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.3,com.datastax.spark:spark-cassandra-connector_2.12:3.4.1 \
    /opt/spark-apps/kafka_to_cassandra.py > /tmp/spark-cassandra.log 2>&1 &"

echo -e "${GREEN}✓ Cassandra speed layer started${NC}"
echo -e "Check status with: ./check_cassandra.sh"