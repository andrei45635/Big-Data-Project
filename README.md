# Air Quality Prediction System - Big Data Project

A real-time air quality monitoring and prediction system built using Lambda Architecture with Kafka, Hadoop, Spark, PostgreSQL, and Grafana.

## 🎯 Project Overview

This project implements an end-to-end big data pipeline that:
- Fetches real-time air quality data from multiple cities worldwide
- Processes data using both batch and stream processing (Lambda Architecture)
- Stores historical data in HDFS for analytics and future ML model training
- Provides queryable data in PostgreSQL for visualization
- Visualizes real-time air quality metrics in Grafana dashboards

## 🏗️ Architecture
```
API Sources (WAQI) 
    ↓
Python Data Fetcher
    ↓
Apache Kafka (Message Queue)
    ↓
Spark Streaming → HDFS (Batch Layer - Historical Data Archive)
    ↓
Spark Batch Job (every 10 min) → PostgreSQL (Queryable Data)
    ↓
Grafana (Visualization & Dashboards)
```

## 🛠️ Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Data Ingestion | Apache Kafka (KRaft) | Real-time message streaming |
| Batch Processing | Apache Spark + Hadoop HDFS | Historical data storage & processing |
| Stream Processing | Spark Streaming | Real-time data processing |
| Database | PostgreSQL 15 | Queryable data for visualization |
| Big Data Storage | Hadoop HDFS | Historical data archive (Parquet) |
| Visualization | Grafana | Interactive dashboards |
| Orchestration | Docker Compose | Container management |
| API Source | WAQI API | Air quality data |

## 📋 Prerequisites

- **WSL2** (Ubuntu) on Windows
- **Docker Desktop** with WSL2 backend enabled
- **Python 3.8+**
- **Apache Kafka** (running on WSL2 in KRaft mode)
- **Java 11+** (for Kafka)
- **8GB+ RAM** recommended

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

# Download and extract Kafka
cd ~
wget https://downloads.apache.org/kafka/3.6.1/kafka_2.13-3.6.1.tgz
tar -xzf kafka_2.13-3.6.1.tgz
cd kafka_2.13-3.6.1

# Set Java Home
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> ~/.bashrc
source ~/.bashrc
```

### 4. Configure Kafka for Docker Integration

Edit `~/kafka_*/config/server.properties`:
```properties
# KRaft mode configuration
process.roles=broker,controller
node.id=1
controller.quorum.voters=1@localhost:9093

# Network configuration for Docker
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
advertised.listeners=PLAINTEXT://172.17.0.1:9092,CONTROLLER://localhost:9093
controller.listener.names=CONTROLLER
log.dirs=/tmp/kraft-combined-logs
```

Initialize Kafka storage:
```bash
cd ~/kafka_*
KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"
bin/kafka-storage.sh format -t $KAFKA_CLUSTER_ID -c config/server.properties --standalone
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
├── spark-apps/
│   ├── kafka_to_hdfs.py
│   ├── hdfs_to_mongodb.py
│   └── hdfs_to_postgres.py
├── data/
├── start_pipeline.sh
├── stop_pipeline.sh
├── status_pipeline.sh
├── sync_to_postgres.sh
└── README.md
```

### 6. Configure API Token

Edit `fetch_programmatic_api.py` and add your WAQI API token:
```python
WAQI_TOKEN = "your_token_here"  # Get from https://aqicn.org/data-platform/token/
```

## 🎬 Quick Start

### Option 1: Using Shell Scripts (Recommended)
```bash
# Make scripts executable
chmod +x start_pipeline.sh stop_pipeline.sh status_pipeline.sh sync_to_postgres.sh

# Start the entire pipeline
./start_pipeline.sh

# Check pipeline status
./status_pipeline.sh

# Sync HDFS data to PostgreSQL (for Grafana)
./sync_to_postgres.sh

# Stop the pipeline
./stop_pipeline.sh
```

### Option 2: Manual Start

**Terminal 1: Start Docker Services**
```bash
sudo docker-compose up -d
```

**Terminal 2: Start Kafka**
```bash
cd ~/kafka_*
bin/kafka-server-start.sh config/server.properties
```

**Terminal 3: Start Spark Streaming Job**
```bash
sudo docker exec -u root -it spark-master /opt/spark/bin/spark-submit \
    --master spark://spark-master:7077 \
    --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.3 \
    /opt/spark-apps/kafka_to_hdfs.py
