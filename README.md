# Air Quality Monitoring System - Big Data Project

A real-time air quality monitoring system built using **Lambda Architecture** with Kafka, Hadoop, Spark, Cassandra, PostgreSQL, and Grafana.

## 🎯 Project Overview

This project implements an end-to-end big data pipeline that:
- Fetches real-time air quality data from multiple cities worldwide
- Implements true **Lambda Architecture** with batch and speed layers
- Stores historical data in HDFS for long-term analytics
- Processes real-time data with time-windowed aggregations in Cassandra
- Provides queryable data in PostgreSQL for visualization
- Visualizes air quality metrics in Grafana dashboards

## 🏗️ Lambda Architecture
```
                    ┌─→ Spark Streaming → HDFS (Batch Layer)
                    │                      ↓
API → Kafka → Kafka ─┤                  Spark Batch → PostgreSQL (Serving Layer)
                    │                                      ↓
                    └─→ Spark Streaming → Cassandra (Speed Layer - Time Windows)
                                           ↓
                                        Grafana (Visualization)
```

### Architecture Layers:

1. **Batch Layer**: Historical data in HDFS → PostgreSQL for analytics
2. **Speed Layer**: Real-time aggregations in Cassandra (1-hour windows)
3. **Serving Layer**: PostgreSQL + Cassandra → Grafana dashboards

## 🛠️ Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Data Ingestion | Apache Kafka 4.1.1 (KRaft) | Real-time message streaming |
| Batch Processing | Apache Spark 3.5.3 + Hadoop HDFS | Historical data storage & processing |
| Stream Processing | Spark Structured Streaming | Real-time data processing |
| Speed Layer DB | Apache Cassandra 4.1 | Time-series aggregations |
| Serving Layer DB | PostgreSQL 15 | Queryable data for visualization |
| Big Data Storage | Hadoop HDFS | Historical data archive (Parquet) |
| Visualization | Grafana | Interactive dashboards |
| Orchestration | Docker Compose | Container management |
| API Source | WAQI API | Air quality data |

## 📋 Prerequisites

- **WSL2** (Ubuntu) on Windows
- **Docker Desktop** with WSL2 backend enabled
- **Python 3.8+**
- **Apache Kafka 4.1.1** (running on WSL2 in KRaft mode)
- **Java 11+** (for Kafka)
- **8GB+ RAM** recommended (10GB+ for Cassandra)

## 🚀 Installation

### 1. Clone the Repository
```bash
git clone <repository-url>
cd Big-Data-Project
```

### 2. Install Python Dependencies
```bash
pip install confluent-kafka requests
```

### 3. Install Kafka on WSL2
```bash
# Install Java
sudo apt update
sudo apt install openjdk-11-jdk -y

# Download and extract Kafka 4.1.1
cd ~
wget https://downloads.apache.org/kafka/4.1.1/kafka_2.13-4.1.1.tgz
tar -xzf kafka_2.13-4.1.1.tgz
cd kafka_2.13-4.1.1

# Set Java Home
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> ~/.bashrc
source ~/.bashrc
```

### 4. Configure Kafka for Docker Integration

Edit `~/kafka_2.13-4.1.1/config/server.properties`:
```properties
# KRaft mode configuration
process.roles=broker,controller
node.id=1
controller.quorum.voters=1@localhost:9093

# Network configuration for Docker
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
advertised.listeners=PLAINTEXT://172.17.0.1:9092
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT

# Storage
log.dirs=/tmp/kraft-combined-logs
```

Initialize Kafka storage:
```bash
cd ~/kafka_2.13-4.1.1
KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"
bin/kafka-storage.sh format -t $KAFKA_CLUSTER_ID -c config/server.properties
```

### 5. Set Up Project Structure
```bash
mkdir -p spark-apps data
```

Your project structure should look like:
```
Big-Data-Project/
├── docker-compose.yml
├── fetch_programmatic_api.py
├── api_keys.py                    # Create this with your API tokens
├── spark-apps/
│   ├── kafka_to_hdfs.py
│   ├── kafka_to_cassandra.py
│   ├── hdfs_to_postgres.py
│   └── hdfs_to_mongodb.py         # Optional
├── start_pipeline.sh
├── stop_pipeline.sh
├── status_pipeline.sh
├── sync_to_postgres.sh
├── setup_cassandra.sh
├── check_cassandra.sh
└── README.md
```

### 6. Configure API Tokens

Create `api_keys.py`:
```python
WAQI_TOKEN = "your_token_here"  # Get from https://aqicn.org/data-platform/token/
OPENWEATHER_KEY = "your_key_here"  # Optional
```

## 🎬 Quick Start

