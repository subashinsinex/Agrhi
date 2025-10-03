import 'dart:convert';
import 'package:http/http.dart' as http;

/// ---------------- Weather Service ----------------
class WeatherService {
  static const String _geoBaseUrl =
      'https://geocoding-api.open-meteo.com/v1/search';
  static const String _weatherBaseUrl =
      'https://api.open-meteo.com/v1/forecast';

  /// Fetch weather by place name
  Future<Weather> getWeatherByPlace(String placeName) async {
    final location = await _getCoordinates(placeName);
    return getWeather(location.latitude, location.longitude, location.name);
  }

  /// Fetch weather by latitude & longitude
  Future<Weather> getWeather(
    double latitude,
    double longitude, [
    String? placeName,
  ]) async {
    final uri = Uri.parse(
      '$_weatherBaseUrl?latitude=$latitude&longitude=$longitude&current_weather=true',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch weather. Status: ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final currentWeather = json['current_weather'] as Map<String, dynamic>?;

    if (currentWeather == null) {
      throw const FormatException('Missing current_weather data');
    }

    return Weather.fromJson(currentWeather, placeName ?? 'Unknown');
  }

  /// Private: Get coordinates by place name
  Future<Location> _getCoordinates(String placeName) async {
    final uri = Uri.parse('$_geoBaseUrl?name=$placeName&count=1');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch location data. Status: ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>?;

    if (results == null || results.isEmpty) {
      throw Exception('No location found for "$placeName"');
    }

    final firstResult = results.first as Map<String, dynamic>;
    return Location(
      name: firstResult['name'] ?? placeName,
      latitude: (firstResult['latitude'] as num).toDouble(),
      longitude: (firstResult['longitude'] as num).toDouble(),
    );
  }
}

/// ---------------- Location Model ----------------
class Location {
  final String name;
  final double latitude;
  final double longitude;

  const Location({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

/// ---------------- Weather Model ----------------
class Weather {
  final String locationName;
  final double temperature;
  final double windSpeed;
  final int weatherCode;

  const Weather({
    required this.locationName,
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
  });

  /// Convert weatherCode → human-readable condition
  String get condition {
    switch (weatherCode) {
      case 0:
        return 'Clear';
      case 1:
      case 2:
      case 3:
        return 'Partly Cloudy';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return 'Rain';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return 'Snow';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Unknown';
    }
  }

  factory Weather.fromJson(Map<String, dynamic> json, String locationName) {
    return Weather(
      locationName: locationName,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      windSpeed: (json['windspeed'] as num?)?.toDouble() ?? 0.0,
      weatherCode: (json['weathercode'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() =>
      'Weather in $locationName → $condition, Temp: $temperature°C, Wind: $windSpeed km/h';
}
