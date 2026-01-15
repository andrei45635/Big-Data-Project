#!/usr/bin/env python3
import sys
import pandas as pd
import numpy as np
import joblib
from tensorflow.keras.models import load_model

# -------------------
# CONFIG
# -------------------
MODEL_PATH = "aqi_model_lstm.keras"       # folder saved by model.save()
SCALER_PATH = "scaler.save"         # MinMaxScaler saved with joblib
FEATURE_COLS = [
    "aqi", "pm25", "pm10", "ozone", "no2", "so2", "co",
    "temperature", "humidity", "pressure", "wind_speed"
]
TARGET_COL = "aqi"

# -------------------
# ARG CHECK
# -------------------
if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} <time_window_csv>")
    sys.exit(1)

TIME_WINDOW_CSV = sys.argv[1]

# -------------------
# LOAD MODEL AND SCALER
# -------------------
model = load_model(MODEL_PATH)
scaler = joblib.load(SCALER_PATH)

# -------------------
# LOAD TIME WINDOW
# -------------------
df = pd.read_csv(TIME_WINDOW_CSV)

# Ensure all required columns exist
missing_cols = set(FEATURE_COLS) - set(df.columns)
if missing_cols:
    print(f"Error: missing columns in input CSV: {missing_cols}")
    sys.exit(1)

# -------------------
# HANDLE MISSING DATA
# -------------------
# Forward-fill, back-fill per column
df[FEATURE_COLS] = df[FEATURE_COLS].ffill().bfill()

# Fill any remaining NaNs with 0 (safeguard)
df[FEATURE_COLS] = df[FEATURE_COLS].fillna(0)

# -------------------
# PREPARE INPUT
# -------------------
X_window = df[FEATURE_COLS].values

# Check shape
if X_window.shape[0] != model.input_shape[1]:
    print(f"Error: time window length {X_window.shape[0]} "
          f"does not match model input length {model.input_shape[1]}")
    sys.exit(1)

# Scale features
X_scaled = scaler.transform(X_window)

# Reshape for LSTM: (1, TIME_WINDOW, num_features)
X_scaled = X_scaled.reshape(1, X_scaled.shape[0], X_scaled.shape[1])

# -------------------
# RUN INFERENCE
# -------------------
pred_scaled = model.predict(X_scaled)[0]

# Inverse transform AQI only
dummy = np.zeros((pred_scaled.shape[0], len(FEATURE_COLS)))
target_index = FEATURE_COLS.index(TARGET_COL)
dummy[:, target_index] = pred_scaled
pred_aqi = scaler.inverse_transform(dummy)[:, target_index]

# -------------------
# OUTPUT
# -------------------
# print("Predicted future AQI:")
# for i, val in enumerate(pred_aqi, 1):
#     print(f"t+{i}: {val:.2f}")

print(','.join([str(val) for _, val in enumerate(pred_aqi, 1)]))
