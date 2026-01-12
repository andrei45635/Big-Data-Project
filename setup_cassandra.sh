#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== Setting Up Cassandra Schema ===${NC}\n"

# Check if Cassandra is running
if ! sudo docker ps | grep -q cassandra; then
    echo -e "${RED}✗ Cassandra container is not running${NC}"
    echo -e "${YELLOW}Start it with: sudo docker-compose up -d cassandra${NC}"
    exit 1
fi

# Wait for Cassandra to be ready
echo -e "${YELLOW}Waiting for Cassandra to be ready...${NC}"
for i in {1..30}; do
    if sudo docker exec cassandra cqlsh -e "DESCRIBE KEYSPACES" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Cassandra is ready${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo -e "\n${YELLOW}Creating keyspace and tables...${NC}"

# Create schema
sudo docker exec cassandra cqlsh << 'EOF'
-- Create keyspace
CREATE KEYSPACE IF NOT EXISTS air_quality
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

USE air_quality;

-- Time window table (1-hour windows)
CREATE TABLE IF NOT EXISTS hourly_metrics (
    city_name text,
    window_start timestamp,
    window_end timestamp,
    avg_aqi double,
    max_aqi int,
    min_aqi int,
    avg_pm25 double,
    avg_pm10 double,
    avg_temperature double,
    avg_humidity double,
    record_count int,
    PRIMARY KEY ((city_name), window_start)
) WITH CLUSTERING ORDER BY (window_start DESC);

-- Latest readings table (for real-time dashboard)
CREATE TABLE IF NOT EXISTS latest_readings (
    city_name text,
    station_name text,
    timestamp timestamp,
    aqi int,
    pm25 double,
    pm10 double,
    temperature double,
    humidity double,
    PRIMARY KEY ((city_name), timestamp, station_name)
) WITH CLUSTERING ORDER BY (timestamp DESC);

-- Create indexes
CREATE INDEX IF NOT EXISTS ON hourly_metrics (window_start);
CREATE INDEX IF NOT EXISTS ON latest_readings (timestamp);

-- Verify
DESCRIBE TABLES;
EOF

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Cassandra schema created successfully${NC}"

    # Show the schema
    echo -e "\n${YELLOW}Created tables:${NC}"
    sudo docker exec cassandra cqlsh -e "USE air_quality; DESCRIBE TABLES;"
else
    echo -e "\n${RED}✗ Failed to create schema${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  1. Make sure API fetcher sends to 'air-quality-realtime' topic"
echo -e "  2. Start Cassandra Spark job: ${GREEN}./start_pipeline.sh${NC}"
echo -e "  3. Check data: ${GREEN}./check_cassandra.sh${NC}"