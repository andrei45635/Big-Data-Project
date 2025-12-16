# Air Quality Prediction System - Big Data Project

A real-time air quality monitoring and prediction system built using Lambda Architecture with Kafka, Hadoop, Spark, and MongoDB.

## 🎯 Project Overview

This project implements an end-to-end big data pipeline that:
- Fetches real-time air quality data from multiple cities
- Processes data using both batch and stream processing
- Stores historical data in HDFS for machine learning model training
- Maintains real-time data in MongoDB for live dashboards
- Enables air quality prediction using machine learning models

## 🏗️ Architecture
```
API Sources (WAQI) 
    ↓
Python Data Fetcher
    ↓
Apache Kafka (Message Queue)
    ↓
    ├─→ Spark Streaming → HDFS (Batch Layer - Historical Data)
    └─→ Spark Streaming → MongoDB (Speed Layer - Real-time Data)
    ↓
ML Model Training & Predictions
    ↓
Dashboard (Visualization)
```

## 🛠️ Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Data Ingestion | Apache Kafka | Real-time message streaming |
| Batch Processing | Apache Spark + Hadoop HDFS | Historical data storage & processing |
| Stream Processing | Spark Streaming | Real-time data processing |
| NoSQL Storage | MongoDB | Current data & predictions |
| Big Data Storage | Hadoop HDFS | Historical data archive |
| ML Framework | Python (scikit-learn/XGBoost) | Prediction models |
| Orchestration | Docker Compose | Container management |
| API Source | WAQI API | Air quality data |

## 📋 Prerequisites

- **WSL2** (Ubuntu) on Windows
- **Docker Desktop** with WSL2 backend enabled
- **Python 3.8+**
- **Apache Kafka** (running on WSL2)
- **Java 11** (for Kafka)
- **8GB+ RAM** recommended

## 🚀 Installation

### 1. Clone the Repository
```bash
git clone <repository-url>
cd Big-Data-Project
```

### 2. Install Python Dependencies
```bash
pip install kafka-python-ng
```

### 3. Install Kafka on WSL2
```bash
# Install Java
sudo apt update
sudo apt install openjdk-25-jdk -y

# Download and extract Kafka
cd ~
wget https://downloads.apache.org/kafka/3.6.1/kafka_2.13-4.1.1.tgz
tar -xzf kafka_2.13-4.1.1.tgz
cd kafka_2.13-4.1.1

# Set Java Home
export JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64
export JRE_HOME=/usr/lib/jvm/java-25-openjdk-amd64/jre
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> ~/.bashrc
echo 'export JRE_HOME=/usr/lib/jvm/java-11-openjdk-amd64/jre' >> ~/.bashrc
```

### 4. Configure Kafka

Edit `~/kafka_*/config/server.properties`:
```properties
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
advertised.listeners=PLAINTEXT://172.17.0.1:9092,CONTROLLER://localhost:9093
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
│   └── kafka_to_mongodb.py
├── data/
├── start_pipeline.sh
├── stop_pipeline.sh
├── status_pipeline.sh
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
chmod +x start_pipeline.sh stop_pipeline.sh status_pipeline.sh

# Start the entire pipeline
./start_pipeline.sh

# Check pipeline status
./status_pipeline.sh

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

## 📊 Monitoring & Verification

### Web Interfaces

- **Spark Master UI**: http://localhost:8081
- **Hadoop NameNode UI**: http://localhost:9870
- **HDFS Explorer**: http://localhost:9870/explorer.html#/air-quality/historical

### Command Line Checks

**Check HDFS Data:**
```bash
# List directories
sudo docker exec -it namenode hdfs dfs -ls /air-quality/historical/

# Check data size
sudo docker exec -it namenode hdfs dfs -du -h /air-quality/historical/

# Browse HDFS in web UI
http://localhost:9870/explorer.html#/air-quality/historical
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

**Check MongoDB Data:**
```bash
sudo docker exec -it mongodb mongosh
> use air_quality
> db.realtime_data.find().limit(1)
> db.realtime_data.count()
```

**Read HDFS Data with Spark:**
```bash
# Enter Spark container
sudo docker exec -it spark-master bash

# Start PySpark
/opt/spark/bin/pyspark

# Inside PySpark:
>>> df = spark.read.parquet("hdfs://namenode:9000/air-quality/historical/")
>>> df.show()
>>> df.count()
>>> df.filter("city_name = 'Bucharest'").show()
```

## 📁 Data Schema

### Air Quality Data Structure
```json
{
  "fetch_timestamp": "2024-12-16T10:30:00",
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
    "s": "2024-12-16 10:00:00",
    "tz": "+02:00",
    "v": 1702728000,
    "iso": "2024-12-16T10:00:00+02:00"
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

### Monitored Cities

- Bucharest, Romania
- Beijing, China
- London, United Kingdom

(Can be extended in `fetch_programmatic_api.py`)

## 🔧 Configuration

### Kafka Topics

- `air-quality-historical` - For batch processing (HDFS)
- `air-quality-realtime` - For stream processing (MongoDB)

### Data Collection Frequency

- API polling: Every 5 minutes
- Spark batch processing: Every 5 minutes
- Real-time updates: Continuous streaming

### Storage

- **HDFS**: Parquet format, partitioned by city
- **MongoDB**: JSON documents with indexes on location and timestamp

## 🐛 Troubleshooting

### Kafka Connection Issues

**Problem**: Spark can't connect to Kafka
```
WARN NetworkClient: Connection to node 1 could not be established
```

**Solution**: Verify Kafka advertised listeners
```bash
# Check config
grep advertised.listeners ~/kafka_*/config/server.properties

# Should be:
advertised.listeners=PLAINTEXT://172.17.0.1:9092,CONTROLLER://localhost:9093
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

**Problem**: NameNode or DataNode fails to start

**Solution**: Clean up volumes and restart
```bash
sudo docker-compose down -v
sudo docker-compose up -d
```

### Python Package Issues

**Problem**: `ModuleNotFoundError: No module named 'kafka'`

**Solution**: Use confluent-kafka instead of kafka-python
```bash
pip uninstall kafka-python
pip install confluent-kafka
```

## 📈 Performance Metrics

### Expected Throughput

- API fetch rate: ~150-200 stations per cycle
- Kafka throughput: 1000+ messages/second
- HDFS write rate: 10-50 MB/minute
- Data retention: Unlimited (HDFS)

### Resource Usage

- Docker containers: ~4-6 GB RAM
- Kafka: ~500 MB RAM
- Python fetcher: ~100 MB RAM


## 📚 Additional Resources

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Apache Spark Structured Streaming](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html)
- [Hadoop HDFS Guide](https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-hdfs/HdfsUserGuide.html)
- [WAQI API Documentation](https://aqicn.org/json-api/doc/)