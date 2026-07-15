import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import '../../../utils/colors.dart';
import '../../../utils/constants.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/smart_retranslator.dart';
import '../../../src/services/community_service.dart';
import '../../../src/services/post_upload_manager.dart';
import 'uploading_post_banner.dart';
import 'create_post_screen.dart';
import 'edit_post_screen.dart';

// ─── Active Video Notifier ────────────────────────────────────────────────────
final _activeVideoId = ValueNotifier<String?>(null);

// ─── Category Config ──────────────────────────────────────────────────────────
const _kCatIcons = <String, IconData>{
  'all': Icons.apps_rounded,
  'general': Icons.forum_rounded,
  'crop_disease': Icons.bug_report_rounded,
  'tips': Icons.lightbulb_rounded,
  'weather': Icons.cloud_rounded,
  'market': Icons.trending_up_rounded,
  'equipment': Icons.agriculture_rounded,
};

const _kCategoryLabels = <String, String>{
  'general': 'General',
  'crop_disease': 'Disease',
  'tips': 'Tips',
  'weather': 'Weather',
  'market': 'Market',
  'equipment': 'Equipment',
};

// ─── Main Screen ──────────────────────────────────────────────────────────────
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _selectedCategory = 'all';
  int _currentPage = 1;
  bool _hasMore = true;
  final _feedScrollController = ScrollController();

  List<Map<String, dynamic>> _myPosts = [];
  bool _isLoadingMyPosts = false;
  bool _myPostsLoaded = false;
  int _lastKnownDoneCount = 0;

  static const _categories = [
    {'value': 'all', 'label': 'All'},
    {'value': 'general', 'label': 'General'},
    {'value': 'crop_disease', 'label': 'Disease'},
    {'value': 'tips', 'label': 'Tips'},
    {'value': 'weather', 'label': 'Weather'},
    {'value': 'market', 'label': 'Market'},
    {'value': 'equipment', 'label': 'Equipment'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 1 && !_myPostsLoaded) _loadMyPosts();
    });
    _loadPosts(refresh: true);
    _feedScrollController.addListener(_onFeedScroll);
    PostUploadManager.instance.addListener(_onUploadManagerChanged);
  }

  void _onUploadManagerChanged() {
    if (!mounted) return;
    final doneCount = PostUploadManager.instance.activeTasks
        .where((t) => t.phase == UploadPhase.done)
        .length;
    if (doneCount > _lastKnownDoneCount) {
      _lastKnownDoneCount = doneCount;
      _refreshAllPosts();
    }
  }

  @override
  void dispose() {
    PostUploadManager.instance.removeListener(_onUploadManagerChanged);
    _tabController.dispose();
    _feedScrollController.dispose();
    super.dispose();
  }

  int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;
  String _fullUrl(String? p) => (p == null || p.isEmpty)
      ? ''
      : '${AppConstants.baseUrl.replaceAll('/api', '')}$p';
  String _videoStreamUrl(String? m) {
    if (m == null || m.isEmpty) return '';
    return '${AppConstants.baseUrl}/community/stream/${m.split('/').last}';
  }

  void _onFeedScroll() {
    if (_feedScrollController.position.pixels >=
            _feedScrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _refreshAllPosts() async {
    await _loadPosts(refresh: true);
    await _loadMyPosts();
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
      });
    }
    try {
      final posts = await CommunityService.getPosts(
        page: _currentPage,
        limit: 10,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _posts = refresh ? posts : [..._posts, ...posts];
        _hasMore = posts.length == 10;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Error loading posts', isError: true);
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    try {
      final posts = await CommunityService.getPosts(
        page: _currentPage,
        limit: 10,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _posts.addAll(posts);
        _hasMore = posts.length == 10;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _currentPage--;
      });
    }
  }

  Future<void> _loadMyPosts() async {
    setState(() => _isLoadingMyPosts = true);
    try {
      final posts = await CommunityService.getMyPosts();
      if (!mounted) return;
      setState(() {
        _myPosts = posts;
        _isLoadingMyPosts = false;
        _myPostsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMyPosts = false;
        _myPostsLoaded = true;
      });
    }
  }

  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    final wasLiked = post['is_liked_by_me'] as bool? ?? false;
    final count = _toInt(post['likes_count']);
    setState(() {
      _posts[index]['is_liked_by_me'] = !wasLiked;
      _posts[index]['likes_count'] = count + (wasLiked ? -1 : 1);
    });
    try {
      await CommunityService.toggleLike(_toInt(post['id']));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts[index]['is_liked_by_me'] = wasLiked;
        _posts[index]['likes_count'] = count;
      });
    }
  }

  Future<void> _deleteMyPost(int postId, int index) async {
    final ok = await _showDeleteDialog();
    if (ok != true) return;
    try {
      await CommunityService.deletePost(postId);
      if (!mounted) return;
      setState(() {
        _myPosts.removeAt(index);
        _posts.removeWhere((p) => _toInt(p['id']) == postId);
      });
      _showSnackBar('Post deleted');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Failed to delete post', isError: true);
    }
  }

  Future<bool?> _showDeleteDialog() => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const SmartReTranslator(
        text: 'Delete Post',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: const SmartReTranslator(
        text: 'Are you sure you want to delete this post?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: SmartReTranslator(
            text: 'Cancel',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.errorColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const SmartReTranslator(
            text: 'Delete',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  void _openComments(
    Map<String, dynamic> post,
    int index, {
    bool isFeedList = true,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        post: post,
        onCommentAdded: () {
          if (!mounted) return;
          setState(() {
            if (isFeedList) {
              _posts[index]['comments_count'] =
                  _toInt(_posts[index]['comments_count']) + 1;
            } else {
              _myPosts[index]['comments_count'] =
                  _toInt(_myPosts[index]['comments_count']) + 1;
            }
          });
        },
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SmartReTranslator(
                text: msg,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? AppColors.errorColor
            : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: CustomAppBar(
        showOnlineStatus: true,
        title: 'Community',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () async {
                HapticFeedback.lightImpact();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    SmartReTranslator(
                      text: 'Post',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryWhite,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(icon: Icon(Icons.dynamic_feed_rounded)),
            Tab(icon: Icon(Icons.person_outline_rounded)),
          ],
        ),
      ),
      body: Column(
        children: [
          const UploadingPostBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildFeedTab(), _buildMyPostsTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Feed Tab ────────────────────────────────────────────────────────────────

  Widget _buildFeedTab() {
    return Column(
      children: [
        // Category chips bar
        Container(
          color: AppColors.backgroundColor,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = _selectedCategory == cat['value'];
                final icon = _kCatIcons[cat['value']] ?? Icons.circle;
                return GestureDetector(
                  onTap: () {
                    if (_selectedCategory != cat['value']) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat['value']!);
                      _loadPosts(refresh: true);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primaryGreen
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryGreen
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 14,
                          color: selected ? Colors.white : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 5),
                        SmartReTranslator(
                          text: cat['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 1),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                )
              : _posts.isEmpty
              ? _buildEmptyState(
                  icon: Icons.people_outline,
                  title: 'No posts yet',
                  subtitle:
                      'Be the first to share something with the farming community!',
                )
              : RefreshIndicator(
                  onRefresh: () => _loadPosts(refresh: true),
                  color: AppColors.primaryGreen,
                  child: ListView.builder(
                    controller: _feedScrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _posts.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        );
                      }
                      return _PostCard(
                        key: ValueKey(_posts[i]['id']),
                        post: _posts[i],
                        fullUrl: _fullUrl,
                        videoStreamUrl: _videoStreamUrl,
                        toInt: _toInt,
                        onLike: () => _toggleLike(i),
                        onComment: () => _openComments(_posts[i], i),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ── My Posts Tab ─────────────────────────────────────────────────────────────

  Widget _buildMyPostsTab() {
    if (_isLoadingMyPosts && !_myPostsLoaded) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }
    if (_myPostsLoaded && _myPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.post_add_rounded,
        title: 'No posts yet',
        subtitle: 'Share something with the farming community!',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMyPosts,
      color: AppColors.primaryGreen,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(2),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildMyPostTile(_myPosts[i], i),
                childCount: _myPosts.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPostTile(Map<String, dynamic> post, int index) {
    final mediaUrl = post['media_url'] as String?;
    final mediaType = post['media_type'] as String? ?? 'none';
    final hasImage = mediaUrl != null && mediaType == 'image';
    final isVideo = mediaType == 'video';
    final thumbUrl = isVideo && post['video_thumbnail'] != null
        ? _fullUrl(post['video_thumbnail'] as String)
        : null;

    return GestureDetector(
      onTap: () => _openMyPostDetail(post, index),
      onLongPress: () => _showMyPostOptions(post, _toInt(post['id']), index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          hasImage
              ? Image.network(
                  _fullUrl(mediaUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _postTilePlaceholder(post),
                )
              : isVideo && thumbUrl != null
              ? Image.network(
                  thumbUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _postTilePlaceholder(post),
                )
              : _postTilePlaceholder(post),
          if (isVideo)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _postTilePlaceholder(Map<String, dynamic> post) {
    final content = post['content'] as String? ?? '';
    return Container(
      color: AppColors.primaryGreen.withOpacity(0.08),
      padding: const EdgeInsets.all(6),
      child: Center(
        child: SmartReTranslator(
          text: content.substring(0, content.length.clamp(0, 60)),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  void _openMyPostDetail(Map<String, dynamic> post, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MyPostDetailSheet(
        post: post,
        fullUrl: _fullUrl,
        videoStreamUrl: _videoStreamUrl,
        toInt: _toInt,
        onEdit: () async {
          Navigator.pop(context);
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditPostScreen(post: post)),
          );
          if (result == true) await _refreshAllPosts();
        },
        onDelete: () async {
          Navigator.pop(context);
          await _deleteMyPost(_toInt(post['id']), index);
        },
        onComment: () => _openComments(post, index, isFeedList: false),
      ),
    );
  }

  void _showMyPostOptions(Map<String, dynamic> post, int postId, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primaryGreen,
                ),
              ),
              title: const SmartReTranslator(
                text: 'Edit Post',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditPostScreen(post: post)),
                );
                if (result == true) await _refreshAllPosts();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline, color: AppColors.errorColor),
              ),
              title: SmartReTranslator(
                text: 'Delete Post',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.errorColor,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _deleteMyPost(postId, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: AppColors.primaryGreen),
            ),
            const SizedBox(height: 20),
            SmartReTranslator(
              text: title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            SmartReTranslator(
              text: subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Post Card ────────────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String Function(String?) fullUrl;
  final String Function(String?) videoStreamUrl;
  final int Function(dynamic) toInt;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const _PostCard({
    super.key,
    required this.post,
    required this.fullUrl,
    required this.videoStreamUrl,
    required this.toInt,
    required this.onLike,
    required this.onComment,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _isExpanded = false;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = true;
  bool _initStarted = false;
  bool _showThumbnail = true;

  @override
  void initState() {
    super.initState();
    _activeVideoId.addListener(_onActiveVideoChanged);
  }

  void _onActiveVideoChanged() {
    final myId = widget.post['id']?.toString();
    if (_activeVideoId.value != myId &&
        _isPlaying &&
        _videoController != null) {
      _videoController!.pause();
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  @override
  void dispose() {
    _activeVideoId.removeListener(_onActiveVideoChanged);
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideo(String url) async {
    if (_initStarted) return;
    _initStarted = true;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0);
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _videoController = ctrl;
        _isVideoInitialized = true;
        _isPlaying = true;
        _isMuted = true;
        _showThumbnail = false;
      });
      _activeVideoId.value = widget.post['id']?.toString();
      await ctrl.play();
    } catch (_) {
      ctrl.dispose();
      if (mounted) setState(() => _initStarted = false);
    }
  }

  void _onThumbnailTap(String streamUrl) {
    setState(() => _showThumbnail = false);
    _initVideo(streamUrl);
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    if (_isPlaying) {
      _videoController!.pause();
      if (_activeVideoId.value == widget.post['id']?.toString()) {
        _activeVideoId.value = null;
      }
    } else {
      _videoController!.play();
      _activeVideoId.value = widget.post['id']?.toString();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _toggleMute() {
    if (_videoController == null) return;
    _videoController!.setVolume(_isMuted ? 1.0 : 0.0);
    setState(() => _isMuted = !_isMuted);
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isLiked = post['is_liked_by_me'] as bool? ?? false;
    final mediaUrl = post['media_url'] as String?;
    final mediaType = post['media_type'] as String? ?? 'none';
    final hasMedia = mediaUrl != null && mediaType != 'none';
    final createdAt = DateTime.tryParse(post['created_at'] ?? '');
    final authorPic = post['author_pic'] as String?;
    final hasAvatar =
        authorPic != null && authorPic != 'no-image' && authorPic.isNotEmpty;
    final content = post['content'] as String? ?? '';
    final likesCount = widget.toInt(post['likes_count']);
    final commentsCount = widget.toInt(post['comments_count']);
    // ✅ ADD this
    final rawCategory = post['category'] as String? ?? '';
    final catLabel =
        _kCategoryLabels[rawCategory] ??
        (post['category_label'] as String? ?? '');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                    backgroundImage: hasAvatar
                        ? NetworkImage(widget.fullUrl(authorPic))
                        : null,
                    child: !hasAvatar
                        ? Text(
                            (post['author_name'] as String? ?? 'F')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),

                // Name + Category on the same row
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Author name
                      Expanded(
                        child: SmartReTranslator(
                          text: post['author_name'] ?? 'Farmer',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // ✅ Category badge on the right (replaces timestamp)
                      if (catLabel.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primaryGreen.withOpacity(0.2),
                            ),
                          ),
                          child: SmartReTranslator(
                            text: catLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Content text ABOVE media ────────────────────────────────────────────
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SmartReTranslator(
                    text: content,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: _isExpanded ? null : 3,
                    overflow: _isExpanded ? null : TextOverflow.ellipsis,
                  ),
                  if (content.length > 120 && !_isExpanded)
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = true),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'See more',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ── Media ───────────────────────────────────────────────────────────────
          if (hasMedia)
            ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: _buildMedia(mediaUrl, mediaType),
            ),

          // ── Action Row ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(
              children: [
                // Like
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onLike();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isLiked
                          ? AppColors.primaryGreen.withOpacity(0.1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18,
                          color: isLiked
                              ? AppColors.primaryGreen
                              : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$likesCount',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isLiked
                                ? AppColors.primaryGreen
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Comment
                GestureDetector(
                  onTap: widget.onComment,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.mode_comment_outlined,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$commentsCount',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // ✅ Upload time — bottom-right of action row
                if (createdAt != null)
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        timeago.format(createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(String? mediaUrl, String mediaType) {
    final url = widget.fullUrl(mediaUrl);

    if (mediaType == 'video') {
      final streamUrl = widget.videoStreamUrl(mediaUrl);
      final thumbUrl = widget.post['video_thumbnail'] != null
          ? widget.fullUrl(widget.post['video_thumbnail'] as String)
          : null;

      // STATE 1: Thumbnail
      if (_showThumbnail) {
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: GestureDetector(
            onTap: () => _onThumbnailTap(streamUrl),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: thumbUrl != null && thumbUrl.isNotEmpty
                      ? Image.network(
                          thumbUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.black87),
                        )
                      : Container(color: Colors.black87),
                ),
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(0.2)),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                // Duration badge
                if (widget.post['video_duration'] != null)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _fmt(widget.toInt(widget.post['video_duration'])),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                // Video badge
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Video',
                          style: TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // STATE 2: Loading
      if (!_isVideoInitialized || _videoController == null) {
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: thumbUrl != null && thumbUrl.isNotEmpty
                    ? Image.network(
                        thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.black87),
                      )
                    : Container(color: Colors.black87),
              ),
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.35)),
              ),
              CircularProgressIndicator(
                color: AppColors.primaryGreen,
                strokeWidth: 3,
              ),
            ],
          ),
        );
      }

      // STATE 3: Playing
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: GestureDetector(
          onTap: _togglePlayPause,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_videoController!),
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _videoController!,
                  allowScrubbing: false,
                  colors: VideoProgressColors(
                    playedColor: AppColors.primaryGreen,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white12,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Image
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade100,
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.grey.shade400,
            size: 40,
          ),
        ),
      ),
    );
  }
}

// ─── Inline Video Player ──────────────────────────────────────────────────────

class _InlineVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final int duration;
  const _InlineVideoPlayer({
    required this.videoUrl,
    this.thumbnailUrl,
    this.duration = 0,
  });

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isLoading = false;

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _initAndPlay() async {
    if (_initialized) {
      _togglePlay();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      c.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() {
        _controller = c;
        _initialized = true;
        _isLoading = false;
      });
      await c.play();
      setState(() => _isPlaying = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isPlaying) setState(() => _showControls = false);
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePlay() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
        _showControls = true;
      });
    } else {
      _controller!.play();
      setState(() {
        _isPlaying = true;
        _showControls = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isPlaying) setState(() => _showControls = false);
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls && _isPlaying) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isPlaying) setState(() => _showControls = false);
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasThumbnail =
        widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty;
    return GestureDetector(
      onTap: _initialized ? _toggleControls : _initAndPlay,
      child: AspectRatio(
        aspectRatio: _initialized && _controller != null
            ? _controller!.value.aspectRatio
            : 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_initialized && _controller != null)
              VideoPlayer(_controller!)
            else if (hasThumbnail)
              Image.network(
                widget.thumbnailUrl!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black87),
              )
            else
              Container(color: Colors.black87),
            if (_isLoading)
              Container(
                color: Colors.black45,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            if (!_isLoading && (!_initialized || _showControls))
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                ),
              ),
            if (_initialized && _controller != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: AppColors.primaryGreen,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white12,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            if (widget.duration > 0 && !_initialized)
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _fmt(widget.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_initialized && _showControls)
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () {
                    final muted = _controller!.value.volume == 0;
                    _controller!.setVolume(muted ? 1.0 : 0.0);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _controller!.value.volume == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 18,
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

// ─── My Post Detail Sheet ─────────────────────────────────────────────────────

class _MyPostDetailSheet extends StatelessWidget {
  final Map<String, dynamic> post;
  final String Function(String?) fullUrl;
  final String Function(String?) videoStreamUrl;
  final int Function(dynamic) toInt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onComment;

  const _MyPostDetailSheet({
    required this.post,
    required this.fullUrl,
    required this.videoStreamUrl,
    required this.toInt,
    required this.onEdit,
    required this.onDelete,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    final mediaUrl = post['media_url'] as String?;
    final mediaType = post['media_type'] as String? ?? 'none';
    final hasImage = mediaUrl != null && mediaType == 'image';
    final isVideo = mediaType == 'video';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.article_outlined,
                      color: AppColors.primaryGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: SmartReTranslator(
                      text: 'My Post',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.primaryGreen,
                      size: 22,
                    ),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: AppColors.errorColor,
                      size: 22,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.all(16),
                children: [
                  if (hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        fullUrl(mediaUrl),
                        height: 260,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                  if (isVideo && mediaUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _InlineVideoPlayer(
                        videoUrl: fullUrl(mediaUrl),
                        thumbnailUrl: post['video_thumbnail'] != null
                            ? fullUrl(post['video_thumbnail'] as String)
                            : null,
                        duration: toInt(post['video_duration']),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SmartReTranslator(
                    text: post['content'] as String? ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 5),
                            SmartReTranslator(
                              text: '${toInt(post['likes_count'])} likes',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: onComment,
                          child: Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 18,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 5),
                              SmartReTranslator(
                                text:
                                    '${toInt(post['comments_count'])} comments',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Comments Sheet ───────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onCommentAdded;
  const _CommentsSheet({required this.post, required this.onCommentAdded});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await CommunityService.getComments(
        _toInt(widget.post['id']),
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      final comment = await CommunityService.addComment(
        postId: _toInt(widget.post['id']),
        content: text,
      );
      _commentController.clear();
      if (!mounted) return;
      setState(() {
        _comments.add({
          ...comment,
          'author_name': 'You',
          'author_pic': null,
          'is_my_comment': true,
        });
        _isSending = false;
      });
      widget.onCommentAdded();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(int commentId, int index) async {
    try {
      await CommunityService.deleteComment(
        postId: _toInt(widget.post['id']),
        commentId: commentId,
      );
      if (!mounted) return;
      setState(() => _comments.removeAt(index));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const SmartReTranslator(text: 'Failed to delete comment'),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  SmartReTranslator(
                    text: 'Comments',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_comments.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    )
                  : _comments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 52,
                            color: Colors.grey.shade200,
                          ),
                          const SizedBox(height: 12),
                          SmartReTranslator(
                            text: 'No comments yet. Be the first!',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      itemCount: _comments.length,
                      itemBuilder: (_, i) => _buildCommentTile(_comments[i], i),
                    ),
            ),
            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _commentController,
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendComment(),
                        decoration: InputDecoration(
                          hintText: 'Write a comment...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _sendComment,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isSending
                            ? Colors.grey.shade300
                            : AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> c, int index) {
    final isMine = c['is_my_comment'] as bool? ?? false;
    final createdAt = DateTime.tryParse(c['created_at'] ?? '');
    final name = c['author_name'] as String? ?? 'Farmer';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: isMine
                ? AppColors.primaryGreen.withOpacity(0.15)
                : Colors.grey.shade200,
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                color: isMine ? AppColors.primaryGreen : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  decoration: BoxDecoration(
                    color: isMine
                        ? AppColors.primaryGreen.withOpacity(0.06)
                        : Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SmartReTranslator(
                            text: isMine ? 'You' : name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: isMine
                                  ? AppColors.primaryGreen
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (createdAt != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              timeago.format(createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      SmartReTranslator(
                        text: c['content'] as String? ?? '',
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMine)
            GestureDetector(
              onTap: () => _deleteComment(_toInt(c['id']), index),
              child: Padding(
                padding: const EdgeInsets.only(left: 6, top: 4),
                child: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red.shade300,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
