import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/smart_retranslator.dart';

class WeatherCard extends StatefulWidget {
  final bool useDeviceLocation;
  final Color? backgroundColor;

  const WeatherCard({
    super.key,
    this.useDeviceLocation = true,
    this.backgroundColor,
  });

  @override
  State<WeatherCard> createState() => WeatherCardState();
}

class WeatherCardState extends State<WeatherCard>
    with SingleTickerProviderStateMixin {
  bool isRefreshing = false;
  bool hasCachedData = false;
  late final AnimationController _rotateController;

  String locationName = 'Loading...';
  double temperature = 0.0;
  String condition = 'Loading';
  double windSpeed = 0.0;
  String timeLabel = 'Now';

  static const _weatherTimeout = Duration(seconds: 10);
  static const _locationTimeout = Duration(seconds: 10);
  static const _cacheKey = 'weather_card_cache_v2';
  static const _cacheMaxAge = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCachedWeather();
      unawaited(_refreshIfNeededInBackground());
    });
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _refreshIfNeededInBackground() async {
    final cached = await _getCachedWeather();
    if (cached == null) {
      await refreshWeather(forceRefresh: true, showLoaderOnlyIfEmpty: true);
      return;
    }

    final age = DateTime.now().difference(cached.updatedAt);
    if (age > _cacheMaxAge) {
      await refreshWeather(forceRefresh: true, showLoaderOnlyIfEmpty: false);
    }
  }

