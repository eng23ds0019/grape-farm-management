import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature;
  final int humidity;
  final double rainfall;
  final double windSpeed;
  final String condition;
  final String forecast;
  final String location;
  final int cloud_cover;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.rainfall,
    required this.windSpeed,
    required this.condition,
    required this.forecast,
    required this.location,
    required this.cloud_cover,
  });

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'rainfall': rainfall,
      'windSpeed': windSpeed,
      'condition': condition,
      'forecast': forecast,
      'location': location,
      'cloud_cover': cloud_cover,
    };
  }

  @override
  String toString() {
    return "Location: $location, Temp: ${temperature.toStringAsFixed(1)}°C, Humidity: $humidity%, Rain: ${rainfall.toStringAsFixed(1)}mm, Wind: ${windSpeed.toStringAsFixed(1)}km/h, Condition: $condition, Forecast: $forecast, Clouds: $cloud_cover%";
  }
}

class WeatherService {
  static const String _apiKey = "f7f801c0305954c2b950cf7faa3b2aef";
  static const String _baseUrl = "https://api.openweathermap.org/data/2.5";

  /// Retrieves weather for a location string (e.g. "Nashik", "Sangli"). 
  /// If API key is missing or fails, falls back to a simulated forecast.
  static Future<WeatherData> getCurrentWeather(String location) async {
    if (location.isEmpty) location = "Sangli"; // Fallback to Sangli instead of Nashik

    if (_apiKey == "YOUR_OPENWEATHERMAP_API_KEY") {
      debugPrint("WeatherService: No API key set. Using simulated weather for $location.");
      return _getSimulatedWeather(location);
    }

    try {
      Uri url;
      if (location.contains(',')) {
        final parts = location.split(',');
        final lat = double.tryParse(parts[0].trim());
        final lon = double.tryParse(parts[1].trim());
        if (lat != null && lon != null) {
          url = Uri.parse("$_baseUrl/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric");
        } else {
          url = Uri.parse("$_baseUrl/weather?q=$location&appid=$_apiKey&units=metric");
        }
      } else {
        url = Uri.parse("$_baseUrl/weather?q=$location&appid=$_apiKey&units=metric");
      }
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final temp = (data['main']['temp'] as num).toDouble();
        final humidity = (data['main']['humidity'] as num).toInt();
        final wind = (data['wind']['speed'] as num).toDouble();
        final condition = data['weather'][0]['main'].toString();
        
        // Check for rain volume in last 1h
        double rain = 0.0;
        if (data.containsKey('rain') && data['rain'].containsKey('1h')) {
          rain = (data['rain']['1h'] as num).toDouble();
        }

        final cloudCover = (data['clouds']?['all'] as num?)?.toInt() ?? 0;

        return WeatherData(
          temperature: temp,
          humidity: humidity,
          rainfall: rain,
          windSpeed: wind,
          condition: condition,
          forecast: "Similar conditions expected for the next 24 hours.",
          location: data['name']?.toString() ?? location,
          cloud_cover: cloudCover,
        );
      } else {
        debugPrint("WeatherService: OpenWeather API failed with ${response.statusCode}: ${response.body}");
        return _getSimulatedWeather(location);
      }
    } catch (e) {
      debugPrint("WeatherService: Network error fetching weather: $e");
      return _getSimulatedWeather(location);
    }
  }

  static WeatherData _getSimulatedWeather(String location) {
    // Generate a slightly random but realistic grape-growing weather scenario
    final hour = DateTime.now().hour;
    double temp = hour > 8 && hour < 18 ? 31.5 : 24.0; // Warmer in day
    return WeatherData(
      temperature: temp,
      humidity: 82,
      rainfall: 0.5,
      windSpeed: 12.0,
      condition: "Cloudy",
      forecast: "High humidity and cloudy skies. Favorable for mildew development.",
      location: location,
      cloud_cover: 80,
    );
  }
}
