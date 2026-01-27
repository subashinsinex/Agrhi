import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import '../shared/smart_retranslator.dart';
import '../shared/custom_app_bar.dart';
import '../../src/services/auth_service.dart';
import '../../src/services/api_service.dart';
import '../../src/services/language_service.dart';
import '../../src/database/database_helper.dart';

class Subsidy {
  final String id;
  final String title;
  final String description;
  final String link;
  final String stateName;

  Subsidy({
    required this.id,
    required this.title,
    required this.description,
    required this.link,
    required this.stateName,
  });

  factory Subsidy.fromJson(Map<String, dynamic> json) {
    return Subsidy(
      id: json['id']?.toString() ?? '0',
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      link: json['link'] ?? '',
      stateName: json['state_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'link': link,
      'state_name': stateName,
    };
  }
}

class SubsidyScreen extends StatefulWidget {
  const SubsidyScreen({super.key});

  @override
  State<SubsidyScreen> createState() => _SubsidyScreenState();
}

class _SubsidyScreenState extends State<SubsidyScreen> {
  List<Subsidy> _allSubsidies = [];
  List<Subsidy> _filteredSubsidies = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ✅ Translation cache for search
  final Map<String, String> _translatedTitles = {};
  final Map<String, String> _translatedStates = {};

  bool _hasError = false;
  bool _showScrollToTop = false;
  bool _isRetrying = false;
  bool _isRefreshing = false;
  bool _isInitialLoading = true;
  String _errorMessage = 'Please connect to the internet and try again.';

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterSubsidies);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 200 && !_showScrollToTop) {
      setState(() {
        _showScrollToTop = true;
      });
    } else if (_scrollController.offset <= 200 && _showScrollToTop) {
      setState(() {
        _showScrollToTop = false;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  /// ✅ Load data with cache-first strategy
  Future<void> _loadData() async {
    try {
      print('📦 Loading subsidies...');

      // ✅ 1. Load from cache first (instant display)
      final cachedSubsidies = await _loadFromCache();

      if (cachedSubsidies.isNotEmpty) {
        print('✅ Loaded ${cachedSubsidies.length} subsidies from cache');

        setState(() {
          _allSubsidies = cachedSubsidies;
          _filteredSubsidies = List.of(_allSubsidies);
          _hasError = false;
          _isInitialLoading = false;
        });

        // ✅ Preload translations
        _preloadTranslations();

        // ✅ 2. Fetch fresh data in background
        _refreshInBackground();
      } else {
        // ✅ 3. No cache - fetch from server
        print('⚠️ No cache found - fetching from server');
        await fetchSubsidies();

        setState(() {
          _isInitialLoading = false;
        });

        // ✅ Preload translations
        _preloadTranslations();
      }
    } catch (e) {
      print('❌ Error loading subsidies: $e');

      // Try to load from cache as fallback
      final cachedSubsidies = await _loadFromCache();
      if (cachedSubsidies.isNotEmpty) {
        setState(() {
          _allSubsidies = cachedSubsidies;
          _filteredSubsidies = List.of(_allSubsidies);
          _isInitialLoading = false;
        });
        _preloadTranslations();
      } else {
        setState(() {
          _hasError = true;
          _isInitialLoading = false;
        });
      }
    }
  }

  /// ✅ Preload all subsidy translations
  Future<void> _preloadTranslations() async {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    // Only translate if not English
    if (languageService.currentLocale.languageCode == 'en') {
      return;
    }

    print('🔄 Preloading ${_allSubsidies.length} subsidy translations...');

    // Clear existing translations
    _translatedTitles.clear();
    _translatedStates.clear();

    int count = 0;
    for (var subsidy in _allSubsidies) {
      // Translate title
      if (!_translatedTitles.containsKey(subsidy.title)) {
        try {
          final translated = await languageService.translate(subsidy.title);
          _translatedTitles[subsidy.title] = translated;
          count++;
        } catch (e) {
          debugPrint('Translation error for ${subsidy.title}: $e');
        }
      }

      // Translate state name
      if (!_translatedStates.containsKey(subsidy.stateName)) {
        try {
          final translated = await languageService.translate(subsidy.stateName);
          _translatedStates[subsidy.stateName] = translated;
          count++;
        } catch (e) {
          debugPrint('Translation error for ${subsidy.stateName}: $e');
        }
      }
    }

    print('✅ Preloaded $count translations');

    if (mounted) {
      setState(() {}); // Refresh UI with translations
    }
  }

  /// ✅ Load subsidies from local cache
  Future<List<Subsidy>> _loadFromCache() async {
    try {
      final cachedData = await _db.getCachedSubsidies();
      return cachedData.map((json) => Subsidy.fromJson(json)).toList();
    } catch (e) {
      print('⚠️ Error loading from cache: $e');
      return [];
    }
  }

  /// ✅ Save subsidies to local cache
  Future<void> _saveToCache(List<Subsidy> subsidies) async {
    try {
      await _db.cacheSubsidies(subsidies.map((s) => s.toJson()).toList());
      print('✅ Saved ${subsidies.length} subsidies to cache');
    } catch (e) {
      print('⚠️ Error saving to cache: $e');
    }
  }

  /// ✅ Refresh data in background without blocking UI
  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      print('🔄 Refreshing subsidies in background...');

      await fetchSubsidies();

      // Reload translations
      _preloadTranslations();

      print('✅ Background refresh completed');
    } catch (e) {
      print('⚠️ Background refresh failed (using cached data): $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  /// Intelligent retry with connectivity check and token refresh
  Future<void> _handleRetry() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
      _errorMessage = 'Checking connection...';
    });

    print('🔄 Retry initiated - checking internet connectivity...');

    setState(() {
      _errorMessage = 'Refreshing access token...';
    });

    try {
      print('🔄 Attempting to refresh access token...');
      await _authService.refreshAccessToken();
      print('✅ Access token refreshed successfully');

      setState(() {
        _hasError = false;
        _isRetrying = false;
        _errorMessage = 'Please connect to the internet and try again.';
      });

      print('🔄 Reloading subsidies...');
      await _loadData();
    } catch (e) {
      print('❌ Failed to refresh access token: $e');

      final errorMsg = e.toString();
      if (errorMsg.contains('expired') || errorMsg.contains('invalid')) {
        setState(() {
          _isRetrying = false;
          _errorMessage = 'Session expired. Please log in again.';
        });
      } else {
        setState(() {
          _isRetrying = false;
          _errorMessage = 'Server is unavailable. Please try again later.';
        });
      }
    }
  }

  Future<void> fetchSubsidies() async {
    try {
      print('🔄 Fetching subsidies from server...');

      final response = await ApiService.instance.get(
        '/subsidies/getSubsidy',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        _hasError = false;

        final dynamic data = response.data;

        List<dynamic> subsidyList;
        if (data is List) {
          subsidyList = data;
        } else if (data is Map && data['data'] != null) {
          subsidyList = data['data'] as List;
        } else {
          print('⚠️ Unexpected response format');
          subsidyList = [];
        }

        final subsidies = subsidyList
            .map((json) => Subsidy.fromJson(json))
            .toList();

        setState(() {
          _allSubsidies = subsidies;
          _filteredSubsidies = List.of(_allSubsidies);
        });

        // ✅ Save to cache
        await _saveToCache(subsidies);

        print('✅ Subsidies loaded successfully: ${subsidies.length} items');
      } else if (response.statusCode == 401) {
        _setError();
        print('❌ Unauthorized - access token may be invalid or expired');
        throw Exception('Session expired - please log in again');
      } else if (response.isOffline) {
        _setError();
        throw Exception('No internet connection');
      } else {
        _setError();
        throw Exception(
          response.error ?? 'Failed to load subsidies: ${response.statusCode}',
        );
      }
    } catch (e) {
      _setError();
      print('❌ Error fetching subsidies: $e');
      rethrow;
    }
  }

  void _setError() {
    setState(() {
      _hasError = true;
    });
  }

  // ✅ Multilingual filter with translation support
  void _filterSubsidies() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredSubsidies = List.of(_allSubsidies);
      } else {
        _filteredSubsidies = _allSubsidies.where((s) {
          // Original English text
          final title = s.title.toLowerCase();
          final state = s.stateName.toLowerCase();

          // Translated text
          final translatedTitle = (_translatedTitles[s.title] ?? '')
              .toLowerCase();
          final translatedState = (_translatedStates[s.stateName] ?? '')
              .toLowerCase();

          // Search in both English and translated text
          return title.contains(query) ||
              state.contains(query) ||
              translatedTitle.contains(query) ||
              translatedState.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: CustomAppBar(
        title: 'Subsidy',
        showOnlineStatus: true,
        actions: [
          // ✅ Show refresh indicator when background refresh is active
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _hasError && _allSubsidies.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isRetrying ? Icons.refresh : Icons.wifi_off,
                    size: 80,
                    color: _isRetrying ? AppColors.primaryGreen : Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SmartReTranslator(
                      text: _errorMessage,
                      style: TextStyle(
                        color: _isRetrying
                            ? AppColors.primaryGreen
                            : Colors.grey,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: _isRetrying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: SmartReTranslator(
                      text: _isRetrying ? 'Retrying...' : 'Retry',
                      style: const TextStyle(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: _isRetrying ? null : _handleRetry,
                  ),
                ],
              ),
            )
          : _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : _allSubsidies.isEmpty
          ? const Center(
              child: SmartReTranslator(
                text: 'No subsidies found',
                style: TextStyle(),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshInBackground,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SmartReTranslator(
                            text: 'Search by title or state',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // ✅ Use ListenableBuilder for proper rebuild
                          ListenableBuilder(
                            listenable: _searchController,
                            builder: (context, _) {
                              return TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: AppColors.primaryGreen,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            color: Colors.grey,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                          },
                                        )
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                    horizontal: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  _filteredSubsidies.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                SmartReTranslator(
                                  text: 'No subsidies found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SmartReTranslator(
                                  text: 'Try searching with different keywords',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final subsidy = _filteredSubsidies[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 4,
                              ),
                              child: Card(
                                key: ValueKey(subsidy.id),
                                color: Colors.white,
                                elevation: 3,
                                shadowColor: AppColors.primaryGreen.withOpacity(
                                  0.13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  title: SmartReTranslator(
                                    text: subsidy.title,
                                    style: const TextStyle(
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: SmartReTranslator(
                                    text: subsidy.stateName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            SubsidyDetailScreen(
                                              subsidy: subsidy,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }, childCount: _filteredSubsidies.length),
                        ),
                ],
              ),
            ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: AppColors.primaryGreen,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            )
          : null,
    );
  }
}

// SubsidyDetailScreen remains the same...
class SubsidyDetailScreen extends StatelessWidget {
  final Subsidy subsidy;
  const SubsidyDetailScreen({super.key, required this.subsidy});

  Future<void> _launchURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.open_in_browser,
                  color: AppColors.primaryGreen,
                  size: 28,
                ),
                SizedBox(width: 12),
                SmartReTranslator(
                  text: 'Open Link',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: const SmartReTranslator(
              text: 'Do you want to open the link in your browser?',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const SmartReTranslator(
                  text: 'Cancel',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const SmartReTranslator(
                  text: 'Open',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
            actionsPadding: const EdgeInsets.only(
              right: 16,
              bottom: 16,
              left: 16,
            ),
          ),
        ) ??
        false;

    if (confirmed) {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const SmartReTranslator(
                text: 'Could not open the link',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final descriptionText = subsidy.description.replaceAll(r'\n', '\n');

    return Scaffold(
      appBar: CustomAppBar(
        title: subsidy.title,
        showOnlineStatus: true,
      ),
      backgroundColor: AppColors.backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Material(
                        color: Colors.white,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: SmartReTranslator(
                            text: descriptionText,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: SmartReTranslator(
                          text: subsidy.stateName,
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (subsidy.link.isNotEmpty)
                        Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 19),
                            label: const SmartReTranslator(
                              text: 'More Info',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                              elevation: 8,
                            ),
                            onPressed: () => _launchURL(context, subsidy.link),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