### One-Time Setup
```bash
# Make scripts executable
chmod +x *.sh

# Start Docker services
sudo docker-compose up -d

# Wait for Cassandra to start (takes 1-2 minutes)
sleep 120

# Setup Cassandra schema
./setup_cassandra.sh
```

### Regular Usage
```bash
# Start the entire pipeline
./start_pipeline.sh

# Check pipeline status
./status_pipeline.sh

# Check Cassandra speed layer
./check_cassandra.sh

# Sync HDFS to PostgreSQL (for Grafana)
./sync_to_postgres.sh

# Stop the pipeline
./stop_pipeline.sh
```

## 📊 Monitoring & Verification

### Web Interfaces

- **Spark Master UI**: http://localhost:8081
- **Hadoop NameNode UI**: http://localhost:9870
- **HDFS Explorer**: http://localhost:9870/explorer.html#/air-quality/historical
- **Grafana Dashboard**: http://localhost:3000 (admin/admin)

### Command Line Checks

**Check HDFS Data (Batch Layer):**
```bash
# List directories
sudo docker exec -it namenode hdfs dfs -ls /air-quality/historical/

# Check data size
sudo docker exec -it namenode hdfs dfs -du -h /air-quality/historical/

# List files by city
sudo docker exec -it namenode hdfs dfs -ls /air-quality/historical/city_name=Bucharest/
```

**Check Kafka Topics:**
```bash
cd ~/kafka_2.13-4.1.1

# List topics
bin/kafka-topics.sh --list --bootstrap-server localhost:9092

# Check message count
bin/kafka-get-offsets.sh --bootstrap-server localhost:9092 --topic air-quality-historical
bin/kafka-get-offsets.sh --bootstrap-server localhost:9092 --topic air-quality-realtime

# Consume sample messages
bin/kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic air-quality-historical \
    --from-beginning \
    --max-messages 1
```

**Check Cassandra Data (Speed Layer):**
```bash
# Quick status
./check_cassandra.sh

# Detailed view
./check_cassandra.sh --detailed

# Manual queries
sudo docker exec -it cassandra cqlsh

USE air_quality;

-- Latest readings
SELECT * FROM latest_readings WHERE city_name = 'Bucharest' LIMIT 5;

-- Hourly aggregations
SELECT * FROM hourly_metrics WHERE city_name = 'Bucharest' LIMIT 5;

-- Exit
exit
```

**Check PostgreSQL Data (Serving Layer):**
```bash
# Connect to PostgreSQL
sudo docker exec -it postgres psql -U postgres -d air_quality

# Check record count
SELECT COUNT(*) FROM air_quality_data;

# View records by city
SELECT city_name, COUNT(*), ROUND(AVG(aqi)) as avg_aqi 
FROM air_quality_data 
GROUP BY city_name;

# View recent data
SELECT timestamp, city_name, station_name, aqi, pm25 
FROM air_quality_data 
ORDER BY timestamp DESC 
LIMIT 10;

# Exit
\q
```

**Read HDFS Data with Spark:**
```bash
# Enter PySpark shell
sudo docker exec -it spark-master /opt/spark/bin/pyspark

# Read and analyze
>>> df = spark.read.parquet("hdfs://namenode:9000/air-quality/historical/")
>>> df.show()
>>> df.count()
>>> df.groupBy("city_name").count().show()
>>> df.filter("city_name = 'Bucharest'").select("aqi", "pm25", "timestamp").show(10)
```

## 📁 Data Schema

### Kafka Message Format
```json
{
  "fetch_timestamp": "2026-01-12T10:30:00",
  "city_name": "Bucharest",
  "idx": 8268,
  "aqi": 85,
  "dominentpol": "pm25",
  "city": {
    "name": "Bucharest Berceni",
    "geo": [44.3947, 26.1128],
    "url": "https://aqicn.org/city/bucharest/berceni",
    "location": "Sector 4, Bucharest, Romania"
  },
  "time": {
    "s": "2026-01-12 10:00:00",
    "tz": "+02:00",
    "v": 1736673600,
    "iso": "2026-01-12T08:00:00Z"
  },
  "iaqi": {
    "pm25": {"v": 65},
    "pm10": {"v": 90},
    "o3": {"v": 45},
    "no2": {"v": 35},
    "so2": {"v": 8},
    "co": {"v": 0.5},
    "t": {"v": 15.2},
    "h": {"v": 72},
    "p": {"v": 1013},
    "w": {"v": 12}
  },
  "attributions": [...],
  "forecast": {
    "daily": {
      "pm25": [...],
      "pm10": [...],
      "o3": [...]
    }
  }
}
```

### Cassandra Schema (Speed Layer)
```sql
-- Keyspace
CREATE KEYSPACE air_quality
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

-- Latest readings (real-time data)
CREATE TABLE latest_readings (
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

-- Hourly aggregations (1-hour time windows)
CREATE TABLE hourly_metrics (
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
```

