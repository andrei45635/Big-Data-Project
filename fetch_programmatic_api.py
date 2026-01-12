
import json
import logging
import time
from datetime import datetime

import requests

from kafka import KafkaProducer

# create api_keys.py and define tokens manually inside it
from api_keys import WAQI_TOKEN, OPENWEATHER_KEY

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

WAQI_BASE = "https://api.waqi.info"
OWM_BASE = "https://api.openweathermap.org/data/2.5"

# Kafka Producer
producer = KafkaProducer(
    bootstrap_servers=['localhost:9092'],
    value_serializer=lambda v: json.dumps(v).encode('utf-8'),
    acks='all',
    retries=3
)

CITIES = {
    'Bucharest': {'lat': 44.4268, 'lon': 26.1025, 'bounds': '44.508589,25.936583,44.389144,26.300223'},
    'Beijing': {'lat': 39.9042, 'lon': 116.4074, 'bounds': '39.379436,116.091230,40.235643,116.784382'},
    'London': {'lat': 51.5074, 'lon': -0.1278, 'bounds': '51.699454,-0.599659,51.314690,0.387957'},
}


def fetch_air_quality(bounds):
    url = f"{WAQI_BASE}/v2/map/bounds/?latlng={bounds}&token={WAQI_TOKEN}"
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    data = response.json()

    if data['status'] != 'ok':
        raise Exception(f"WAQI API error: {data.get('data')}")

    return data['data']

def fetch_station_details(station_uid):
    url = f"{WAQI_BASE}/feed/@{station_uid}/?token={WAQI_TOKEN}"
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    data = response.json()

    if data['status'] != 'ok':
        raise Exception(f"Station API error: {data.get('reason')}")

    return data['data']

def fetch_weather(lat, lon):
    url = f"{OWM_BASE}/weather?lat={lat}&lon={lon}&appid={OPENWEATHER_KEY}&units=metric"
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    return response.json()


def fetch_and_publish():
    while True:
        try:
            fetch_timestamp = datetime.utcnow().isoformat()

            for city_name, city_info in CITIES.items():
                logger.info(f"Fetching data for {city_name}")

                stations = fetch_air_quality(city_info['bounds'])

                for station in stations:
                    try:
                        details = fetch_station_details(station['uid'])

                        combined_data = {
                            'fetch_timestamp': fetch_timestamp,
                            'city_name': city_name,
                            'idx': details.get('idx'),
                            'aqi': details['aqi'],
                            'dominentpol': details.get('dominentpol'),
                            'city': {
                                'name': details['city']['name'],
                                'geo': details['city']['geo'],
                                'url': details['city'].get('url'),
                                'location': details['city'].get('location', '')
                            },
                            'time': {
                                's': details['time']['s'],
                                'tz': details['time']['tz'],
                                'v': details['time']['v'],
                                'iso': details['time']['iso']
                            },
                            'iaqi': details.get('iaqi', {}),
                            'attributions': details.get('attributions', []),
                            'forecast': details.get('forecast', {}),
                        }

                        producer.send('air-quality-realtime', combined_data)
                        producer.send('air-quality-historical', combined_data)

                        logger.info(
                            f"Published: {details['city']['name']} - "
                            f"AQI: {details['aqi']} - "
                            f"Dominant: {details.get('dominentpol', 'N/A')}"
                        )

                        time.sleep(1)

                    except Exception as e:
                        logger.error(f"Error fetching details for station {station['uid']}: {e}")
                        continue

                time.sleep(2)

            producer.flush()
            logger.info(f"Cycle complete. Waiting 5 minutes...")
            time.sleep(300)

        except requests.RequestException as e:
            logger.error(f"API fetch failed: {e}")
            time.sleep(60)
        except Exception as e:
            logger.error(f"Unexpected error: {e}", exc_info=True)
            time.sleep(60)


if __name__ == "__main__":
    try:
        logger.info("Starting data collection...")
        fetch_and_publish()
    finally:
        producer.close()