Future<void> refreshWeather({
    bool forceRefresh = false,
    bool showLoaderOnlyIfEmpty = true,
  }) async {
    if (!mounted || isRefreshing || !widget.useDeviceLocation) return;

    final shouldShowFallbackState = showLoaderOnlyIfEmpty
        ? !hasCachedData
        : true;

    setState(() => isRefreshing = true);

    if (mounted) {
      _rotateController.repeat();
    }

    try {
      final cached = await _getCachedWeather();

      if (!mounted) return;

      if (!forceRefresh && cached != null) {
        final age = DateTime.now().difference(cached.updatedAt);

        if (age <= _cacheMaxAge) {
          setState(() {
            hasCachedData = true;
            locationName = cached.locationName;
            temperature = cached.temperature;
            windSpeed = cached.windSpeed;
            condition = cached.condition;
            timeLabel = 'Saved ${_formatAge(age)} ago';
          });
          return;
        }
      }

      final position = await _getSafePosition();

      if (!mounted) return;

      final weatherFuture = _fetchWeather(
        position.latitude,
        position.longitude,
      );

      final locationFuture = _resolveLocationName(
        position.latitude,
        position.longitude,
      );

      final results = await Future.wait([weatherFuture, locationFuture]);

      if (!mounted) return;

      final weather = results[0] as _WeatherData;
      final resolvedLocation = results[1] as String;

      final cachedData = _CachedWeatherData(
        locationName: resolvedLocation,
        temperature: weather.temperature,
        windSpeed: weather.windSpeed,
        condition: weather.condition,
        updatedAt: DateTime.now(),
      );

      await _saveCachedWeather(cachedData);

      if (!mounted) return;

      setState(() {
        hasCachedData = true;
        locationName = resolvedLocation;
        temperature = weather.temperature;
        windSpeed = weather.windSpeed;
        condition = weather.condition;
        timeLabel = 'Updated now';
      });
    } catch (_) {
      if (!mounted) return;

      if (!hasCachedData && shouldShowFallbackState) {
        setState(() {
          locationName = 'Retry location';
          temperature = 0.0;
          windSpeed = 0.0;
          condition = 'Tap to retry';
          timeLabel = 'Retry';
        });
      }
    } finally {
      if (!mounted) return;

      _rotateController.stop();
      _rotateController.reset();

      setState(() => isRefreshing = false);
    }
  }
  
  Future<void> _loadCachedWeather() async {
    try {
      final cached = await _getCachedWeather();
      if (cached == null) return;

      final age = DateTime.now().difference(cached.updatedAt);

      if (!mounted) return;

      setState(() {
        hasCachedData = true;
        locationName = cached.locationName;
        temperature = cached.temperature;
        windSpeed = cached.windSpeed;
        condition = cached.condition;
        timeLabel = age <= _cacheMaxAge
            ? 'Saved ${_formatAge(age)} ago'
            : 'Syncing...';
      });
    } catch (_) {}
  }

  Future<_CachedWeatherData?> _getCachedWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;

      return _CachedWeatherData.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCachedWeather(_CachedWeatherData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data.toJson()));
    } catch (_) {}
  }

  String _formatAge(Duration age) {
    if (age.inMinutes < 1) return 'just now';
    if (age.inMinutes < 60) return '${age.inMinutes}m';
    if (age.inHours < 24) return '${age.inHours}h';
    return '${age.inDays}d';
  }

  Future<Position> _getSafePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission().timeout(
        _locationTimeout,
      );
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied forever');
    }

    final lastKnown = await Geolocator.getLastKnownPosition();

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: _locationTimeout,
      );
    } on TimeoutException {
      if (lastKnown != null) return lastKnown;
      rethrow;
    } catch (_) {
      if (lastKnown != null) return lastKnown;
      rethrow;
    }
  }

  Future<_WeatherData> _fetchWeather(double lat, double lon) async {
    final weatherUri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat'
      '&longitude=$lon'
      '&current=temperature_2m,wind_speed_10m,weather_code'
      '&timezone=auto',
    );

    final response = await http.get(weatherUri).timeout(_weatherTimeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to load weather');
    }

    final weatherJson = jsonDecode(response.body) as Map<String, dynamic>;
    final current = weatherJson['current'] as Map<String, dynamic>?;

    if (current == null) {
      throw Exception('Current weather data missing');
    }

    return _WeatherData(
      temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
      windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
      condition: _mapWeatherCode(
        (current['weather_code'] as num?)?.toInt() ?? -1,
      ),
    );
  }

  Future<String> _resolveLocationName(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];

        void addPart(String? value) {
          final v = value?.trim();
          if (v == null || v.isEmpty) return;
          final exists = parts.any(
            (item) => item.toLowerCase() == v.toLowerCase(),
          );
          if (!exists) parts.add(v);
        }

        addPart(p.locality);
        addPart(p.subAdministrativeArea);
        addPart(p.administrativeArea);

        if (parts.isNotEmpty) {
          return _compactLocation(parts.join(', '));
        }

        addPart(p.country);
        if (parts.isNotEmpty) {
          return _compactLocation(parts.join(', '));
        }
      }
    } catch (_) {}

    return '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
  }

  String _compactLocation(String value) {
    final parts = value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length <= 2) return parts.join(', ');
    return '${parts[0]}, ${parts[1]}';
  }

  String _mapWeatherCode(int code) {
    if (code == 0) return 'Clear';
    if (code == 1 || code == 2 || code == 3) return 'Partly Cloudy';
    if (code == 45 || code == 48) return 'Fog';
    if (code == 51 || code == 53 || code == 55) return 'Drizzle';
    if (code == 61 || code == 63 || code == 65) return 'Rain';
    if (code == 66 || code == 67) return 'Freezing Rain';
    if (code == 71 || code == 73 || code == 75) return 'Snow';
    if (code == 77) return 'Snow Grains';
    if (code == 80 || code == 81 || code == 82) return 'Rain Showers';
    if (code == 85 || code == 86) return 'Snow Showers';
    if (code == 95 || code == 96 || code == 99) return 'Thunderstorm';
    return 'Weather';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => refreshWeather(forceRefresh: true),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD7DEC9)),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                _WeatherIconPanel(condition: condition),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SmartReTranslator(
                        text: locationName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16.0,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF264E25),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            '${temperature.toStringAsFixed(1)}°C',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2C5A26),
                              height: 1.0,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDE8BF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: SmartReTranslator(
                              text: condition,
                              style: const TextStyle(
                                fontSize: 12.2,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4C6B39),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SmartReTranslator(
                        text: isRefreshing
                            ? 'Wind: ${windSpeed.toStringAsFixed(1)} km/h • Syncing...'
                            : 'Wind: ${windSpeed.toStringAsFixed(1)} km/h • $timeLabel',
                        style: TextStyle(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w500,
                          color: isRefreshing
                              ? const Color(0xFF5C7C4D)
                              : const Color(0xFF6A8460),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: const Color(0xFFF1F6E5),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => refreshWeather(forceRefresh: true),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _rotateController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotateController.value * 2 * math.pi,
                              child: Icon(
                                Icons.refresh_rounded,
                                color: isRefreshing
                                    ? const Color(0xFF6F9A53)
                                    : const Color(0xFF4E7A3D),
                                size: 24,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeatherData {
  final double temperature;
  final double windSpeed;
  final String condition;

  const _WeatherData({
    required this.temperature,
    required this.windSpeed,
    required this.condition,
  });
}

class _CachedWeatherData {
  final String locationName;
  final double temperature;
  final double windSpeed;
  final String condition;
  final DateTime updatedAt;

  const _CachedWeatherData({
    required this.locationName,
    required this.temperature,
    required this.windSpeed,
    required this.condition,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'locationName': locationName,
    'temperature': temperature,
    'windSpeed': windSpeed,
    'condition': condition,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory _CachedWeatherData.fromJson(Map<String, dynamic> json) {
    return _CachedWeatherData(
      locationName: json['locationName']?.toString() ?? 'Unknown location',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0.0,
      condition: json['condition']?.toString() ?? 'Weather',
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _WeatherIconPanel extends StatelessWidget {
  final String condition;

  const _WeatherIconPanel({required this.condition});

  @override
  Widget build(BuildContext context) {
    final normalized = condition.toLowerCase();
    final isSunny = normalized.contains('clear') || normalized.contains('sun');
    final isCloudy = normalized.contains('cloud');
    final showSun = isSunny || isCloudy;

    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: const Color(0xFFD8E3AE),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(120, 139, 195, 74),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (showSun)
                const Positioned(top: 1, left: 4, child: _SunWithRaysSmall()),
              Positioned(
                left: 6,
                right: 6,
                bottom: 8,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                left: 10,
                bottom: 11,
                child: _CloudBubble(size: 16),
              ),
              const Positioned(
                left: 20,
                bottom: 10,
                child: _CloudBubble(size: 19),
              ),
              const Positioned(
                left: 31,
                bottom: 12,
                child: _CloudBubble(size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SunWithRaysSmall extends StatelessWidget {
  const _SunWithRaysSmall();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(
        painter: _SunRaysSmallPainter(),
        child: Center(
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD530),
              boxShadow: [
                BoxShadow(
                  color: Colors.yellow.withOpacity(0.45),
                  blurRadius: 10,
                  spreadRadius: 1.2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SunRaysSmallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFFFD24A)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    const rayCount = 10;
    const innerRadius = 11.0;
    const outerRadius = 14.0;

    for (int i = 0; i < rayCount; i++) {
      final angle = (2 * math.pi / rayCount) * i;
      final start = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );
      final end = Offset(
        center.dx + math.cos(angle) * outerRadius,
        center.dy + math.sin(angle) * outerRadius,
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CloudBubble extends StatelessWidget {
  final double size;

  const _CloudBubble({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
