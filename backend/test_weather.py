import requests
import json

WEATHER_API_KEY = "f7f801c0305954c2b950cf7faa3b2aef"
url = f"https://api.openweathermap.org/data/2.5/weather?q=Sangli&appid={WEATHER_API_KEY}&units=metric"

try:
    resp = requests.get(url, timeout=5)
    print("Status:", resp.status_code)
    print("Response:", json.dumps(resp.json(), indent=2))
except Exception as e:
    print("Error:", e)