```

**Terminal 4: Start API Fetcher**
```bash
python3 fetch_programmatic_api.py
```

**Terminal 5: Sync to PostgreSQL (when ready)**
```bash
./sync_to_postgres.sh
```

## 📊 Monitoring & Verification

### Web Interfaces

- **Spark Master UI**: http://localhost:8081
- **Hadoop NameNode UI**: http://localhost:9870
- **HDFS Explorer**: http://localhost:9870/explorer.html#/air-quality/historical
- **Grafana Dashboard**: http://localhost:3000 (admin/admin)

### Command Line Checks

**Check HDFS Data:**
```bash
# List directories
sudo docker exec -it namenode hdfs dfs -ls /air-quality/historical/

# Check data size
sudo docker exec -it namenode hdfs dfs -du -h /air-quality/historical/

# List files recursively
sudo docker exec -it namenode hdfs dfs -ls -R /air-quality/historical/
```

**Check Kafka Messages:**
```bash
cd ~/kafka_*

# List topics
bin/kafka-topics.sh --list --bootstrap-server localhost:9092

# Consume messages
bin/kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic air-quality-historical \
    --from-beginning \
    --max-messages 5
```

**Check PostgreSQL Data:**
```bash
# Connect to PostgreSQL
sudo docker exec -it postgres psql -U postgres -d air_quality

# Check record count
SELECT COUNT(*) FROM air_quality_data;

# View records by city
SELECT city_name, COUNT(*), AVG(aqi) FROM air_quality_data GROUP BY city_name;

# View recent data
SELECT timestamp, city_name, station_name, aqi, pm25 FROM air_quality_data ORDER BY timestamp DESC LIMIT 10;

# Exit
\q
```

**Read HDFS Data with Spark:**
```bash
# Enter Spark container
sudo docker exec -it spark-master /opt/spark/bin/pyspark

