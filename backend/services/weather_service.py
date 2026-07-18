"""
Weather Service — OpenWeatherMap integration.
Caches for 30 minutes. Falls back to simulated data on failure.
"""
import os
import time
import requests
from typing import Optional

WEATHER_API_KEY = os.getenv("WEATHER_API_KEY", "f7f801c0305954c2b950cf7faa3b2aef")
BASE_URL = "https://api.openweathermap.org/data/2.5"

_cache = {}
_cache_ttl = 1800  # 30 minutes


def get_weather(location: str = "Nashik", lat: Optional[float] = None, lon: Optional[float] = None) -> dict:
    # Use coordinates if available for caching and querying
    cache_key = f"{lat},{lon}" if lat and lon else location.lower()
    cached = _cache.get(cache_key)
    if cached and (time.time() - cached["_ts"]) < _cache_ttl:
        return cached["data"]

    try:
        if lat and lon:
            url = f"{BASE_URL}/weather?lat={lat}&lon={lon}&appid={WEATHER_API_KEY}&units=metric"
        else:
            url = f"{BASE_URL}/weather?q={location}&appid={WEATHER_API_KEY}&units=metric"
            
        resp = requests.get(url, timeout=5)

        if resp.status_code == 200:
            data = resp.json()
            result = {
                "location": data.get("name", location),
                "temperature": round(data["main"]["temp"], 1),
                "feels_like": round(data["main"]["feels_like"], 1),
                "humidity": data["main"]["humidity"],
                "condition": data["weather"][0]["main"],
                "description": data["weather"][0]["description"],
                "wind_speed": round(data["wind"]["speed"] * 3.6, 1),  # m/s to km/h
                "rainfall_1h": data.get("rain", {}).get("1h", 0.0),
                "cloud_cover": data.get("clouds", {}).get("all", 0),
                "visibility": data.get("visibility", 10000) / 1000,
                "source": "OpenWeatherMap",
            }
            _cache[cache_key] = {"data": result, "_ts": time.time()}
            return result
        else:
            print(f"⚠️  Weather API error {resp.status_code}: {resp.text[:100]}")
            return _fallback_weather(location)

    except Exception as e:
        print(f"❌ Weather service error: {e}")
        return _fallback_weather(location)


def format_for_prompt(weather: dict) -> str:
    return (
        f"Weather in {weather['location']}: "
        f"Temp {weather['temperature']}°C, "
        f"Humidity {weather['humidity']}%, "
        f"Condition: {weather['condition']} ({weather['description']}), "
        f"Wind: {weather['wind_speed']} km/h, "
        f"Rain last hour: {weather['rainfall_1h']} mm, "
        f"Cloud cover: {weather['cloud_cover']}%"
    )


def _fallback_weather(location: str) -> dict:
    """Realistic simulation for Maharashtra grape region."""
    import datetime
    hour = datetime.datetime.now().hour
    temp = 31.5 if 8 < hour < 18 else 24.0
    return {
        "location": location,
        "temperature": temp,
        "feels_like": temp + 2,
        "humidity": 78,
        "condition": "Clouds",
        "description": "scattered clouds",
        "wind_speed": 12.0,
        "rainfall_1h": 0.0,
        "cloud_cover": 65,
        "visibility": 8.0,
        "source": "Simulated",
    }
