#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== Cassandra Speed Layer Status ===${NC}\n"

# Check if Cassandra is running
if ! sudo docker ps | grep -q cassandra; then
    echo -e "${RED}✗ Cassandra container is not running${NC}"
    exit 1
fi

# Quick check - just count records (fast)
echo -e "${BLUE}Quick Summary:${NC}"

for city in Bucharest Beijing London; do
    LATEST=$(sudo docker exec cassandra cqlsh --request-timeout=5 -e \
        "SELECT COUNT(*) FROM air_quality.latest_readings WHERE city_name = '$city';" \
        2>/dev/null | grep -oE '[0-9]+' | tail -1)

    HOURLY=$(sudo docker exec cassandra cqlsh --request-timeout=5 -e \
        "SELECT COUNT(*) FROM air_quality.hourly_metrics WHERE city_name = '$city';" \
        2>/dev/null | grep -oE '[0-9]+' | tail -1)

    if [ -n "$LATEST" ]; then
        echo -e "  ${GREEN}$city${NC}: $LATEST latest, $HOURLY windows"
    fi
done

# Only show details if user wants them
if [ "$1" == "--detailed" ]; then
    echo -e "\n${BLUE}Latest Readings (Bucharest - Last 5):${NC}"
    sudo docker exec cassandra cqlsh --request-timeout=10 -e "
    SELECT city_name, station_name, timestamp, aqi, pm25
    FROM air_quality.latest_readings
    WHERE city_name = 'Bucharest'
    LIMIT 5;" 2>/dev/null

    echo -e "\n${BLUE}Hourly Windows (Bucharest - Last 5):${NC}"
    sudo docker exec cassandra cqlsh --request-timeout=10 -e "
    SELECT city_name, window_start, avg_aqi, max_aqi, record_count
    FROM air_quality.hourly_metrics
    WHERE city_name = 'Bucharest'
    LIMIT 5;" 2>/dev/null
fi

echo -e "\n${YELLOW}Tips:${NC}"
echo -e "  - Use ${GREEN}./check_cassandra.sh --detailed${NC} for full data view"
echo -e "  - Quick check runs fast, detailed view takes longer"
echo -e "  - Query manually: ${GREEN}sudo docker exec -it cassandra cqlsh${NC}"