#!/bin/bash

# ---- CONFIG ----
HOST="localhost"
PORT="5432"
DB="air_quality"
USER="postgres"
TABLE="air_quality_data"
OUTPUT="./AQD.csv"
# ----------------

# Optional: avoid password prompt
export PGPASSWORD="postgres"

psql \
  -h "$HOST" \
  -p "$PORT" \
  -U "$USER" \
  -d "$DB" \
  -c "\copy $TABLE TO '$OUTPUT' CSV HEADER"

echo "Exported $TABLE to $OUTPUT"
