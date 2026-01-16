from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_timestamp

spark = SparkSession.builder \
    .appName("HDFSToPostgres") \
    .config("spark.jars.packages", "org.postgresql:postgresql:42.6.0") \
    .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")

print("Reading data from HDFS...")
df = spark.read.parquet("hdfs://namenode:9000/air-quality/historical/")

flattened_df = df.select(
    col("fetch_timestamp"),
    col("city_name"),
    col("idx"),
    col("aqi"),
    col("dominentpol").alias("dominant_pollutant"),
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

final_df = flattened_df.withColumn(
    "timestamp",
    to_timestamp(col("fetch_timestamp"))
)

print(f"Found {final_df.count()} records to write")

jdbc_url = "jdbc:postgresql://postgres:5432/air_quality"
connection_properties = {
    "user": "postgres",
    "password": "postgres",
    "driver": "org.postgresql.Driver"
}

print("Writing to PostgreSQL...")
final_df.write \
    .jdbc(
        url=jdbc_url,
        table="air_quality_data",
        mode="overwrite",
        properties=connection_properties
    )

print("Successfully wrote data to PostgreSQL!")

print("\nData summary:")
final_df.groupBy("city_name").count().show()

spark.stop()