import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../src/database/database_helper.dart';
import '../../../../src/services/language_service.dart';
import '../../../../utils/routes.dart';
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

class _UpcomingNotificationCardState extends State<UpcomingNotificationCard> {
  final PageController _pageController = PageController();

  bool isLoading = true;
  bool isRefreshing = false;

  List<Map<String, dynamic>> reminders = [];
  int currentIndex = 0;
  String currentLanguage = '';
  Map<String, String> translatedTexts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadTranslations();
      await loadCardData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final langService = Provider.of<LanguageService>(context);
    final newLanguage = langService.currentLocale.languageCode;

    if (currentLanguage != newLanguage) {
      currentLanguage = newLanguage;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await loadTranslations();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> loadTranslations() async {
    final langService = Provider.of<LanguageService>(context, listen: false);

    const keys = {
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
    setState(() => translatedTexts = newTexts);
  }

  Future<void> loadCardData({bool showRefresh = false}) async {
    if (!mounted) return;

    setState(() {
      if (reminders.isEmpty) {
        isLoading = true;
      } else {
        isRefreshing = true;
      }
    });

    try {
      final db = DatabaseHelper.instance;
      final data = await db.getUpcomingReminders(daysAhead: widget.daysAhead);

      final filtered = data.where((item) {
        final days = extractDays(item);
        return days >= 0;
      }).toList()..sort((a, b) => extractDays(a).compareTo(extractDays(b)));

      if (!mounted) return;

      setState(() {
        reminders = filtered;
        currentIndex = 0;
        isLoading = false;
        isRefreshing = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients || reminders.isEmpty){return;}
        _pageController.jumpToPage(0);
      });

      if (showRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              translatedTexts['refreshing'] ?? 'Refreshing harvests...',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading harvest cards: $e');

      if (!mounted) return;
      setState(() {
        isLoading = false;
        isRefreshing = false;
        reminders = [];
        currentIndex = 0;
      });
    }
  }

  int extractDays(Map<String, dynamic> reminder) {
    final dynamic days =
        reminder['daysuntilharvest'] ?? reminder['days_until_harvest'];

    if (days is int) return days;
    if (days is num) return days.toInt();
    if (days is String) return int.tryParse(days) ?? 9999;
    return 9999;
  }

  String getPlantName(Map<String, dynamic> reminder) {
    final name =
        reminder['plantname']?.toString() ??
        reminder['plant_name']?.toString() ??
        '';

    return name.trim().isNotEmpty
        ? name
        : (translatedTexts['unknownCrop'] ?? 'Crop');
  }

  String getHarvestDate(Map<String, dynamic> reminder) {
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

  String getCountdownText(Map<String, dynamic> reminder) {
    final days = extractDays(reminder);

    if (days == 0) return translatedTexts['harvestToday'] ?? 'Ready today';
    if (days == 1) return '1 ${translatedTexts['dayLeft'] ?? 'day left'}';
    return '$days ${translatedTexts['daysLeft'] ?? 'days left'}';
  }

  void openCropCare(Map<String, dynamic> reminder) {
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

  void openCropCareList() {
    Navigator.pushNamed(context, Routes.cropCare);
  }

  void showNextReminder() {
    if (reminders.length <= 1) return;
    if (!_pageController.hasClients) return;

    final nextIndex = (currentIndex + 1) % reminders.length;
    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return buildLoadingCard();
    if (reminders.isEmpty) return buildEmptyCard();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF082E1B),
            const Color(0xFF005A2B),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF005A2B).withOpacity(0.15),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 112,
            child: PageView.builder(
              controller: _pageController,
              itemCount: reminders.length,
              physics: reminders.length > 1
                  ? const BouncingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                if (!mounted) return;
                setState(() => currentIndex = index);
              },
              itemBuilder: (context, index) {
                final reminder = reminders[index];
                final plantName = getPlantName(reminder);
                final countdown = getCountdownText(reminder);
                final harvestDate = getHarvestDate(reminder);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => openCropCare(reminder),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
                      child: Row(
                        children: [
                          _buildCropIcon(),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SmartReTranslator(
                                  text: plantName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  countdown,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${translatedTexts['harvestDate'] ?? 'Harvest Date'} • $harvestDate',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.95),
                                          fontSize: 12.2,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${index + 1}/${reminders.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Material(
                                color: Colors.white.withOpacity(0.06),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: showNextReminder,
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.20),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (reminders.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                reminders.length > 5 ? 5 : reminders.length,
                (index) {
                  final active = index == currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: active ? 8 : 6,
                    height: active ? 8 : 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? const Color(0xFFB7D36E)
                          : Colors.white.withOpacity(0.35),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (isRefreshing)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCropIcon() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF9EB955), width: 4),
        gradient: const LinearGradient(
          colors: [Color(0x553E5A12), Color(0x221B2A08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.eco_rounded, color: Colors.white, size: 34),
      ),
    );
  }

  Widget buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A331D), Color(0xFF005A2D)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget buildEmptyCard() {
    return GestureDetector(
      onTap: openCropCareList,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A331D), Color(0xFF005A2D)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.15),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              _buildCropIcon(),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SmartReTranslator(
                      text:
                          translatedTexts['noHarvestTitle'] ??
                          'No harvests lined up',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
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
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
