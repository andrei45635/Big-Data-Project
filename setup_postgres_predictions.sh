#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=== Setting Up PostgreSQL Predictions Table ===${NC}\n"

# Check if PostgreSQL is running
if ! sudo docker ps | grep -q postgres; then
    echo -e "${RED}✗ PostgreSQL container is not running${NC}"
    exit 1
fi

# Create predictions table
sudo docker exec postgres psql -U postgres -d air_quality << 'EOF'
-- Create predictions table
CREATE TABLE IF NOT EXISTS aqi_predictions (
    id SERIAL PRIMARY KEY,
    aqi INTEGER NOT NULL,
    city VARCHAR(100) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_predictions_city ON aqi_predictions(city);
CREATE INDEX IF NOT EXISTS idx_predictions_timestamp ON aqi_predictions(timestamp);
CREATE INDEX IF NOT EXISTS idx_predictions_city_timestamp ON aqi_predictions(city, timestamp);

-- Show table structure
\d aqi_predictions
EOF

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ PostgreSQL predictions table created successfully${NC}"
else
    echo -e "\n${RED}✗ Failed to create predictions table${NC}"
    exit 1
fi