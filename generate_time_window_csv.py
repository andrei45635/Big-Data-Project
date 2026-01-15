#!/usr/bin/env python3
import pandas as pd
import numpy as np
import random

# -------------------
# CONFIG
# -------------------
CSV_PATH = "AQD.csv"
OUTPUT_PATH = "recent_window.csv"
TIME_WINDOW = 24  # same as used in LSTM training
CITY_COL = "city_name"

FEATURE_COLS = [
    "aqi", "pm25", "pm10", "ozone", "no2", "so2", "co",
    "temperature", "humidity", "pressure", "wind_speed"
]

# -------------------
# LOAD DATA
# -------------------
df = pd.read_csv(CSV_PATH)

# Parse timestamp
df["timestamp"] = pd.to_datetime(df["timestamp"])

# Filter cities with at least TIME_WINDOW rows
valid_cities = df.groupby(CITY_COL).filter(lambda x: len(x) >= TIME_WINDOW)[CITY_COL].unique()
if len(valid_cities) == 0:
    raise ValueError(f"No city has at least {TIME_WINDOW} rows.")

# Pick a random city
city = random.choice(valid_cities)
df_city = df[df[CITY_COL] == city].sort_values("timestamp")

# -------------------
# SELECT TIME WINDOW
# -------------------
# Take last TIME_WINDOW rows (you can randomize within city if you prefer)
recent_window = df_city.tail(TIME_WINDOW)

# Ensure only features are saved
recent_window = recent_window[FEATURE_COLS]

# Save CSV
recent_window.to_csv(OUTPUT_PATH, index=False)

print(f"Saved recent time window of {TIME_WINDOW} rows for city '{city}' to '{OUTPUT_PATH}'")
