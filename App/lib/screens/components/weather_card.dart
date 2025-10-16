import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../src/services/weather_service.dart';
import '../../src/services/language_service.dart';

class WeatherCard extends StatefulWidget {
  final String location;
  final Color? backgroundColor;

  const WeatherCard({super.key, required this.location, this.backgroundColor});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  String? temperature;
  String? condition;
  String? wind;
  IconData weatherIcon = Icons.cloud;
  bool isLoading = true;

  Map<String, String> translatedTexts = {};
  String _currentLanguage = '';

  @override
  void initState() {
    super.initState();
    _loadTranslations().then((_) => _fetchWeather());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final langService = Provider.of<LanguageService>(context);
    if (_currentLanguage != langService.currentLocale.languageCode) {
      _currentLanguage = langService.currentLocale.languageCode;
      _loadTranslations().then((_) => _fetchWeather());
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
    };

    final Map<String, String> newTranslations = {};
    for (var entry in keys.entries) {
      newTranslations[entry.key] = await langService.translate(entry.value);
    }
    if (!mounted) return;
    setState(() {
      translatedTexts = newTranslations;
    });
  }

  Future<void> _fetchWeather({bool isRefresh = false}) async {
    if (isRefresh && !isLoading) {
      setState(() => isLoading = true);
    }

    if (isRefresh) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.refresh, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                translatedTexts['refreshing'] ?? 'Refreshing weather data...',
              ),
            ],
          ),
          backgroundColor: AppColors.infoColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      final weather = await WeatherService().getWeatherByPlace(widget.location);
      if (!mounted) return;

      final conditionStr = _translateCondition(weather.weatherCode);

      setState(() {
        temperature =
            "${weather.temperature.toStringAsFixed(1)}${translatedTexts['degreeCelsius'] ?? '°C'}";
        condition = conditionStr;
        wind =
            "${weather.windSpeed.toStringAsFixed(1)} ${translatedTexts['kmh'] ?? 'km/h'}";
        weatherIcon = _mapWeatherToIcon(weather.weatherCode);
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        temperature = "--";
        condition = translatedTexts['unavailable'] ?? 'Unavailable';
        wind = "--";
      });
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
        return Icons.foggy; // ensure this icon exists in your app
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _fetchWeather(isRefresh: true),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.backgroundColor != null
                ? [
                    widget.backgroundColor!.withOpacity(0.9),
                    widget.backgroundColor!,
                  ]
                : [
                    AppColors.primaryGreen.withOpacity(0.8),
                    AppColors.primaryGreen,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              _WeatherIcon(icon: weatherIcon),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.location,
                      style: const TextStyle(
                        fontSize: 20,
                        color: AppColors.primaryWhite,
                        fontWeight: FontWeight.w600,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      condition ?? "Loading...",
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primaryWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      wind ?? "",
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primaryWhite,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              isLoading
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryWhite,
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryWhite.withOpacity(0.2),
                      ),
                      child: Text(
                        temperature ?? "--",
                        style: const TextStyle(
                          fontSize: 20,
                          color: AppColors.primaryWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherIcon extends StatelessWidget {
  final IconData icon;
  const _WeatherIcon({required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.primaryWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: AppColors.primaryGreen, size: 28),
    );
  }
}
