from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, ArrayType, MapType

spark = (SparkSession.builder
         .appName("KafkaToHDFS")
         .config("spark.jars.packages", "org.apache.spark:spark-sql-kafka-0-10_2.12:4.1.1")
         .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000")
         .getOrCreate())

spark.sparkContext.setLogLevel("INFO")

schema = StructType([
    StructField("fetch_timestamp", StringType()),
    StructField("city_name", StringType()),
    StructField("idx", IntegerType()),
    StructField("aqi", IntegerType()),
    StructField("dominentpol", StringType()),
    StructField("city", StructType([
        StructField("name", StringType()),
        StructField("geo", ArrayType(DoubleType())),
        StructField("url", StringType()),
        StructField("location", StringType())
    ])),
    StructField("time", StructType([
        StructField("s", StringType()),
        StructField("tz", StringType()),
        StructField("v", IntegerType()),
        StructField("iso", StringType())
    ])),
    StructField("iaqi", MapType(StringType(), StructType([
        StructField("v", DoubleType())
    ]))),
    StructField("attributions", ArrayType(StructType([
        StructField("name", StringType()),
        StructField("url", StringType())
    ]))),
    StructField("forecast", MapType(StringType(), StringType()))  # Simplified
])

df = (spark
      .readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", "172.17.0.1:9092")
      .option("subscribe", "air-quality-historical")
      .option("startingOffsets", "earliest")
      .load())

parsed_df = df.select(
    from_json(col("value").cast("string"), schema).alias("data")
).select("data.*")

query = parsed_df \
    .writeStream \
    .format("parquet") \
    .option("path", "hdfs://namenode:9000/air-quality/historical") \
    .option("checkpointLocation", "hdfs://namenode:9000/checkpoints/historical") \
    .partitionBy("city_name") \
    .outputMode("append") \
    .trigger(processingTime="5 minutes") \
    .start()

query.awaitTermination()