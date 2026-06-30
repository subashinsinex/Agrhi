import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../utils/routes.dart';
import '../../src/database/database_helper.dart';
import '../../src/services/language_service.dart';
import '../shared/smart_retranslator.dart';

class UpcomingNotificationCard extends StatefulWidget {
  final Color? backgroundColor;
  final int daysAhead;

  const UpcomingNotificationCard({
    super.key,
    this.backgroundColor,
    this.daysAhead = 365,
  });

  @override
  State<UpcomingNotificationCard> createState() =>
      _UpcomingNotificationCardState();
}

class _UpcomingNotificationCardState extends State<UpcomingNotificationCard>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  bool isRefreshing = false;

  List<Map<String, dynamic>> _reminders = [];
  int _currentIndex = 0;

  String _currentLanguage = '';
  Map<String, String> translatedTexts = {};

  final PageController _pageController = PageController(viewportFraction: 1);

  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  Color get _baseColor => widget.backgroundColor ?? AppColors.primaryGreen;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCardData();
    });
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final langService = Provider.of<LanguageService>(context);
    if (_currentLanguage != langService.currentLocale.languageCode) {
      _currentLanguage = langService.currentLocale.languageCode;
      _loadTranslations();
    }
  }

  Future<void> _loadTranslations() async {
    final langService = Provider.of<LanguageService>(context, listen: false);

    final keys = {
      'title': 'Harvest Day',
      'today': 'Today',
      'tomorrow': 'Tomorrow',
      'daysLeft': 'days left',
      'dayLeft': 'day left',
      'unknownCrop': 'Crop',
      'dueSoon': 'Due soon',
      'refreshing': 'Refreshing harvests...',
      'harvestDate': 'Harvest Date',
      'harvestToday': 'Ready today',
      'noHarvestTitle': 'No harvests lined up',
      'noHarvestSubtitle': 'Harvest-day crops will appear here.',
      'openCropCare': 'Open Crop Care',
      'viewAll': 'View all',
    };

    final Map<String, String> newTexts = {};
    for (final entry in keys.entries) {
      newTexts[entry.key] = await langService.translate(entry.value);
    }

    if (!mounted) return;
    setState(() {
      translatedTexts = newTexts;
    });
  }

  Future<void> _loadCardData({bool showRefresh = false}) async {
    if (!mounted) return;

    setState(() {
      if (_reminders.isEmpty) {
        isLoading = true;
      } else {
        isRefreshing = true;
      }
    });

    try {
      final db = DatabaseHelper.instance;
      final reminders = await db.getUpcomingReminders(
        daysAhead: widget.daysAhead,
      );

      final filtered = reminders.where((item) {
        final days = _extractDays(item);
        return days >= 0;
      }).toList();

      filtered.sort((a, b) => _extractDays(a).compareTo(_extractDays(b)));

      if (!mounted) return;

      setState(() {
        _reminders = filtered;
        _currentIndex = 0;
        isLoading = false;
        isRefreshing = false;
      });

      if (_pageController.hasClients && filtered.isNotEmpty) {
        _pageController.jumpToPage(0);
      }

      if (showRefresh && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              translatedTexts['refreshing'] ?? 'Refreshing harvests...',
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading harvest cards: $e');

      if (!mounted) return;
      setState(() {
        isLoading = false;
        isRefreshing = false;
        _reminders = [];
        _currentIndex = 0;
      });
    }
  }

  int _extractDays(Map<String, dynamic> reminder) {
    final dynamic days =
        reminder['daysuntilharvest'] ?? reminder['days_until_harvest'];

    if (days is int) return days;
    if (days is num) return days.toInt();
    if (days is String) return int.tryParse(days) ?? 9999;
    return 9999;
  }

  String _getPlantName(Map<String, dynamic> reminder) {
    final name =
        reminder['plantname']?.toString() ??
        reminder['plant_name']?.toString() ??
        '';
    return name.trim().isNotEmpty
        ? name
        : (translatedTexts['unknownCrop'] ?? 'Crop');
  }

  String _getHarvestDate(Map<String, dynamic> reminder) {
    final raw =
        reminder['harvestreminderdate']?.toString() ??
        reminder['harvest_reminder_date']?.toString() ??
        reminder['harvestdate']?.toString() ??
        reminder['harvest_date']?.toString();

    if (raw == null || raw.isEmpty) {
      return translatedTexts['dueSoon'] ?? 'Due soon';
    }

    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  String _getCountdownText(Map<String, dynamic> reminder) {
    final days = _extractDays(reminder);

    if (days <= 0) return translatedTexts['harvestToday'] ?? 'Ready today';
    if (days == 1) return '1 ${translatedTexts['dayLeft'] ?? 'day left'}';
    return '$days ${translatedTexts['daysLeft'] ?? 'days left'}';
  }

  IconData _getReminderIcon(Map<String, dynamic> reminder) {
    final days = _extractDays(reminder);

    if (days <= 0) return Icons.notifications_active_rounded;
    if (days == 1) return Icons.alarm_rounded;
    if (days <= 3) return Icons.event_available_rounded;
    return Icons.agriculture_rounded;
  }

  void _openCropCare(Map<String, dynamic> reminder) {
    final cropId =
        reminder['cropid']?.toString() ?? reminder['crop_id']?.toString();

    if (cropId == null || cropId.isEmpty) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      Routes.cropCare,
      ModalRoute.withName(Routes.dashboard),
      arguments: {'cropId': cropId, 'fromReminder': true},
    );
  }

  void _openCropCareList() {
    Navigator.pushNamed(context, Routes.cropCare);
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      height: 156,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _baseColor.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _baseColor.withOpacity(0.85),
                  _baseColor.withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return GestureDetector(
      onTap: _openCropCareList,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _baseColor.withOpacity(0.30),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _baseColor.withOpacity(0.85),
                    _baseColor.withOpacity(0.95),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: -40,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -30,
                    bottom: -30,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.agriculture_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SmartReTranslator(
                                text:
                                    translatedTexts['noHarvestTitle'] ??
                                    'No harvests lined up',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                  height: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              SmartReTranslator(
                                text:
                                    translatedTexts['noHarvestSubtitle'] ??
                                    'Harvest-day crops will appear here.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 14,
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

  Widget _buildCard(Map<String, dynamic> reminder, int index) {
    final plantName = _getPlantName(reminder);
    final countdownText = _getCountdownText(reminder);
    final harvestDate = _getHarvestDate(reminder);
    final icon = _getReminderIcon(reminder);

    return GestureDetector(
      onTap: () => _openCropCare(reminder),
      onLongPress: () => _loadCardData(showRefresh: true),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: _baseColor.withOpacity(0.30),
              blurRadius: 18,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _baseColor.withOpacity(0.85),
                    _baseColor.withOpacity(0.95),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.3,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -24,
                    top: -24,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -18,
                    bottom: -18,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        _pulseAnimation != null
                            ? ScaleTransition(
                                scale: _pulseAnimation!,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      icon,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    icon,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: SmartReTranslator(
                                      text: plantName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                        height: 1.0,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (isRefreshing)
                                    const SizedBox(
                                      width: 11,
                                      height: 11,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.7,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    Text(
                                      '${index + 1}/${_reminders.length}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white.withOpacity(0.78),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                countdownText,
                                style: TextStyle(
                                  fontSize: 11.8,
                                  color: Colors.white.withOpacity(0.95),
                                  fontWeight: FontWeight.w600,
                                  height: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.event_outlined,
                                    size: 11,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${translatedTexts['harvestDate'] ?? 'Harvest Date'} · $harvestDate',
                                      style: TextStyle(
                                        fontSize: 9.6,
                                        color: Colors.white.withOpacity(0.88),
                                        fontWeight: FontWeight.w500,
                                        height: 1.0,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 11,
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

  Widget _buildIndicator() {
    if (_reminders.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_reminders.length, (index) {
          final isActive = index == _currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 20 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: isActive ? _baseColor : _baseColor.withOpacity(0.20),
              borderRadius: BorderRadius.circular(20),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingCard();
    }

    if (_reminders.isEmpty) {
      return _buildEmptyCard();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 100,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _reminders.length,
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return _buildCard(_reminders[index], index);
            },
          ),
        ),
        _buildIndicator(),
      ],
    );
  }
}
