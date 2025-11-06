// lib/src/screens/features/subsidy_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import '../../utils/storage_helper.dart';
import '../../src/services/language_service.dart';
import '../../src/services/auth_service.dart';
import '../../src/services/connectivity_service.dart';
import '../../utils/constants.dart';

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
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      link: json['link'] ?? '',
      stateName: json['state_name'] ?? '',
    );
  }
}

// Smart widget for translation that uses cache then re-translates once cache is ready
class SmartReTranslator extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const SmartReTranslator({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
  });

  @override
  _SmartReTranslatorState createState() => _SmartReTranslatorState();
}

class _SmartReTranslatorState extends State<SmartReTranslator> {
  late LanguageService languageService;
  String displayedText = '';
  bool _cacheLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    languageService = Provider.of<LanguageService>(context);

    _getInitialTranslation();

    if (!languageService.isInitialized) {
      languageService.addListener(() {
        if (languageService.isInitialized && !_cacheLoaded) {
          _cacheLoaded = true;
          _refreshTranslation();
        }
      });
    } else {
      _cacheLoaded = true;
      _refreshTranslation();
    }
  }

  void _getInitialTranslation() async {
    final cacheKey = languageService.currentLocale.languageCode;
    final cached = languageService.translationCache[cacheKey]?[widget.text];
    if (mounted) {
      setState(() {
        displayedText = cached ?? widget.text;
      });
    }
  }

  void _refreshTranslation() async {
    final translation = await languageService.translate(widget.text);
    if (mounted) {
      setState(() {
        displayedText = translation;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      displayedText.isEmpty ? widget.text : displayedText,
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }
}

class SubsidyScreen extends StatefulWidget {
  const SubsidyScreen({super.key});

  @override
  State<SubsidyScreen> createState() => _SubsidyScreenState();
}

class _SubsidyScreenState extends State<SubsidyScreen> {
  late Future<List<Subsidy>> _futureSubsidies;
  List<Subsidy> _allSubsidies = [];
  List<Subsidy> _filteredSubsidies = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final StorageHelper _storage = StorageHelper();
  final AuthService _authService = AuthService();
  final ConnectivityService _connectivityService = ConnectivityService();

  bool _hasError = false;
  bool _showScrollToTop = false;
  bool _isRetrying = false;
  String _errorMessage = 'Please connect to the internet and try again.';

  @override
  void initState() {
    super.initState();
    _fetchData();
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

  void _fetchData() {
    _futureSubsidies = fetchSubsidies();
  }

  /// Intelligent retry with connectivity check and token refresh
  Future<void> _handleRetry() async {
    if (_isRetrying) return; // Prevent multiple simultaneous retries

    setState(() {
      _isRetrying = true;
      _errorMessage = 'Checking connection...';
    });

    print('🔄 Retry initiated - checking internet connectivity...');

    // Step 1: Check internet connectivity
    final hasInternet = await _connectivityService.hasInternetConnection();

    if (!hasInternet) {
      print('❌ No internet connection available');
      setState(() {
        _isRetrying = false;
        _errorMessage =
            'No internet connection. Please check your network and try again.';
      });
      return;
    }

    print('✅ Internet connection available');

    setState(() {
      _errorMessage = 'Refreshing access token...';
    });

    // Step 2: Try to refresh access token
    try {
      print('🔄 Attempting to refresh access token...');
      await _authService.refreshAccessToken();
      print('✅ Access token refreshed successfully');

      // Step 3: Reload the page
      setState(() {
        _hasError = false;
        _isRetrying = false;
        _errorMessage = 'Please connect to the internet and try again.';
      });

      print('🔄 Reloading subsidies...');
      _fetchData();
    } catch (e) {
      print('❌ Failed to refresh access token: $e');

      // Check if it's an auth error or server error
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

  Future<List<Subsidy>> fetchSubsidies() async {
    final accessToken = await _storage.getAccessToken();

    print(
      '🔍 Subsidy Screen - Access Token: ${accessToken != null ? "Found (${accessToken.length} chars)" : "NULL"}',
    );

    final headers = <String, String>{'Content-Type': 'application/json'};

    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    } else {
      print('⚠️ No access token found - API call will likely fail');
    }

    try {
      final url = Uri.parse('${AppConstants.baseUrl}/subsidies/getSubsidy');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        _hasError = false;
        final List<dynamic> data = jsonDecode(response.body);
        final subsidies = data.map((json) => Subsidy.fromJson(json)).toList();
        setState(() {
          _allSubsidies = subsidies;
          _filteredSubsidies = List.of(_allSubsidies);
        });
        print('✅ Subsidies loaded successfully: ${subsidies.length} items');
        return subsidies;
      } else if (response.statusCode == 401) {
        _setError();
        print('❌ Unauthorized - access token may be invalid or expired');
        throw Exception('Session expired - please log in again');
      } else {
        _setError();
        throw Exception('Failed to load subsidies: ${response.statusCode}');
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

  void _filterSubsidies() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredSubsidies = List.of(_allSubsidies);
      } else {
        _filteredSubsidies = _allSubsidies.where((s) {
          return s.title.toLowerCase().contains(query) ||
              s.stateName.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: SmartReTranslator(
          text: 'Subsidy',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.textWhite,
        elevation: 8,
        shadowColor: AppColors.shadowColor,
      ),
      body: _hasError
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
          : FutureBuilder<List<Subsidy>>(
              future: _futureSubsidies,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  _setError();
                  return const SizedBox.shrink();
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: SmartReTranslator(
                      text: 'No subsidies found',
                      style: const TextStyle(),
                    ),
                  );
                } else {
                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SmartReTranslator(
                                text: 'Search by title or state',
                                style: const TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: AppColors.primaryGreen,
                                  ),
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
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
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
                                  style: TextStyle(
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
                                          SubsidyDetailScreen(subsidy: subsidy),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }, childCount: _filteredSubsidies.length),
                      ),
                    ],
                  );
                }
              },
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

// SubsidyDetailScreen with improved dialog visibility
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
            title: Row(
              children: [
                Icon(
                  Icons.open_in_browser,
                  color: AppColors.primaryGreen,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Open Link',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: Text(
              'Do you want to open the link in your browser?',
              style: TextStyle(
                color: Colors.grey[800],
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
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text(
                  'Open',
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
              content: const Text(
                'Could not open the link',
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
      appBar: AppBar(
        title: SmartReTranslator(
          text: subsidy.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.textWhite,
        elevation: 8,
        shadowColor: AppColors.shadowColor,
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
                            style: TextStyle(
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
                          style: TextStyle(
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
                            label: SmartReTranslator(
                              text: 'More Info',
                              style: const TextStyle(fontSize: 16),
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
