#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== Syncing HDFS to MongoDB ===${NC}\n"

# Check if Docker is running
if ! sudo docker ps | grep -q spark-master; then
    echo -e "${RED}✗ Spark container is not running. Start the pipeline first.${NC}"
    exit 1
fi

# Check if MongoDB is running
if ! sudo docker ps | grep -q mongodb; then
    echo -e "${RED}✗ MongoDB container is not running. Start the pipeline first.${NC}"
    exit 1
fi

# Run the sync job
echo -e "${YELLOW}Running Spark job to sync data...${NC}"
sudo docker exec -u root spark-master /opt/spark/bin/spark-submit \
    --master spark://spark-master:7077 \
    --total-executor-cores 8 \
    /opt/spark-apps/hdfs_to_mongodb.py

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Sync completed successfully${NC}"

    # Show MongoDB stats
    echo -e "\n${YELLOW}MongoDB Statistics:${NC}"
    sudo docker exec mongodb mongosh --quiet --eval "
        db.getSiblingDB('air_quality').measurements.aggregate([
            { \$group: {
                _id: '\$city_name',
                count: { \$sum: 1 },
                avg_aqi: { \$avg: '\$aqi' },
                max_aqi: { \$max: '\$aqi' }
            }},
            { \$sort: { count: -1 }}
        ]).forEach(doc => print('  ' + doc._id + ': ' + doc.count + ' records (avg AQI: ' + Math.round(doc.avg_aqi) + ', max: ' + Math.round(doc.max_aqi) + ')'))
    "
else
    echo -e "\n${RED}✗ Sync failed. Check logs for details.${NC}"
    exit 1
fi