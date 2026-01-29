import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------- Weather Service ----------------
class WeatherService {
  static const String _geoBaseUrl =
      'https://geocoding-api.open-meteo.com/v1/search';
  static const String _weatherBaseUrl =
      'https://api.open-meteo.com/v1/forecast';

  // Cache keys for location
  static const String _lastLocationKey = 'last_known_location';
  static const String _lastLocationNameKey = 'last_known_location_name';

  /// Fetch weather by place name
  Future<Weather> getWeatherByPlace(String placeName) async {
    final location = await _getCoordinates(placeName);
    return getWeather(location.latitude, location.longitude, location.name);
  }

  /// Fetch weather by device's current location with caching
  Future<Weather> getWeatherByCurrentLocation() async {
    // ✅ Try to get cached location first (instant)
    final cachedLocation = await _getCachedLocation();
    if (cachedLocation != null) {
      print('📍 Using cached location: ${cachedLocation['name']}');

      // Get weather with cached location immediately
      final weatherFuture = getWeather(
        cachedLocation['latitude'],
        cachedLocation['longitude'],
        cachedLocation['name'],
      );

      // Update location in background (don't await)
      _updateLocationInBackground();

      return weatherFuture;
    }

    // No cache available, get fresh location
    return _fetchFreshLocation();
  }

  /// Get cached location data
  Future<Map<String, dynamic>?> _getCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationJson = prefs.getString(_lastLocationKey);

      if (locationJson != null) {
        final data = jsonDecode(locationJson) as Map<String, dynamic>;

        // Check if cache is not too old (e.g., 1 hour)
        final cachedTime = DateTime.parse(data['timestamp']);
        final age = DateTime.now().difference(cachedTime);

        if (age.inHours < 1) {
          return data;
        }
      }
    } catch (e) {
      print('❌ Error loading cached location: $e');
    }
    return null;
  }

  /// Save location to cache
  Future<void> _cacheLocation(
    double latitude,
    double longitude,
    String name,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationData = {
        'latitude': latitude,
        'longitude': longitude,
        'name': name,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_lastLocationKey, jsonEncode(locationData));
      print('✅ Location cached: $name');
    } catch (e) {
      print('❌ Error caching location: $e');
    }
  }

  /// Update location in background without blocking UI
  Future<void> _updateLocationInBackground() async {
    try {
      // Use getLastKnownPosition first (fastest)
      Position? position = await Geolocator.getLastKnownPosition();

      if (position != null) {
        final placeName = await _getPlaceNameFromCoordinates(
          position.latitude,
          position.longitude,
        );
        await _cacheLocation(position.latitude, position.longitude, placeName);
      }

      // Then get accurate position (slower)
      final accuratePosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 5),
      );

      final placeName = await _getPlaceNameFromCoordinates(
        accuratePosition.latitude,
        accuratePosition.longitude,
      );

      await _cacheLocation(
        accuratePosition.latitude,
        accuratePosition.longitude,
        placeName,
      );
    } catch (e) {
      print('⚠️ Background location update failed: $e');
      // Don't throw - this is background update
    }
  }

  /// Fetch fresh location (used when no cache available)
  Future<Weather> _fetchFreshLocation() async {
    // Check and request location permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    // ✅ Try cached position first
    Position? position = await Geolocator.getLastKnownPosition();

    position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 5),
      );

    // Get place name from coordinates using reverse geocoding
    String placeName = await _getPlaceNameFromCoordinates(
      position.latitude,
      position.longitude,
    );

    // Cache the location for next time
    await _cacheLocation(position.latitude, position.longitude, placeName);

    return getWeather(position.latitude, position.longitude, placeName);
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

  /// Private: Get place name from coordinates (reverse geocoding)
  Future<String> _getPlaceNameFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Return city name, or locality, or subAdministrativeArea
        return place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea ??
            'Unknown Location';
      }
      return 'Unknown Location';
    } catch (e) {
      return 'Unknown Location';
    }
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

  /// Clear cached location (useful for testing)
  Future<void> clearLocationCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastLocationKey);
    await prefs.remove(_lastLocationNameKey);
    print('🗑️ Location cache cleared');
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