### PostgreSQL Schema (Serving Layer)
```sql
CREATE TABLE air_quality_data (
    fetch_timestamp VARCHAR,
    timestamp TIMESTAMP,
    city_name VARCHAR,
    idx INTEGER,
    aqi INTEGER,
    dominant_pollutant VARCHAR,
    station_name VARCHAR,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    station_url VARCHAR,
    measurement_time VARCHAR,
    measurement_time_iso VARCHAR,
    pm25 DOUBLE PRECISION,
    pm10 DOUBLE PRECISION,
    ozone DOUBLE PRECISION,
    no2 DOUBLE PRECISION,
    so2 DOUBLE PRECISION,
    co DOUBLE PRECISION,
    temperature DOUBLE PRECISION,
    humidity DOUBLE PRECISION,
    pressure DOUBLE PRECISION,
    wind_speed DOUBLE PRECISION
);
```

### Monitored Cities

- **Bucharest, Romania** (44.4268, 26.1025)
- **Beijing, China** (39.9042, 116.4074)
- **London, United Kingdom** (51.5074, -0.1278)

Cities can be added/modified in `fetch_programmatic_api.py`

## 📈 Grafana Dashboard Setup

### 1. Configure PostgreSQL Data Source (Batch Layer)

1. Open http://localhost:3000 (login: admin/admin)
2. Go to **Configuration** → **Data Sources** → **Add data source**
3. Select **PostgreSQL**
4. Configure:
   - **Host**: `postgres:5432`
   - **Database**: `air_quality`
   - **User**: `postgres`
   - **Password**: `postgres`
   - **TLS/SSL Mode**: `disable`
5. Click **Save & Test**

### 2. Configure Cassandra Data Source (Speed Layer)
```bash
# Install Cassandra plugin
sudo docker exec -u root grafana grafana-cli plugins install hadesarchitect-cassandra-datasource
sudo docker restart grafana
```

Then in Grafana:
1. Add **Cassandra** data source
2. Configure:
   - **Host**: `cassandra:9042`
   - **Keyspace**: `air_quality`
3. Click **Save & Test**

### 3. Example Dashboard Queries

**PostgreSQL - Historical Trends:**
```sql
-- Average AQI by City Over Time
SELECT
  timestamp AS "time",
  city_name,
  AVG(aqi) as aqi
FROM air_quality_data
WHERE $__timeFilter(timestamp)
GROUP BY timestamp, city_name
ORDER BY timestamp;

-- Latest Readings by City
SELECT DISTINCT ON (city_name)
  city_name as "City",
  aqi as "AQI",
  pm25 as "PM2.5",
  station_name as "Station"
FROM air_quality_data
ORDER BY city_name, timestamp DESC;
```

**Cassandra - Real-time Windows:**
```sql
-- Hourly AQI Trends
SELECT window_start, city_name, avg_aqi, max_aqi
FROM hourly_metrics 
WHERE city_name IN ('Bucharest', 'Beijing', 'London');

-- Latest Real-time Readings
SELECT timestamp, city_name, station_name, aqi, pm25
FROM latest_readings 
WHERE city_name = 'Bucharest' 
LIMIT 20;
```

### 4. Recommended Panel Types

- **Time Series**: AQI trends (use PostgreSQL for long history, Cassandra for recent)
- **Stat**: Current AQI values from Cassandra latest_readings
- **Gauge**: AQI with color thresholds (0-50 green, 50-100 yellow, 100+ red)
- **Table**: All stations with latest metrics
- **Bar Chart**: City comparisons from hourly_metrics
- **Heatmap**: PM2.5 levels by hour

## 🔧 Configuration

### Kafka Topics

- `air-quality-historical` - Batch layer (HDFS)
- `air-quality-realtime` - Speed layer (Cassandra)

**Topic Configuration:**
- Partitions: 1 (can be increased for higher throughput)
- Replication Factor: 1
- Retention: 7 days (default)

### Data Flow Frequencies

- **API polling**: Every 5 minutes (~150-200 stations per cycle)
- **Kafka throughput**: Real-time (sub-second)
- **Spark Streaming**: Continuous micro-batches (5-minute trigger)
- **Cassandra writes**: Real-time (as data arrives)
- **Cassandra time windows**: 1-hour aggregations
- **HDFS → PostgreSQL sync**: Manual or every 10 minutes

### Storage Configuration

- **HDFS**: Parquet format, Snappy compression, partitioned by `city_name`
- **Cassandra**: Time-series optimized, partition key on `city_name`
- **PostgreSQL**: B-tree indexes on `timestamp`, `city_name`, `aqi`
- **Data Retention**:
  - HDFS: Unlimited (configure if needed)
  - Cassandra: Configurable TTL (default: no expiration)
  - PostgreSQL: Configurable (recommend 30-90 days)

