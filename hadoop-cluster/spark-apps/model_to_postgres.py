from pyspark.sql import SparkSession
from pyspark.sql.functions import col
import subprocess
import os
from datetime import datetime, timedelta

spark = SparkSession.builder \
    .appName("MLPredictionsToPostgres") \
    .config("spark.jars.packages",
            "com.datastax.spark:spark-cassandra-connector_2.12:3.4.1,"
            "org.postgresql:postgresql:42.6.0") \
    .config("spark.cassandra.connection.host", "cassandra") \
    .config("spark.cassandra.connection.port", "9042") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")

print("Starting ML prediction job...")

# Configuration
CITIES = ['Bucharest', 'Beijing', 'London']
ML_SCRIPT_PATH = "/opt/spark-apps/ml_model/predict_aqi.py"
POSTGRES_URL = "jdbc:postgresql://postgres:5432/air_quality"
POSTGRES_PROPERTIES = {
    "user": "postgres",
    "password": "postgres",
    "driver": "org.postgresql.Driver"
}

# Verify Cassandra connection
try:
    test_df = spark.read \
        .format("org.apache.spark.sql.cassandra") \
        .option("keyspace", "air_quality") \
        .option("table", "hourly_metrics") \
        .load() \
        .limit(1)
    print("✓ Connected to Cassandra")
except Exception as e:
    print(f"✗ Error connecting to Cassandra: {e}")
    spark.stop()
    exit(1)

# Process each city
all_predictions = []

for city in CITIES:
    try:
        print(f"\n=== Processing {city} ===")

        # Get last 24 hours of data from Cassandra
        twenty_four_hours_ago = (datetime.now() - timedelta(hours=24)).strftime('%Y-%m-%d %H:%M:%S')

        df = spark.read \
            .format("org.apache.spark.sql.cassandra") \
            .option("keyspace", "air_quality") \
            .option("table", "latest_readings") \
            .load() \
            .filter(col("city_name") == city)
            #.filter(col("window_start") >= twenty_four_hours_ago) \
            #.orderBy("window_start")

        row_count = df.count()
        print(f"Found {row_count} hourly records for {city}")

        if row_count < 6:
            print(f"⚠ Not enough data for {city} (need at least 6 hours), skipping...")
            continue

        # Export to CSV for the ML model
        csv_path = f"/tmp/{city}_24h_data.csv"
        df.select(
            "aqi",
            "pm25",
            "pm10",
            "temperature",
            "humidity"
            ""
        ).toPandas().to_csv(csv_path, index=False)

        print(f"Exported data to {csv_path}")

        # Run the Python inference script
        result = subprocess.run(
            ["python3", ML_SCRIPT_PATH, csv_path],
            capture_output=True,
            text=True,
            timeout=60
        )

        if result.returncode == 0:
            predictions_str = result.stdout.strip()
            print(f"Raw output: {predictions_str}")

            try:
                predictions = [int(x.strip()) for x in predictions_str.split(',')]

                if len(predictions) != 6:
                    print(f"✗ Expected 6 predictions, got {len(predictions)}")
                    continue

                print(f"✓ Predictions for {city}: {predictions}")

                # Prepare predictions for PostgreSQL
                base_time = datetime.now()

                for hour_offset, predicted_aqi in enumerate(predictions, 1):
                    prediction_record = {
                        'aqi': predicted_aqi,
                        'city': city,
                        'timestamp': base_time + timedelta(hours=hour_offset)
                    }
                    all_predictions.append(prediction_record)

            except ValueError as e:
                print(f"✗ Error parsing predictions: {e}")
                continue

        else:
            print(f"✗ Error running ML script for {city}:")
            print(f"  stderr: {result.stderr}")
            continue

        # Cleanup temp file
        if os.path.exists(csv_path):
            os.remove(csv_path)

    except Exception as e:
        print(f"✗ Error processing {city}: {e}")
        import traceback

        traceback.print_exc()
        continue

# Write all predictions to PostgreSQL
if all_predictions:
    print(f"\n=== Writing {len(all_predictions)} predictions to PostgreSQL ===")

    try:
        pred_df = spark.createDataFrame(all_predictions)

        # Write to PostgreSQL
        pred_df.write \
            .jdbc(
            url=POSTGRES_URL,
            table="aqi_predictions",
            mode="append",
            properties=POSTGRES_PROPERTIES
        )

        print("✓ Successfully saved predictions to PostgreSQL")

        # Show summary
        summary = pred_df.groupBy("city").count().collect()
        for row in summary:
            print(f"  {row['city']}: {row['count']} predictions")

    except Exception as e:
        print(f"✗ Error writing to PostgreSQL: {e}")
        import traceback

        traceback.print_exc()
else:
    print("\n⚠ No predictions generated")

print("\n=== ML prediction job completed ===")
spark.stop()