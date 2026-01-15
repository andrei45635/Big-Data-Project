import pandas as pd
import numpy as np
import joblib
from sklearn.preprocessing import MinMaxScaler
from sklearn.model_selection import train_test_split
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.callbacks import EarlyStopping

# -------------------
# CONFIG
# -------------------
CSV_PATH = "AQD.csv"
TIME_WINDOW = 24        # past hours used for prediction
FORECAST_HORIZON = 6    # hours into the future
BATCH_SIZE = 32
EPOCHS = 50

TARGET_COL = "aqi"

FEATURE_COLS = [
    "aqi",
    "pm25", "pm10", "ozone", "no2", "so2", "co",
    "temperature", "humidity", "pressure", "wind_speed"
]

CITY_COL = "city_name"

# -------------------
# LOAD DATA
# -------------------
df = pd.read_csv(CSV_PATH)

# Parse timestamp and sort
df["timestamp"] = pd.to_datetime(df["timestamp"])
df = df.sort_values(["city_name", "timestamp"])

# -------------------
# HANDLE MISSING DATA
# -------------------
# Forward-fill and back-fill per city
df[FEATURE_COLS] = df.groupby(CITY_COL)[FEATURE_COLS].transform(lambda x: x.ffill().bfill())

# Then optionally fill any remaining NaNs with 0 (or mean)
df[FEATURE_COLS] = df[FEATURE_COLS].fillna(0)

# -------------------
# SCALE DATA
# -------------------
scaler = MinMaxScaler()
df[FEATURE_COLS] = scaler.fit_transform(df[FEATURE_COLS])

# -------------------
# CREATE SEQUENCES PER CITY
# -------------------
def create_sequences_city(df, city, window, horizon, feature_cols, target_col):
    city_data = df[df[CITY_COL] == city][feature_cols].values
    target_index = feature_cols.index(target_col)
    X, y = [], []
    for i in range(len(city_data) - window - horizon):
        X.append(city_data[i:i+window])
        y.append(city_data[i+window:i+window+horizon, target_index])
    return np.array(X), np.array(y)

# Combine sequences from all cities
X_list, y_list = [], []
for city in df[CITY_COL].unique():
    X_city, y_city = create_sequences_city(df, city, TIME_WINDOW, FORECAST_HORIZON, FEATURE_COLS, TARGET_COL)
    X_list.append(X_city)
    y_list.append(y_city)

X = np.concatenate(X_list, axis=0)
y = np.concatenate(y_list, axis=0)

print("Input shape:", X.shape)
print("Target shape:", y.shape)

# -------------------
# TRAIN / VALIDATION SPLIT
# -------------------
X_train, X_val, y_train, y_val = train_test_split(
    X, y, test_size=0.2, shuffle=False
)

# -------------------
# BUILD LSTM MODEL
# -------------------
model = Sequential([
    LSTM(64, return_sequences=True, input_shape=(TIME_WINDOW, X.shape[2])),
    Dropout(0.2),
    LSTM(32),
    Dense(FORECAST_HORIZON)
])

model.compile(optimizer="adam", loss="mse")
model.summary()

# -------------------
# TRAIN
# -------------------
early_stop = EarlyStopping(monitor="val_loss", patience=5, restore_best_weights=True)

history = model.fit(
    X_train, y_train,
    validation_data=(X_val, y_val),
    epochs=EPOCHS,
    batch_size=BATCH_SIZE,
    callbacks=[early_stop]
)

# -------------------
# PREDICT FUTURE AQI
# -------------------
def predict_future(model, recent_window, scaler, target_index):
    recent_window = recent_window.reshape(1, TIME_WINDOW, -1)
    pred_scaled = model.predict(recent_window)[0]

    # Inverse scaling (AQI only)
    dummy = np.zeros((FORECAST_HORIZON, len(FEATURE_COLS)))
    dummy[:, target_index] = pred_scaled
    inv = scaler.inverse_transform(dummy)
    return inv[:, target_index]

# Example inference for last window of a city
city = df[CITY_COL].unique()[1]
city_data = df[df[CITY_COL]==city][FEATURE_COLS].values
target_index = FEATURE_COLS.index(TARGET_COL)
recent_window = city_data[-TIME_WINDOW:]
future_aqi = predict_future(model, recent_window, scaler, target_index)

print(f"Predicted future AQI for city {city}:")
print(future_aqi)

model.save("aqi_model_lstm.keras")
joblib.dump(scaler, "hadoop-cluster/spark-apps/ml_model/scaler.save")
