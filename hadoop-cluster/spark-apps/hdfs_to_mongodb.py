from pyspark.sql import SparkSession
from pyspark.sql.functions import col
from pymongo import MongoClient
import json

spark = SparkSession.builder \
    .appName("HDFSToMongoDB") \
    .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")

# Read all Parquet files from HDFS
print("Reading data from HDFS...")
df = spark.read.parquet("hdfs://namenode:9000/air-quality/historical/")

# Flatten nested structures
flattened_df = df.select(
    col("fetch_timestamp"),
    col("city_name"),
    col("idx"),
    col("aqi"),
    col("dominentpol"),
    col("city.name").alias("station_name"),
    col("city.geo").getItem(0).alias("latitude"),
    col("city.geo").getItem(1).alias("longitude"),
    col("city.url").alias("station_url"),
    col("time.s").alias("measurement_time"),
    col("time.iso").alias("measurement_time_iso"),
    col("iaqi.pm25.v").alias("pm25"),
    col("iaqi.pm10.v").alias("pm10"),
    col("iaqi.o3.v").alias("ozone"),
    col("iaqi.no2.v").alias("no2"),
    col("iaqi.so2.v").alias("so2"),
    col("iaqi.co.v").alias("co"),
    col("iaqi.t.v").alias("temperature"),
    col("iaqi.h.v").alias("humidity"),
    col("iaqi.p.v").alias("pressure"),
    col("iaqi.w.v").alias("wind_speed")
)

# Convert to list of dictionaries
print("Converting to Python objects...")
records = [row.asDict() for row in flattened_df.collect()]
print(f"Found {len(records)} records")

# Connect to MongoDB and insert
print("Connecting to MongoDB...")
client = MongoClient("mongodb://mongodb:27017/")
db = client["air_quality"]
collection = db["measurements"]

# Clear old data and insert new
print("Clearing old data...")
collection.delete_many({})

print("Inserting new data...")
if records:
    collection.insert_many(records)
    print(f"Successfully inserted {len(records)} records into MongoDB")
else:
    print("No records to insert")

# Create indexes for better query performance
print("Creating indexes...")
collection.create_index([("fetch_timestamp", -1)])
collection.create_index([("city_name", 1)])
collection.create_index([("aqi", 1)])

# Print sample
print("\nSample record:")
sample = collection.find_one()
if sample:
    # Remove _id for cleaner output
    sample.pop('_id', None)
    print(json.dumps(sample, indent=2, default=str))

# Show stats
print(f"\nTotal documents: {collection.count_documents({})}")
print("Documents by city:")
for doc in collection.aggregate([
    {"$group": {"_id": "$city_name", "count": {"$sum": 1}}},
    {"$sort": {"count": -1}}
]):
    print(f"  {doc['_id']}: {doc['count']}")

client.close()
spark.stop()