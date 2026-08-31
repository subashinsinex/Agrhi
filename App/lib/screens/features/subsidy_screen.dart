import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/colors.dart';
import '../shared/smart_retranslator.dart';
import '../shared/custom_app_bar.dart';
import '../shared/disclaimer_banner.dart';
import '../../src/services/auth_service.dart';
import '../../src/services/api_service.dart';
import '../../src/services/language_service.dart';
import '../../src/database/database_helper.dart';

import '../../utils/page_transitions.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();
  final DatabaseHelper _db = DatabaseHelper.instance;

  final Map<String, String> _translatedTitles = {};
  final Map<String, String> _translatedStates = {};

  List<Subsidy> _allSubsidies = [];
  List<Subsidy> _filteredSubsidies = [];

  bool _hasError = false;
  bool _showScrollToTop = false;
  bool _isRetrying = false;
  bool _isRefreshing = false;
  bool _isInitialLoading = true;

  String _errorMessage = 'Please connect to the internet and try again.';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > 240;
    if (shouldShow != _showScrollToTop) {
      setState(() {
        _showScrollToTop = shouldShow;
      });
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 180),
      _filterSubsidies,
    );
    setState(() {});
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadData() async {
    try {
      final cachedSubsidies = await _loadFromCache();

      if (cachedSubsidies.isNotEmpty) {
        setState(() {
          _allSubsidies = cachedSubsidies;
          _filteredSubsidies = List.of(cachedSubsidies);
          _hasError = false;
          _isInitialLoading = false;
        });

        _preloadTranslations();
        _refreshInBackground();
      } else {
        await fetchSubsidies();
        if (mounted) {
          setState(() {
            _isInitialLoading = false;
          });
        }
        _preloadTranslations();
      }
    } catch (_) {
      final cachedSubsidies = await _loadFromCache();

      if (cachedSubsidies.isNotEmpty) {
        setState(() {
          _allSubsidies = cachedSubsidies;
          _filteredSubsidies = List.of(cachedSubsidies);
          _hasError = false;
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

  Future<void> _preloadTranslations() async {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    if (languageService.currentLocale.languageCode == 'en') return;

    _translatedTitles.clear();
    _translatedStates.clear();

    for (final subsidy in _allSubsidies) {
      if (!_translatedTitles.containsKey(subsidy.title)) {
        try {
          final translated = await languageService.translate(subsidy.title);
          _translatedTitles[subsidy.title] = translated;
        } catch (_) {}
      }

      if (!_translatedStates.containsKey(subsidy.stateName)) {
        try {
          final translated = await languageService.translate(subsidy.stateName);
          _translatedStates[subsidy.stateName] = translated;
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<List<Subsidy>> _loadFromCache() async {
    try {
      final cachedData = await _db.getCachedSubsidies();
      return cachedData.map((json) => Subsidy.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveToCache(List<Subsidy> subsidies) async {
    try {
      await _db.cacheSubsidies(subsidies.map((s) => s.toJson()).toList());
    } catch (_) {}
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await fetchSubsidies();
      _preloadTranslations();
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _handleRetry() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
      _errorMessage = 'Refreshing access token...';
    });

    try {
      await _authService.refreshAccessToken();

      if (mounted) {
        setState(() {
          _hasError = false;
          _isRetrying = false;
          _errorMessage = 'Please connect to the internet and try again.';
        });
      }

      await _loadData();
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      setState(() {
        _isRetrying = false;
        _errorMessage =
            errorMsg.contains('expired') || errorMsg.contains('invalid')
            ? 'Session expired. Please log in again.'
            : 'Server is unavailable. Please try again later.';
      });
    }
  }

  Future<void> fetchSubsidies() async {
    try {
      final response = await ApiService.instance.get(
        '/subsidies/getSubsidy',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final dynamic data = response.data;

        List<dynamic> subsidyList;
        if (data is List) {
          subsidyList = data;
        } else if (data is Map && data['data'] != null) {
          subsidyList = data['data'] as List;
        } else {
          subsidyList = [];
        }

        final subsidies = subsidyList
            .map((json) => Subsidy.fromJson(json))
            .toList();

        setState(() {
          _allSubsidies = subsidies;
          _filteredSubsidies = _applyFilter(_searchController.text, subsidies);
          _hasError = false;
        });

        await _saveToCache(subsidies);
      } else if (response.statusCode == 401) {
        _setError();
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
    } catch (_) {
      _setError();
      rethrow;
    }
  }

  void _setError() {
    if (!mounted) return;
    setState(() {
      _hasError = true;
    });
  }

  void _filterSubsidies() {
    final query = _searchController.text;
    if (!mounted) return;

    setState(() {
      _filteredSubsidies = _applyFilter(query, _allSubsidies);
    });
  }

  List<Subsidy> _applyFilter(String query, List<Subsidy> subsidies) {
    final q = query.toLowerCase().trim();

    if (q.isEmpty) return List.of(subsidies);

    return subsidies.where((s) {
      final title = s.title.toLowerCase();
      final state = s.stateName.toLowerCase();
      final description = s.description.toLowerCase();
      final translatedTitle = (_translatedTitles[s.title] ?? '').toLowerCase();
      final translatedState = (_translatedStates[s.stateName] ?? '')
          .toLowerCase();

      return title.contains(q) ||
          state.contains(q) ||
          description.contains(q) ||
          translatedTitle.contains(q) ||
          translatedState.contains(q);
    }).toList();
  }

  void _openDetails(Subsidy subsidy) {
    Navigator.push(
      context,
      smoothPageRoute(SubsidyDetailScreen(subsidy: subsidy)),
    );
  }

  String _shortDescription(String text) {
    final cleaned = text
        .replaceAll(r'\n', ' ')
        .replaceAll('\\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return '';
    if (cleaned.length <= 140) return cleaned;
    return '${cleaned.substring(0, 140).trim()}...';
  }

  Widget _buildBody() {
    if (_isInitialLoading && _allSubsidies.isEmpty) {
      return const SubsidyLoadingView();
    }

    if (_hasError && _allSubsidies.isEmpty) {
      return SubsidyErrorView(
        message: _errorMessage,
        isRetrying: _isRetrying,
        onRetry: _handleRetry,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshInBackground,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SubsidySearchSection(
                controller: _searchController,
                totalCount: _allSubsidies.length,
                filteredCount: _filteredSubsidies.length,
              ),
            ),
          ),
          if (_filteredSubsidies.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: SubsidyEmptyView(
                hasQuery: _searchController.text.trim().isNotEmpty,
                onClear: () => _searchController.clear(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.builder(
                itemCount: _filteredSubsidies.length,
                itemBuilder: (context, index) {
                  final subsidy = _filteredSubsidies[index];
                  return SubsidyCard(
                    subsidy: subsidy,
                    descriptionPreview: _shortDescription(subsidy.description),
                    onTap: () => _openDetails(subsidy),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: 'Subsidy',
        showOnlineStatus: true,
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: AppColors.primaryGreen,
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}

class SubsidySearchSection extends StatelessWidget {
  final TextEditingController controller;
  final int totalCount;
  final int filteredCount;

  const SubsidySearchSection({
    super.key,
    required this.controller,
    required this.totalCount,
    required this.filteredCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasQuery = controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SmartReTranslator(
            text: 'Search by title, description, or state',
            style: TextStyle(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by title or state',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.primaryGreen,
              ),
              suffixIcon: hasQuery
                  ? IconButton(
                      onPressed: controller.clear,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF7F8F7),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primaryGreen,
                  width: 1.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.account_balance_wallet_rounded,
                label: '$filteredCount shown',
              ),
              _InfoChip(
                icon: Icons.dataset_rounded,
                label: '$totalCount total',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class SubsidyCard extends StatelessWidget {
  final Subsidy subsidy;
  final String descriptionPreview;
  final VoidCallback onTap;

  const SubsidyCard({
    super.key,
    required this.subsidy,
    required this.descriptionPreview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDescription = descriptionPreview.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withOpacity(0.96),
        elevation: 1.5,
        shadowColor: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SmartReTranslator(
                        text: subsidy.title,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SmartReTranslator(
                  text: hasDescription
                      ? descriptionPreview
                      : 'No description available.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: hasDescription
                        ? AppColors.textSecondary
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: SmartReTranslator(
                              text: subsidy.stateName.isNotEmpty
                                  ? subsidy.stateName
                                  : 'Unknown state',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ),
                          if (subsidy.link.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Official link',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                            color: AppColors.primaryGreen,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'View',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SubsidyLoadingView extends StatelessWidget {
  const SubsidyLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: const [
        _LoadingSearchCard(),
        SizedBox(height: 14),
        _LoadingSubsidyCard(),
        _LoadingSubsidyCard(),
        _LoadingSubsidyCard(),
        _LoadingSubsidyCard(),
      ],
    );
  }
}

class _LoadingSearchCard extends StatelessWidget {
  const _LoadingSearchCard();

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(height: 150, borderRadius: BorderRadius.circular(20));
  }
}

class _LoadingSubsidyCard extends StatelessWidget {
  const _LoadingSubsidyCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _ShimmerBox(height: 150, borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double height;
  final BorderRadius borderRadius;

  const _ShimmerBox({required this.height, required this.borderRadius});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1 + (2 * _controller.value), 0),
              end: Alignment(1 + (2 * _controller.value), 0),
              colors: const [
                Color(0xFFECECEC),
                Color(0xFFF7F7F7),
                Color(0xFFECECEC),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SubsidyErrorView extends StatelessWidget {
  final String message;
  final bool isRetrying;
  final VoidCallback onRetry;

  const SubsidyErrorView({
    super.key,
    required this.message,
    required this.isRetrying,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRetrying ? Icons.refresh_rounded : Icons.wifi_off_rounded,
                size: 72,
                color: isRetrying ? AppColors.primaryGreen : Colors.grey,
              ),
              const SizedBox(height: 16),
              const SmartReTranslator(
                text: 'Unable to load subsidies',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              SmartReTranslator(
                text: message,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isRetrying ? null : onRetry,
                  icon: isRetrying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: SmartReTranslator(
                    text: isRetrying ? 'Retrying...' : 'Retry',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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

class SubsidyEmptyView extends StatelessWidget {
  final bool hasQuery;
  final VoidCallback? onClear;

  const SubsidyEmptyView({super.key, this.hasQuery = false, this.onClear});

  @override
  Widget build(BuildContext context) {
    final title = hasQuery
        ? 'No matching subsidies found'
        : 'No subsidies found';
    final subtitle = hasQuery
        ? 'Try searching with a different title, description, or state name.'
        : 'Subsidies will appear here when data becomes available.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasQuery ? Icons.search_off_rounded : Icons.inbox_outlined,
                  size: 40,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 18),
              SmartReTranslator(
                text: title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              SmartReTranslator(
                text: subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (hasQuery && onClear != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                  label: const SmartReTranslator(
                    text: 'Clear search',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SubsidyDetailScreen extends StatelessWidget {
  final Subsidy subsidy;

  const SubsidyDetailScreen({super.key, required this.subsidy});

  Future<void> _launchURL(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const SmartReTranslator(
            text: 'Invalid link',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    final confirmed =
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
                  Icons.open_in_browser_rounded,
                  color: AppColors.primaryGreen,
                  size: 26,
                ),
                SizedBox(width: 10),
                SmartReTranslator(
                  text: 'Open Link',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: const SmartReTranslator(
              text: 'Do you want to open the link in your browser?',
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const SmartReTranslator(
                  text: 'Cancel',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const SmartReTranslator(
                  text: 'Open',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
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

  String _extractHost(String url) {
    final uri = Uri.tryParse(url);
    return uri?.host.isNotEmpty == true ? uri!.host : url;
  }

  @override
  Widget build(BuildContext context) {
    final descriptionText = subsidy.description.replaceAll(r'\n', '\n');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(title: subsidy.title, showOnlineStatus: true),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailHeader(subsidy: subsidy),
                    const SizedBox(height: 16),
                    _DetailSectionCard(
                      title: 'Description',
                      child: SmartReTranslator(
                        text: descriptionText.isEmpty
                            ? 'No description available.'
                            : descriptionText,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.65,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (subsidy.link.isNotEmpty)
                      _DetailSectionCard(
                        title: 'Reference link',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.link_rounded,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _extractHost(subsidy.link),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    DisclaimerBanner(
                      'Subsidy information is for reference only. Eligibility and availability are governed by government authorities. \'More Info\' links redirect to official external websites.',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            if (subsidy.link.isNotEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchURL(context, subsidy.link),
                      icon: const Icon(Icons.open_in_new_rounded, size: 20),
                      label: const SmartReTranslator(
                        text: 'More Info',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final Subsidy subsidy;

  const _DetailHeader({required this.subsidy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withOpacity(0.95),
            AppColors.primaryGreen.withOpacity(0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartReTranslator(
            text: subsidy.title,
            style: const TextStyle(
              fontSize: 22,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: SmartReTranslator(
              text: subsidy.stateName,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartReTranslator(
            text: title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
