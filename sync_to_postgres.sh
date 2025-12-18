#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== Syncing HDFS to PostgreSQL ===${NC}\n"

# Check if Docker is running
if ! sudo docker ps | grep -q spark-master; then
    echo -e "${RED}✗ Spark container is not running. Start the pipeline first.${NC}"
    exit 1
fi

# Check if PostgreSQL is running
if ! sudo docker ps | grep -q postgres; then
    echo -e "${RED}✗ PostgreSQL container is not running. Start the pipeline first.${NC}"
    exit 1
fi

# Run the sync job
echo -e "${YELLOW}Running Spark job to sync data...${NC}"
sudo docker exec -u root spark-master /opt/spark/bin/spark-submit \
    --master spark://spark-master:7077 \
    --packages org.postgresql:postgresql:42.6.0 \
    /opt/spark-apps/hdfs_to_postgres.py

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Sync completed successfully${NC}"

    # Show PostgreSQL stats
    echo -e "\n${YELLOW}PostgreSQL Statistics:${NC}"
    sudo docker exec postgres psql -U postgres -d air_quality -c "
        SELECT
            city_name AS \"City\",
            COUNT(*) AS \"Records\",
            ROUND(AVG(aqi)::numeric, 1) AS \"Avg AQI\",
            MAX(aqi) AS \"Max AQI\",
            MIN(timestamp) AS \"Oldest Data\",
            MAX(timestamp) AS \"Latest Data\"
        FROM air_quality_data
        GROUP BY city_name
        ORDER BY \"Avg AQI\" DESC;
    "

    echo -e "\n${YELLOW}Total records in database:${NC}"
    sudo docker exec postgres psql -U postgres -d air_quality -t -c "
        SELECT COUNT(*) FROM air_quality_data;
    " | tr -d ' '
else
    echo -e "\n${RED}✗ Sync failed. Check logs for details.${NC}"
    exit 1
fi