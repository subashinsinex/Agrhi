import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colors.dart';
import '../../src/services/weather_service.dart';
import '../../src/services/language_service.dart';

class WeatherCard extends StatefulWidget {
  final String? location;
  final bool useDeviceLocation;
  final Color? backgroundColor;

  const WeatherCard({
    super.key,
    this.location,
    this.useDeviceLocation = false,
    this.backgroundColor,
  });

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard>
    with SingleTickerProviderStateMixin {
  String? temperature;
  String? condition;
  String? wind;
  String? displayLocation;
  String? originalLocationName;
  IconData weatherIcon = Icons.cloud;
  bool isLoading = true;
  bool isSyncing = false;
  DateTime? lastSyncTime;

  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  Map<String, String> translatedTexts = {};
  String _currentLanguage = '';

  static const String _cacheKeyPrefix = 'weather_cache_';
  static const String _lastSyncPrefix = 'weather_last_sync_';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedDataThenSync();
    });
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final langService = Provider.of<LanguageService>(context);
    if (_currentLanguage != langService.currentLocale.languageCode) {
      _currentLanguage = langService.currentLocale.languageCode;
      _loadTranslationsAndRefreshDisplay();
    }
  }

  Future<void> _loadCachedDataThenSync() async {
    await _loadTranslations();
    final cachedData = await _loadCachedWeather();
    if (cachedData != null) {
      debugPrint('✅ Loaded cached weather data');
      _displayWeatherData(cachedData, fromCache: true);
    }
    await _fetchWeatherSilently();
  }

  Future<Map<String, dynamic>?> _loadCachedWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      final cachedJson = prefs.getString(cacheKey);

      if (cachedJson != null) {
        final cachedData = jsonDecode(cachedJson) as Map<String, dynamic>;
        final lastSyncStr = prefs.getString('$_lastSyncPrefix$cacheKey');
        if (lastSyncStr != null) {
          lastSyncTime = DateTime.parse(lastSyncStr);
        }
        return cachedData;
      }
    } catch (e) {
      debugPrint('❌ Error loading cached weather: $e');
    }
    return null;
  }

  Future<void> _saveWeatherToCache(Map<String, dynamic> weatherData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();
      await prefs.setString(cacheKey, jsonEncode(weatherData));
      await prefs.setString(
        '$_lastSyncPrefix$cacheKey',
        DateTime.now().toIso8601String(),
      );
      debugPrint('✅ Weather data cached successfully');
    } catch (e) {
      debugPrint('❌ Error caching weather data: $e');
    }
  }

  String _getCacheKey() {
    if (widget.useDeviceLocation) {
      return '${_cacheKeyPrefix}current_location';
    } else if (widget.location != null) {
      return '$_cacheKeyPrefix${widget.location}';
    }
    return '${_cacheKeyPrefix}default';
  }

  void _displayWeatherData(
    Map<String, dynamic> data, {
    bool fromCache = false,
  }) {
    if (!mounted) return;

    final langService = Provider.of<LanguageService>(context, listen: false);

    setState(() {
      originalLocationName = data['locationName'];
      temperature =
          "${data['temperature']}${translatedTexts['degreeCelsius'] ?? '°C'}";
      condition = _translateCondition(data['weatherCode']);
      wind = "${data['windSpeed']} km/h";
      weatherIcon = _mapWeatherToIcon(data['weatherCode']);

      if (fromCache) {
        isLoading = false;
      } else {
        isLoading = false;
        isSyncing = false;
        lastSyncTime = DateTime.now();
      }
    });

    if (originalLocationName != null) {
      langService.translate(originalLocationName!).then((translated) {
        if (mounted) {
          setState(() {
            displayLocation = translated;
          });
        }
      });
    }
  }

  Future<void> _fetchWeatherSilently() async {
    if (!mounted) return;
    setState(() => isSyncing = true);

    try {
      Weather weather;

      if (widget.useDeviceLocation) {
        weather = await WeatherService().getWeatherByCurrentLocation();
      } else if (widget.location != null) {
        weather = await WeatherService().getWeatherByPlace(widget.location!);
      } else {
        throw Exception('No location provided');
      }

      final weatherData = {
        'locationName': weather.locationName,
        'temperature': weather.temperature.toStringAsFixed(1),
        'weatherCode': weather.weatherCode,
        'windSpeed': weather.windSpeed.toStringAsFixed(1),
      };

      await _saveWeatherToCache(weatherData);
      _displayWeatherData(weatherData, fromCache: false);
    } catch (e) {
      debugPrint('❌ Error fetching weather silently: $e');

      if (!mounted) return;
      setState(() {
        isSyncing = false;
        if (temperature == null) {
          displayLocation =
              translatedTexts['locationError'] ?? 'Location unavailable';
          temperature = "--";
          condition = translatedTexts['unavailable'] ?? 'Unavailable';
          wind = "--";
          isLoading = false;
        }
      });
    }
  }

  Future<void> _loadTranslations() async {
    final langService = Provider.of<LanguageService>(context, listen: false);
    final keys = {
      'refreshing': 'Refreshing weather data...',
      'unavailable': 'Unavailable',
      'kmh': 'km/h',
      'degreeCelsius': '°C',
      'clear': 'Clear',
      'partlyCloudy': 'Partly Cloudy',
      'fog': 'Fog',
      'rain': 'Rain',
      'snow': 'Snow',
      'thunderstorm': 'Thunderstorm',
      'unknown': 'Unknown',
      'currentLocation': 'Current Location',
      'locationError': 'Location unavailable',
      'loading': 'Loading...',
      'lastSync': 'Updated',
      'syncing': 'Syncing...',
      'justNow': 'Just now',
      'minutesAgo': 'm',
      'hoursAgo': 'h',
      'wind': 'Wind',
    };

    final Map<String, String> newTranslations = {};
    for (var entry in keys.entries) {
      newTranslations[entry.key] = await langService.translate(entry.value);
    }

    if (originalLocationName != null && originalLocationName!.isNotEmpty) {
      newTranslations['locationName'] = await langService.translate(
        originalLocationName!,
      );
    }

    if (!mounted) return;
    setState(() {
      translatedTexts = newTranslations;
      if (originalLocationName != null &&
          newTranslations['locationName'] != null) {
        displayLocation = newTranslations['locationName'];
      }
    });
  }

  Future<void> _loadTranslationsAndRefreshDisplay() async {
    await _loadTranslations();
    if (mounted && temperature != null) {
      setState(() {});
    }
  }

  Future<void> _fetchWeather({bool isRefresh = false}) async {
    if (isRefresh) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.refresh, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  translatedTexts['refreshing'] ?? 'Refreshing weather data...',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await _fetchWeatherSilently();
    }
  }

  String _translateCondition(int code) {
    switch (code) {
      case 0:
        return translatedTexts['clear'] ?? 'Clear';
      case 1:
      case 2:
      case 3:
        return translatedTexts['partlyCloudy'] ?? 'Partly Cloudy';
      case 45:
      case 48:
        return translatedTexts['fog'] ?? 'Fog';
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return translatedTexts['rain'] ?? 'Rain';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return translatedTexts['snow'] ?? 'Snow';
      case 95:
      case 96:
      case 99:
        return translatedTexts['thunderstorm'] ?? 'Thunderstorm';
      default:
        return translatedTexts['unknown'] ?? 'Unknown';
    }
  }

  IconData _mapWeatherToIcon(int code) {
    switch (code) {
      case 0:
        return Icons.wb_sunny_rounded;
      case 1:
      case 2:
      case 3:
        return Icons.cloud_rounded;
      case 45:
      case 48:
        return Icons.foggy;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return Icons.beach_access_rounded;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return Icons.ac_unit_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.flash_on_rounded;
      default:
        return Icons.wb_cloudy_rounded;
    }
  }

  String _getLastSyncText() {
    if (lastSyncTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(lastSyncTime!);

    if (difference.inMinutes < 1) {
      return translatedTexts['justNow'] ?? 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}${translatedTexts['minutesAgo'] ?? 'm'}';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}${translatedTexts['hoursAgo'] ?? 'h'}';
    } else {
      return '${difference.inDays}d';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _fetchWeather(isRefresh: true),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (widget.backgroundColor ?? AppColors.primaryGreen)
                  .withOpacity(0.25),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.backgroundColor != null
                      ? [
                          widget.backgroundColor!.withOpacity(0.85),
                          widget.backgroundColor!.withOpacity(0.95),
                        ]
                      : [
                          AppColors.primaryGreen.withOpacity(0.85),
                          AppColors.primaryGreen.withOpacity(0.95),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  // Decorative circles - smaller and repositioned
                  Positioned(
                    right: -25,
                    top: -25,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -15,
                    bottom: -30,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                  ),

                  // Main content - reduced padding
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Weather icon with animation - made smaller
                        if (!isLoading && _pulseAnimation != null)
                          ScaleTransition(
                            scale: _pulseAnimation!,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                weatherIcon,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else if (!isLoading)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              weatherIcon,
                              size: 48,
                              color: Colors.white,
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),

                        const SizedBox(width: 16),

                        // Weather details - more compact
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Location with icon
                              Row(
                                children: [
                                  if (widget.useDeviceLocation) ...[
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      displayLocation ??
                                          widget.location ??
                                          translatedTexts['loading'] ??
                                          'Loading...',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              // Temperature & Condition in one line
                              Row(
                                children: [
                                  Text(
                                    temperature ?? "--",
                                    style: const TextStyle(
                                      fontSize: 36,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w300,
                                      height: 1,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        condition ??
                                            translatedTexts['loading'] ??
                                            'Loading...',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Wind & Last Sync in one row
                              Row(
                                children: [
                                  // Wind
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.air,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    wind ?? '--',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),

                                  // Spacer
                                  const SizedBox(width: 12),

                                  // Last sync
                                  if (lastSyncTime != null) ...[
                                    Icon(
                                      isSyncing
                                          ? Icons.sync
                                          : Icons.check_circle,
                                      size: 10,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        isSyncing
                                            ? translatedTexts['syncing'] ??
                                                  'Syncing...'
                                            : _getLastSyncText(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white.withOpacity(0.7),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Compact refresh indicator
                        const SizedBox(width: 8),
                        if (isSyncing)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.refresh,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