## 🐛 Troubleshooting

### Kafka Connection Issues

**Problem**: Spark can't connect to Kafka
```bash
# Check Kafka configuration
grep advertised.listeners ~/kafka_2.13-4.1.1/config/server.properties

# Should show:
# advertised.listeners=PLAINTEXT://172.17.0.1:9092

# Restart Kafka if needed
pkill -f kafka.Kafka
cd ~/kafka_2.13-4.1.1
bin/kafka-server-start.sh config/server.properties
```

### Cassandra Not Starting

**Problem**: Cassandra container keeps restarting
```bash
# Check logs
sudo docker logs cassandra

# If out of memory, limit resources in docker-compose.yml:
cassandra:
  environment:
    - MAX_HEAP_SIZE=512M
    - HEAP_NEWSIZE=128M
  mem_limit: 2g
```

### Cassandra Tables Don't Exist

**Problem**: Queries fail with "keyspace doesn't exist"
```bash
# Manually create schema
./setup_cassandra.sh

# Or connect and create manually
sudo docker exec -it cassandra cqlsh
# Then paste the CREATE TABLE commands
```

### Spark Streaming Job Crashes

**Problem**: Offset mismatch error
```bash
# Clear checkpoint and restart
sudo docker exec namenode hdfs dfs -rm -r /checkpoints/historical
sudo docker exec namenode hdfs dfs -rm -r /checkpoints/cassandra-latest
sudo docker exec namenode hdfs dfs -rm -r /checkpoints/cassandra-windows

# Restart Spark jobs
./stop_pipeline.sh
./start_pipeline.sh
```

### No Data in Cassandra

**Problem**: Tables exist but no data
```bash
# Check if realtime topic has messages
cd ~/kafka_2.13-4.1.1
bin/kafka-get-offsets.sh --bootstrap-server localhost:9092 --topic air-quality-realtime

# If 0 messages, API fetcher isn't sending to realtime topic
# Edit fetch_programmatic_api.py and UNCOMMENT:
# producer.send('air-quality-realtime', combined_data)

# Restart API fetcher
pkill -f fetch_programmatic_api.py
python3 fetch_programmatic_api.py &
```

### Spark Job Waiting for Cores

**Problem**: Job stuck with 0 cores allocated
```bash
# Check how many jobs are running
curl http://localhost:8081

# Kill other jobs to free cores
sudo docker exec spark-master pkill -f kafka_to_hdfs.py

# Or reduce core allocation in start_pipeline.sh:
--total-executor-cores 4  # Instead of 8
```

## 📊 Performance Metrics

### Expected Throughput

- **API fetch rate**: ~150-200 stations per cycle (every 5 minutes)
- **Kafka throughput**: 600+ messages per 5-minute cycle
- **HDFS write rate**: 10-50 MB per cycle
- **Cassandra writes**: Real-time (< 100ms latency)
- **PostgreSQL sync**: ~750 records in ~30 seconds
- **Time window processing**: 1-hour windows calculated in real-time

### Resource Usage

- **Docker containers**: ~6-8 GB RAM (with Cassandra)
- **Kafka (WSL2)**: ~500 MB RAM
- **Python fetcher**: ~100 MB RAM
- **Cassandra**: ~2 GB RAM
- **Total disk**: ~1-2 GB per day

### Data Volume (After 24 Hours)

- **HDFS**: ~400-500 KB (compressed Parquet)
- **Cassandra latest_readings**: ~600 records
- **Cassandra hourly_metrics**: ~24 windows per city
- **PostgreSQL**: ~750 records (after sync)
- **Kafka**: Transient (messages deleted after consumption)

## 📚 Additional Resources

- [Apache Kafka 4.1.1 Documentation](https://kafka.apache.org/documentation/)
- [Apache Spark Structured Streaming](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html)
- [Apache Cassandra 4.1 Documentation](https://cassandra.apache.org/doc/latest/)
- [Hadoop HDFS Guide](https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-hdfs/HdfsUserGuide.html)
- [PostgreSQL 15 Documentation](https://www.postgresql.org/docs/15/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Lambda Architecture](http://lambda-architecture.net/)
- [WAQI API Documentation](https://aqicn.org/json-api/doc/)

## 📝 License

This project is for academic purposes as part of a Big Data course at Babeș-Bolyai University.

## 🙏 Acknowledgments

- World Air Quality Index (WAQI) for providing the API
- Apache Software Foundation for Kafka, Spark, Hadoop, and Cassandra
- Docker community for containerization tools
- Grafana Labs for visualization platform

---