#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== Running ML Prediction Job ===${NC}\n"

# Check if Cassandra is running
if ! sudo docker ps | grep -q cassandra; then
    echo -e "${RED}✗ Cassandra is not running${NC}"
    echo -e "${YELLOW}Start with: sudo docker start cassandra${NC}"
    exit 1
fi

# Check if PostgreSQL is running
if ! sudo docker ps | grep -q postgres; then
    echo -e "${RED}✗ PostgreSQL is not running${NC}"
    exit 1
fi

# Check if enough data exists in Cassandra
echo -e "${YELLOW}Checking data availability...${NC}"
RECORD_COUNT=$(sudo docker exec cassandra cqlsh -e \
    "SELECT COUNT(*) FROM air_quality.hourly_metrics WHERE city_name = 'Bucharest';" \
    2>/dev/null | grep -oE '[0-9]+' | tail -1)

#if [ -z "$RECORD_COUNT" ] || [ "$RECORD_COUNT" -lt 6 ]; then
#    echo -e "${RED}✗ Not enough data (need at least 6 hours)${NC}"
#    echo -e "${YELLOW}Current records: ${RECORD_COUNT:-0}${NC}"
#    exit 1
#fi

echo -e "${GREEN}✓ Found $RECORD_COUNT hourly records${NC}"

# Copy ML script to Spark container
echo -e "\n${YELLOW}Preparing ML environment...${NC}"
sudo docker exec spark-master mkdir -p /opt/spark-apps/ml_model

# Install Python dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo docker exec -u root spark-master pip install pandas numpy==1.24.3 scikit-learn joblib tensorflow

# Copy your ML model script
if [ -f "hadoop-cluster/spark-apps/ml_model/predict_aqi.py" ]; then
    sudo docker cp hadoop-cluster/spark-apps/ml_model/predict_aqi.py spark-master:/opt/spark-apps/ml_model/
    sudo docker cp AQD.csv spark-master:/opt/spark-apps/ml_model/
    sudo docker cp train_aqi_lstm.py spark-master:/opt/spark-apps/ml_model/
    sudo docker exec -it spark-master python3 /opt/spark-apps/ml_model/train_aqi_lstm.py /opt/spark-apps/ml_model/AQD.csv
    echo -e "${GREEN}✓ ML script copied${NC}"
else
    echo -e "${RED}✗ ML script not found at ml_model/predict_aqi.py${NC}"
    exit 1
fi

# Run the Spark job
echo -e "\n${YELLOW}Running Spark ML job...${NC}"
sudo docker exec -u root spark-master /opt/spark/bin/spark-submit \
    --master spark://spark-master:7077 \
    --packages com.datastax.spark:spark-cassandra-connector_2.12:3.4.1,org.postgresql:postgresql:42.6.0 \
    /opt/spark-apps/model_to_postgres.py

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ ML predictions completed successfully${NC}"

    # Show predictions
    echo -e "\n${YELLOW}Latest Predictions (PostgreSQL):${NC}"
    sudo docker exec postgres psql -U postgres -d air_quality -c \
        "SELECT city, aqi, timestamp
         FROM aqi_predictions
         ORDER BY timestamp DESC
         LIMIT 18;" 2>/dev/null
else
    echo -e "\n${RED}✗ ML prediction job failed${NC}"
    echo -e "${YELLOW}Check logs: sudo docker exec spark-master cat /tmp/spark-ml.log${NC}"
    exit 1
fi