# Inside PySpark:
>>> df = spark.read.parquet("hdfs://namenode:9000/air-quality/historical/")
>>> df.show()
>>> df.count()
>>> df.printSchema()
>>> df.filter("city_name = 'Bucharest'").show()
>>> df.groupBy("city_name").count().show()
```

## 📁 Data Schema

### Air Quality Data Structure (HDFS - Parquet)
```json
{
  "fetch_timestamp": "2024-12-18T10:30:00",
  "city_name": "Bucharest",
  "idx": 8268,
  "aqi": 85,
  "dominentpol": "pm25",
  "city": {
    "name": "Bucharest Berceni",
    "geo": [44.3947, 26.1128],
    "url": "https://aqicn.org/city/bucharest/berceni"
  },
  "time": {
    "s": "2024-12-18 10:00:00",
    "tz": "+02:00",
    "v": 1702728000,
    "iso": "2024-12-18T10:00:00+02:00"
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
  "forecast": {
    "daily": {
      "pm25": [...],
      "pm10": [...],
      "o3": [...]
    }
  }
}
```

### PostgreSQL Table Schema
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

### 1. Configure PostgreSQL Data Source

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

### 2. Example Dashboard Queries

**Average AQI by City Over Time:**
```sql
SELECT
  timestamp AS "time",
  city_name,
  AVG(aqi) as aqi
FROM air_quality_data
WHERE $__timeFilter(timestamp)
GROUP BY timestamp, city_name
ORDER BY timestamp
```

**Latest AQI by City:**
```sql
SELECT DISTINCT ON (city_name)
  city_name as "City",
  aqi as "AQI",
  station_name as "Station",
  pm25 as "PM2.5"
FROM air_quality_data
ORDER BY city_name, timestamp DESC
```

**PM2.5 Trends:**
```sql
SELECT
  timestamp AS "time",
  city_name,
  AVG(pm25) as pm25
FROM air_quality_data
WHERE $__timeFilter(timestamp) AND pm25 IS NOT NULL
GROUP BY timestamp, city_name
ORDER BY timestamp
```

**All Stations with Latest Data:**
```sql
SELECT DISTINCT ON (station_name)
  station_name as "Station",
  city_name as "City",
  aqi as "AQI",
  pm25 as "PM2.5",
  pm10 as "PM10",
  temperature as "Temp (°C)",
  humidity as "Humidity (%)",
  timestamp
FROM air_quality_data
ORDER BY station_name, timestamp DESC
```

### 3. Recommended Panel Types

- **Time Series**: AQI trends, pollutant levels over time
- **Stat**: Current AQI values, latest measurements
- **Gauge**: AQI with color thresholds (0-50 green, 50-100 yellow, 100+ red)
- **Table**: All stations with detailed metrics
- **Bar Chart**: City comparisons
- **Pie Chart**: Pollutant distribution

## 🔧 Configuration

### Kafka Topics

- `air-quality-historical` - For batch processing (HDFS)
- `air-quality-realtime` - For real-time stream processing

**Topic Configuration:**
- Partitions: 3
- Replication Factor: 1
- Retention: 7 days (default)

### Data Collection Frequency

- **API polling**: Every 5 minutes
- **Spark streaming**: Continuous (micro-batches every 5 minutes)
- **HDFS → PostgreSQL sync**: Manual or scheduled (every 10 minutes)

### Storage Details

- **HDFS**: Parquet format, Snappy compression, partitioned by `city_name`
- **PostgreSQL**: Relational table with indexes on `timestamp`, `city_name`, and `aqi`
- **Data Retention**: 
  - HDFS: Unlimited (configure manually if needed)
  - PostgreSQL: Configurable (recommend keeping recent data only)

## 🐛 Troubleshooting

### Kafka Connection Issues

**Problem**: Spark can't connect to Kafka
```
WARN NetworkClient: Connection to node 1 could not be established
ERROR ClientUtils: Couldn't resolve server host.docker.internal
```

**Solution**: Verify Kafka advertised listeners
```bash
# Check config
grep advertised.listeners ~/kafka_*/config/server.properties

# Should be:
advertised.listeners=PLAINTEXT://172.17.0.1:9092,CONTROLLER://localhost:9093
```

### Spark Streaming Job Crashes

**Problem**: Checkpoint offset mismatch
```
ERROR: Partition air-quality-historical-0's offset was changed from 134 to 59
```

**Solution**: Clear checkpoint and restart
```bash
# Delete checkpoint
sudo docker exec -it namenode hdfs dfs -rm -r /checkpoints/historical

# Restart Spark job
sudo docker exec -u root -it spark-master /opt/spark/bin/spark-submit \
    --master spark://spark-master:7077 \
    --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.3 \
    /opt/spark-apps/kafka_to_hdfs.py
```

### HDFS Permission Errors

**Problem**: Cannot write to HDFS
```
Permission denied: user=spark, access=WRITE
```

**Solution**: Run spark-submit as root
```bash
sudo docker exec -u root -it spark-master /opt/spark/bin/spark-submit ...
```

### Docker Container Not Starting

**Problem**: Container fails to start or exits immediately

**Solution**: Check logs and restart
```bash
# Check logs
sudo docker logs <container-name>

# Clean up and restart
sudo docker-compose down
sudo docker-compose up -d
```

### PostgreSQL Version Incompatibility

**Problem**: PostgreSQL data format error after upgrade

**Solution**: Remove old volume and use PostgreSQL 15
```bash
sudo docker-compose down
sudo docker volume rm <project>_postgres-data
# Update docker-compose.yml to use postgres:15
sudo docker-compose up -d
```

### Python Package Issues

**Problem**: `ModuleNotFoundError: No module named 'kafka'`

**Solution**: Use confluent-kafka
```bash
pip uninstall kafka-python kafka-python-ng
pip install confluent-kafka
```

### Spark Job Gets 0 Cores

**Problem**: Spark job stuck waiting for resources

**Solution**: Kill other running Spark jobs first
```bash
# Kill streaming job
sudo docker exec spark-master pkill -f kafka_to_hdfs.py

# Then run your job
sudo docker exec -u root -it spark-master /opt/spark/bin/spark-submit ...
```

## 📊 Performance Metrics

### Expected Throughput

- API fetch rate: ~150-200 stations per cycle (every 5 minutes)
- Kafka throughput: 1000+ messages/second (not fully utilized)
- HDFS write rate: 10-50 MB per 5-minute cycle
- PostgreSQL sync: ~750 records in ~30 seconds
- Data retention: 
  - HDFS: Unlimited
  - PostgreSQL: Configurable

### Resource Usage

- Docker containers: ~4-6 GB RAM total
- Kafka (WSL2): ~500 MB RAM
- Python fetcher: ~100 MB RAM
- Total disk usage: ~500 MB - 1 GB per day (depends on data volume)

### Data Volume (Example After 24 Hours)

- HDFS: ~350-400 KB (compressed Parquet)
- PostgreSQL: ~750 records
- Kafka: Transient (messages deleted after consumption)

## 📚 Additional Resources

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Apache Spark Structured Streaming](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html)
- [Hadoop HDFS Guide](https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-hdfs/HdfsUserGuide.html)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/15/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [WAQI API Documentation](https://aqicn.org/json-api/doc/)