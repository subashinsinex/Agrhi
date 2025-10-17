import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import '../../src/services/language_service.dart';

class Subsidy {
  final int id;
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
  String displayedText = ''; // Initialize with empty string instead of late
  bool _cacheLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    languageService = Provider.of<LanguageService>(context);

    // Load cached translation instantly
    _getInitialTranslation();

    // Listen when cache is loaded to retranslate
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
  bool _hasError = false;
  bool _showScrollToTop = false;

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

  Future<List<Subsidy>> fetchSubsidies() async {
    try {
      final url = Uri.parse(
        'http://10.21.69.186:5000/api/subsidies/getSubsidy',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        _hasError = false;
        final List<dynamic> data = jsonDecode(response.body);
        final subsidies = data.map((json) => Subsidy.fromJson(json)).toList();
        setState(() {
          _allSubsidies = subsidies;
          _filteredSubsidies = List.of(_allSubsidies);
        });
        return subsidies;
      } else {
        _setError();
        throw Exception('Failed to load subsidies');
      }
    } catch (_) {
      _setError();
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
                  const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  SmartReTranslator(
                    text: 'Please connect to the internet and try again.',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: SmartReTranslator(
                      text: 'Reload',
                      style: const TextStyle(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _fetchData();
                      });
                    },
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
                              key: ValueKey(
                                subsidy.id,
                              ), // Added key for proper updates
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

class SubsidyDetailScreen extends StatelessWidget {
  final Subsidy subsidy;
  const SubsidyDetailScreen({super.key, required this.subsidy});

  Future<void> _launchURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Open Link'),
            content: const Text(
              'Do you want to open the link in your browser?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open'),
              ),
            ],
            backgroundColor: AppColors.appBarBackground,
          ),
        ) ??
        false;

    if (confirmed) {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link')),
        );
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
