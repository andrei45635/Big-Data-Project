from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    from_json, col, window, avg, max as spark_max,
    min as spark_min, count, to_timestamp, current_timestamp
)
from pyspark.sql.types import *

spark = SparkSession.builder \
    .appName("KafkaToCassandra") \
    .config("spark.jars.packages",
            "org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.3,"
            "com.datastax.spark:spark-cassandra-connector_2.12:3.4.1") \
    .config("spark.cassandra.connection.host", "cassandra") \
    .config("spark.cassandra.connection.port", "9042") \
    .config("spark.sql.extensions", "com.datastax.spark.connector.CassandraSparkExtensions") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")

# Schema for incoming data
schema = StructType([
    StructField("fetch_timestamp", StringType()),
    StructField("city_name", StringType()),
    StructField("idx", IntegerType()),
    StructField("aqi", IntegerType()),
    StructField("dominentpol", StringType()),
    StructField("city", StructType([
        StructField("name", StringType()),
        StructField("geo", ArrayType(DoubleType())),
    ])),
    StructField("iaqi", MapType(StringType(), StructType([
        StructField("v", DoubleType())
    ]))),
])

# Read from Kafka
df = spark \
    .readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "172.17.0.1:9092") \
    .option("subscribe", "air-quality-realtime") \
    .option("startingOffsets", "latest") \
    .option("failOnDataLoss", "false") \
    .load()

# Parse JSON
parsed_df = df.select(
    from_json(col("value").cast("string"), schema).alias("data")
).select("data.*")

# Add proper timestamp
timestamped_df = parsed_df.withColumn(
    "timestamp",
    to_timestamp(col("fetch_timestamp"))
)

# Flatten for processing
flattened_df = timestamped_df.select(
    col("timestamp"),
    col("city_name"),
    col("city.name").alias("station_name"),
    col("aqi"),
    col("iaqi.pm25.v").alias("pm25"),
    col("iaqi.pm10.v").alias("pm10"),
    col("iaqi.t.v").alias("temperature"),
    col("iaqi.h.v").alias("humidity")
)

# === SPEED LAYER 1: Latest Readings ===
def write_latest_to_cassandra(batch_df, batch_id):
    batch_df.write \
        .format("org.apache.spark.sql.cassandra") \
        .mode("append") \
        .option("keyspace", "air_quality") \
        .option("table", "latest_readings") \
        .save()

latest_query = flattened_df \
    .writeStream \
    .foreachBatch(write_latest_to_cassandra) \
    .outputMode("append") \
    .option("checkpointLocation", "hdfs://namenode:9000/checkpoints/cassandra-latest") \
    .start()

# === SPEED LAYER 2: Hourly Time Windows ===
windowed_df = flattened_df \
    .withWatermark("timestamp", "10 minutes") \
    .groupBy(
        col("city_name"),
        window(col("timestamp"), "1 hour")
    ) \
    .agg(
        avg("aqi").alias("avg_aqi"),
        spark_max("aqi").alias("max_aqi"),
        spark_min("aqi").alias("min_aqi"),
        avg("pm25").alias("avg_pm25"),
        avg("pm10").alias("avg_pm10"),
        avg("temperature").alias("avg_temperature"),
        avg("humidity").alias("avg_humidity"),
        count("*").alias("record_count")
    ) \
    .select(
        col("city_name"),
        col("window.start").alias("window_start"),
        col("window.end").alias("window_end"),
        col("avg_aqi"),
        col("max_aqi"),
        col("min_aqi"),
        col("avg_pm25"),
        col("avg_pm10"),
        col("avg_temperature"),
        col("avg_humidity"),
        col("record_count")
    )

def write_windows_to_cassandra(batch_df, batch_id):
    batch_df.write \
        .format("org.apache.spark.sql.cassandra") \
        .mode("append") \
        .option("keyspace", "air_quality") \
        .option("table", "hourly_metrics") \
        .save()

windowed_query = windowed_df \
    .writeStream \
    .foreachBatch(write_windows_to_cassandra) \
    .outputMode("update") \
    .option("checkpointLocation", "hdfs://namenode:9000/checkpoints/cassandra-windows") \
    .start()

# Wait for both queries
spark.streams.awaitAnyTermination()