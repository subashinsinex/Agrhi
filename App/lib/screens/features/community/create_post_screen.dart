import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../../../utils/colors.dart';
import '../../shared/smart_retranslator.dart';
import '../../../src/services/post_upload_manager.dart';

// ── Category config ──────────────────────────────────────────────────────────

class _CatConfig {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _CatConfig(this.value, this.label, this.icon, this.color);
}

const _kCategories = [
  _CatConfig('general', 'General', Icons.forum_rounded, AppColors.primaryGreen),
  _CatConfig(
    'crop_disease',
    'Crop Disease',
    Icons.bug_report_rounded,
    AppColors.primaryGreen,
  ),
  _CatConfig('tips', 'Tips', Icons.lightbulb_rounded, AppColors.primaryGreen),
  _CatConfig('weather', 'Weather', Icons.cloud_rounded, AppColors.primaryGreen),
  _CatConfig(
    'market',
    'Market',
    Icons.trending_up_rounded,
    AppColors.primaryGreen,
  ),
  _CatConfig(
    'equipment',
    'Equipment',
    Icons.agriculture_rounded,
    AppColors.primaryGreen,
  ),
];

// ── Screen ───────────────────────────────────────────────────────────────────

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with TickerProviderStateMixin {
  final _contentController = TextEditingController();
  final _contentFocus = FocusNode();
  final _picker = ImagePicker();

  String _selectedCategory = 'general';
  File? _selectedMedia;
  bool _isVideo = false;

  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoPreviewPlaying = false;

  double _trimStart = 0.0;
  double _trimEnd = 30.0;
  double _videoDuration = 0.0;
  bool _showTrimmer = false;
  bool _isTrimming = false;

  late final AnimationController _shareGlowAnim;
  late final AnimationController _mediaEnterAnim;

  static const int _maxVideoSeconds = 30;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _shareGlowAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _mediaEnterAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _contentController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _contentFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocus.dispose();
    _videoController?.removeListener(_onVideoPositionChanged);
    _videoController?.dispose();
    _shareGlowAnim.dispose();
    _mediaEnterAnim.dispose();
    super.dispose();
  }

  _CatConfig get _activeCat =>
      _kCategories.firstWhere((c) => c.value == _selectedCategory);

  // ── Video helpers ────────────────────────────────────────────────────────────

  Future<void> _initVideoPreview(File file) async {
    _videoController?.removeListener(_onVideoPositionChanged);
    _videoController?.dispose();
    final ctrl = VideoPlayerController.file(file);
    await ctrl.initialize();
    await ctrl.setLooping(false); // ✅ NO looping — we control the loop manually
    if (!mounted) {
      ctrl.dispose();
      return;
    }
    ctrl.addListener(_onVideoPositionChanged); // ✅ attach boundary listener
    setState(() {
      _videoController = ctrl;
      _videoInitialized = true;
      _videoPreviewPlaying = false;
    });
  }

  /// ✅ Called every frame — stops playback when position passes _trimEnd
  void _onVideoPositionChanged() {
    if (_videoController == null) return;
    if (!_videoPreviewPlaying) return;

    final pos = _videoController!.value.position.inMilliseconds / 1000.0;
    if (pos >= _trimEnd) {
      _videoController!.pause();
      _videoController!.seekTo(
        Duration(milliseconds: (_trimStart * 1000).round()),
      );
      if (mounted) setState(() => _videoPreviewPlaying = false);
    }
  }

  /// ✅ Always seek to _trimStart before playing (in trimmer mode)
  Future<void> _toggleVideoPreview() async {
    if (_videoController == null) return;
    if (_videoPreviewPlaying) {
      await _videoController!.pause();
      setState(() => _videoPreviewPlaying = false);
    } else {
      if (_showTrimmer) {
        // In trimmer: always start from trim start
        await _videoController!.seekTo(
          Duration(milliseconds: (_trimStart * 1000).round()),
        );
      }
      await _videoController!.play();
      setState(() => _videoPreviewPlaying = true);
    }
  }

  // ── Media helpers ────────────────────────────────────────────────────────────

  void _clearMedia() {
    HapticFeedback.mediumImpact();
    _videoController?.removeListener(_onVideoPositionChanged);
    _videoController?.dispose();
    _mediaEnterAnim.reset();
    setState(() {
      _selectedMedia = null;
      _isVideo = false;
      _videoController = null;
      _videoInitialized = false;
      _videoPreviewPlaying = false;
      _trimStart = 0.0;
      _trimEnd = 30.0;
      _videoDuration = 0.0;
      _showTrimmer = false;
    });
  }

  void _showMediaSheet() {
    HapticFeedback.lightImpact();
    _contentFocus.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MediaSourceSheet(
        hasMedia: _selectedMedia != null,
        onCamera: () {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 150), _pickCamera);
        },
        onGallery: () {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 150), _pickGallery);
        },
        onRemove: _selectedMedia != null
            ? () {
                Navigator.pop(context);
                _clearMedia();
              }
            : null,
      ),
    );
  }

  // ── Pickers ──────────────────────────────────────────────────────────────────

  Future<void> _pickCamera() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked != null && mounted) {
        HapticFeedback.selectionClick();
        _mediaEnterAnim.forward(from: 0);
        setState(() {
          _selectedMedia = File(picked.path);
          _isVideo = false;
          _videoInitialized = false;
        });
      }
    } catch (_) {
      _showError('Failed to open camera');
    }
  }

  Future<void> _pickGallery() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _TypeCard(
                    icon: Icons.image_rounded,
                    label: 'Photo',
                    sub: 'From gallery',
                    color: const Color(0xFF1E88E5),
                    onTap: () => Navigator.pop(context, 'image'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeCard(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    sub: 'Max 30 seconds',
                    color: const Color(0xFFE53935),
                    onTap: () => Navigator.pop(context, 'video'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (choice == 'image') {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        HapticFeedback.selectionClick();
        _mediaEnterAnim.forward(from: 0);
        setState(() {
          _selectedMedia = File(picked.path);
          _isVideo = false;
          _videoInitialized = false;
        });
      }
    } else if (choice == 'video') {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked != null && mounted) {
        await _handleVideoPicked(File(picked.path));
      }
    }
  }

  Future<void> _handleVideoPicked(File file) async {
    final probe = VideoPlayerController.file(file);
    await probe.initialize();
    final dur = probe.value.duration.inSeconds.toDouble();
    await probe.dispose();
    if (!mounted) return;

    if (dur <= _maxVideoSeconds) {
      _mediaEnterAnim.forward(from: 0);
      setState(() {
        _selectedMedia = file;
        _isVideo = true;
        _videoDuration = dur;
        _trimStart = 0.0;
        _trimEnd = dur;
        _showTrimmer = false;
      });
      await _initVideoPreview(file);
    } else {
      setState(() {
        _videoDuration = dur;
        _trimStart = 0.0;
        _trimEnd = _maxVideoSeconds.toDouble();
        _showTrimmer = true;
        _selectedMedia = file;
        _isVideo = true;
      });
      await _initVideoPreview(file);
      _mediaEnterAnim.forward(from: 0);
    }
  }

  Future<void> _applyTrim() async {
    if (_selectedMedia == null) return;
    final originalFile = _selectedMedia!;

    // Stop and remove listener before trimming
    _videoController?.removeListener(_onVideoPositionChanged);
    await _videoController?.pause();

    setState(() {
      _isTrimming = true;
      _showTrimmer = false;
      _videoPreviewPlaying = false;
    });

    try {
      final dir = await getTemporaryDirectory();
      final output =
          '${dir.path}/trim_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final start = _trimStart.toStringAsFixed(3);
      final dur = (_trimEnd - _trimStart).toStringAsFixed(3);

      // ✅ FIX: use -c:v libx264 -c:a aac for frame-accurate trimming
      // -c copy is fast but snaps to keyframes and is inaccurate
      final session = await FFmpegKit.execute(
        '-y -i "${originalFile.path}" -ss $start -t $dur -c:v libx264 -c:a aac -preset ultrafast -crf 23 "$output"',
      );
      final code = await session.getReturnCode();
      if (!mounted) return;

      if (ReturnCode.isSuccess(code)) {
        final trimmed = File(output);
        _mediaEnterAnim.forward(from: 0);
        setState(() {
          _selectedMedia = trimmed;
          _isVideo = true;
          _videoDuration = _trimEnd - _trimStart;
          _trimStart = 0.0;
          _trimEnd = _trimEnd - _trimStart; // reset to full trimmed length
          _showTrimmer = false;
        });
        await _initVideoPreview(trimmed);
        _showInfo('Video trimmed to ${_formatDur(_videoDuration)}');
      } else {
        _showError('Failed to trim video. Try a shorter clip.');
        setState(() {
          _selectedMedia = null;
          _isVideo = false;
        });
      }
    } catch (_) {
      if (mounted) _showError('Failed to process video');
    } finally {
      if (mounted) setState(() => _isTrimming = false);
    }
  }

  String _formatDur(double secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).round().toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Submit ───────────────────────────────────────────────────────────────────

  void _submitPost() {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      HapticFeedback.heavyImpact();
      _showError('Write something before posting');
      _contentFocus.requestFocus();
      return;
    }
    HapticFeedback.mediumImpact();
    PostUploadManager.instance.submitPost(
      content: text,
      category: _selectedCategory,
      mediaFile: _selectedMedia,
      onSuccess: (_) {},
      onError: (_) {},
    );
    Navigator.pop(context, true);
  }

  // ── Snackbars ────────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SmartReTranslator(
                  text: msg,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SmartReTranslator(
                  text: msg,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canPost = !_isTrimming && !_showTrimmer;
    return Scaffold(
      backgroundColor: _showTrimmer ? Colors.black : Colors.transparent,
      appBar: _showTrimmer ? null : _buildAppBar(canPost),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _isTrimming
            ? _buildTrimmingState()
            : _showTrimmer
            ? _buildTrimmerUI()
            : _buildComposer(),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool canPost) {
    final charCount = _contentController.text.trim().length;
    return AppBar(
      backgroundColor: AppColors.appBarBackground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.close_rounded,
            color: AppColors.textWhite,
            size: 18,
          ),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
      ),
      title: Column(
        children: [
          const SmartReTranslator(
            text: 'New Post',
            style: TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: charCount > 0
                ? Text(
                    '$charCount / 1000',
                    key: const ValueKey('count'),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textWhite.withAlpha(
                        charCount > 900 ? 255 : 160,
                      ),
                      fontWeight: charCount > 900
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: AnimatedBuilder(
            animation: _shareGlowAnim,
            builder: (_, __) {
              final hasText =
                  _contentController.text.trim().isNotEmpty && canPost;
              final glow = hasText ? _shareGlowAnim.value * 14.0 : 0.0;
              return GestureDetector(
                onTap: canPost ? _submitPost : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: hasText ? null : Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: hasText
                        ? [
                            BoxShadow(
                              color: AppColors.primaryGreen.withAlpha(120),
                              blurRadius: glow,
                              spreadRadius: glow * 0.2,
                            ),
                          ]
                        : [],
                  ),
                  child: SmartReTranslator(
                    text: 'Share',
                    style: TextStyle(
                      color: hasText
                          ? Colors.white
                          : Colors.white.withAlpha(80),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withAlpha(20)),
      ),
    );
  }

  // ── Trimming state (FFmpeg running) ──────────────────────────────────────────

  Widget _buildTrimmingState() {
    return Center(
      key: const ValueKey('trimming'),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PulseRings(
              color: AppColors.primaryGreen,
              size: 110,
              icon: Icons.content_cut_rounded,
            ),
            const SizedBox(height: 32),
            const SmartReTranslator(
              text: 'Trimming your video...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            SmartReTranslator(
              text: 'Cutting to selected segment on your device',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey.shade200,
                color: AppColors.primaryGreen,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 14),
            SmartReTranslator(
              text: 'This may take a few seconds',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  // ── Trimmer UI ───────────────────────────────────────────────────────────────

  Widget _buildTrimmerUI() {
    final selected = _trimEnd - _trimStart;
    final isValid = selected <= _maxVideoSeconds && selected >= 1;

    return Scaffold(
      key: const ValueKey('trimmer'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: _clearMedia,
        ),
        title: Column(
          children: [
            const Text(
              'Trim Video',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              'Max ${_maxVideoSeconds}s',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: isValid ? _applyTrim : null,
            child: Text(
              'Done',
              style: TextStyle(
                color: isValid ? const Color(0xFF25D366) : Colors.white30,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Video preview — tapping plays only within [_trimStart, _trimEnd]
          Expanded(
            child: GestureDetector(
              onTap: _toggleVideoPreview,
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: _videoInitialized && _videoController != null
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : const Icon(
                        Icons.videocam_rounded,
                        color: Colors.white24,
                        size: 64,
                      ),
              ),
            ),
          ),

          // Play / Pause button
          GestureDetector(
            onTap: _toggleVideoPreview,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  _videoPreviewPlaying
                      ? Icons.pause_circle_rounded
                      : Icons.play_circle_rounded,
                  key: ValueKey(_videoPreviewPlaying),
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
          ),

          // Frame strip + time readout
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TrimTimeChip(
                        label: 'Start',
                        time: _formatDur(_trimStart),
                      ),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: isValid
                              ? const Color(0xFF25D366)
                              : Colors.redAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        child: Text('${selected.round()}s selected'),
                      ),
                      _TrimTimeChip(label: 'End', time: _formatDur(_trimEnd)),
                    ],
                  ),
                ),

                _TrimStrip(
                  duration: _videoDuration,
                  trimStart: _trimStart,
                  trimEnd: _trimEnd,
                  maxTrimSeconds: _maxVideoSeconds.toDouble(),
                  onStartChanged: (v) {
                    // ✅ Stop playback & re-seek on handle drag
                    _videoController?.pause();
                    setState(() {
                      _trimStart = v;
                      _videoPreviewPlaying = false;
                      if (_trimEnd - _trimStart > _maxVideoSeconds) {
                        _trimEnd = _trimStart + _maxVideoSeconds;
                      }
                      if (_trimEnd < _trimStart + 1) {
                        _trimEnd = (_trimStart + 1).clamp(0.0, _videoDuration);
                      }
                    });
                    _videoController?.seekTo(
                      Duration(milliseconds: (v * 1000).round()),
                    );
                  },
                  onEndChanged: (v) {
                    _videoController?.pause();
                    setState(() {
                      _trimEnd = v;
                      _videoPreviewPlaying = false;
                      if (_trimEnd - _trimStart > _maxVideoSeconds) {
                        _trimStart = _trimEnd - _maxVideoSeconds;
                      }
                      if (_trimEnd < _trimStart + 1) {
                        _trimStart = (_trimEnd - 1).clamp(0.0, _videoDuration);
                      }
                    });
                    _videoController?.seekTo(
                      Duration(milliseconds: (v * 1000).round()),
                    );
                  },
                ),

                if (!isValid)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          size: 14,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Selection exceeds 30 seconds',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
    );
  }

  // ── Composer ─────────────────────────────────────────────────────────────────

  Widget _buildComposer() {
    final charCount = _contentController.text.trim().length;
    final nearLimit = charCount > 900;

    return SingleChildScrollView(
      key: const ValueKey('form'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    const SmartReTranslator(
                      text: 'Write Post',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: _contentController,
                    focusNode: _contentFocus,
                    maxLines: 5,
                    minLines: 3,
                    maxLength: 1000,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      hintText: "What's on your farm today?",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                        height: 1.6,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      counterStyle: TextStyle(
                        color: nearLimit
                            ? AppColors.errorColor
                            : Colors.grey.shade400,
                        fontSize: 11,
                        fontWeight: nearLimit
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.label_outline_rounded,
                      size: 16,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    const SmartReTranslator(
                      text: 'Select Category',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primaryGreen,
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      onChanged: (val) {
                        if (val != null) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedCategory = val);
                        }
                      },
                      selectedItemBuilder: (context) => _kCategories
                          .map(
                            (c) => Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  Icon(
                                    c.icon,
                                    size: 18,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    c.label,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      items: _kCategories.map((c) {
                        final isSel = c.value == _selectedCategory;
                        return DropdownMenuItem<String>(
                          value: c.value,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: c.color.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(c.icon, size: 16, color: c.color),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                c.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSel
                                      ? AppColors.primaryGreen
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (isSel) ...[
                                const Spacer(),
                                Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: AppColors.primaryGreen,
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Future.delayed(Duration.zero, _pickCamera),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              SmartReTranslator(
                                text: 'Camera',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            Future.delayed(Duration.zero, _pickGallery),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primaryGreen,
                              width: 1.8,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_library_rounded,
                                color: AppColors.primaryGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              SmartReTranslator(
                                text: 'Gallery',
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SmartReTranslator(
                  text:
                      'Posts with photos or videos get 3× more engagement from the community.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          if (_selectedMedia != null) ...[
            const SizedBox(height: 16),
            _buildMediaSection(),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Media section ────────────────────────────────────────────────────────────

  Widget _buildMediaSection() {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _mediaEnterAnim,
              curve: Curves.easeOutCubic,
            ),
          ),
      child: FadeTransition(
        opacity: _mediaEnterAnim,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              _isVideo && _videoInitialized && _videoController != null
                  ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                  : _isVideo
                  ? Container(
                      height: 220,
                      width: double.infinity,
                      color: Colors.black,
                      child: const Center(
                        child: Icon(
                          Icons.videocam_rounded,
                          color: Colors.white38,
                          size: 48,
                        ),
                      ),
                    )
                  : Image.file(
                      _selectedMedia!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withAlpha(100)],
                    ),
                  ),
                ),
              ),

              if (_isVideo && _videoInitialized)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _toggleVideoPreview,
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _videoPreviewPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(140),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  children: [
                    _Pill(
                      icon: Icons.edit_rounded,
                      label: 'Change',
                      bg: Colors.black.withAlpha(150),
                      onTap: _showMediaSheet,
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      icon: Icons.close_rounded,
                      label: 'Remove',
                      bg: const Color(0xFFD32F2F).withAlpha(210),
                      onTap: _clearMedia,
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 10,
                left: 10,
                child: _Pill(
                  icon: _isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                  label: _isVideo ? 'Video · max 30s' : 'Photo',
                  bg: Colors.black.withAlpha(150),
                  onTap: null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Trim UI helpers
// ═════════════════════════════════════════════════════════════════════════════

class _TrimTimeChip extends StatelessWidget {
  final String label;
  final String time;
  const _TrimTimeChip({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TrimStrip extends StatelessWidget {
  final double duration;
  final double trimStart;
  final double trimEnd;
  final double maxTrimSeconds;
  final ValueChanged<double> onStartChanged;
  final ValueChanged<double> onEndChanged;

  const _TrimStrip({
    required this.duration,
    required this.trimStart,
    required this.trimEnd,
    required this.maxTrimSeconds,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  static const double _stripHeight = 58.0;
  static const double _handleWidth = 24.0;
  static const Color _handleColor = Color(0xFFFFD600);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final usable = totalWidth - _handleWidth * 2;

        final leftFrac = duration > 0
            ? (trimStart / duration).clamp(0.0, 1.0)
            : 0.0;
        final rightFrac = duration > 0
            ? (trimEnd / duration).clamp(0.0, 1.0)
            : 1.0;

        final leftPx = leftFrac * usable;
        final rightPx = rightFrac * usable + _handleWidth;

        return SizedBox(
          height: _stripHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  children: List.generate(22, (i) {
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 0.5,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Icon(
                          Icons.image_rounded,
                          color: Colors.white10,
                          size: 12,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: leftPx + _handleWidth,
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
              Positioned(
                left: rightPx,
                top: 0,
                bottom: 0,
                right: 0,
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
              Positioned(
                left: leftPx + _handleWidth,
                width: (rightPx - (leftPx + _handleWidth)).clamp(
                  0.0,
                  totalWidth,
                ),
                top: 0,
                child: Container(height: 3, color: _handleColor),
              ),
              Positioned(
                left: leftPx + _handleWidth,
                width: (rightPx - (leftPx + _handleWidth)).clamp(
                  0.0,
                  totalWidth,
                ),
                bottom: 0,
                child: Container(height: 3, color: _handleColor),
              ),
              Positioned(
                left: leftPx,
                top: 0,
                bottom: 0,
                width: _handleWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) {
                    if (duration <= 0) return;
                    final delta = (d.primaryDelta! / usable) * duration;
                    final newVal = (trimStart + delta).clamp(0.0, trimEnd - 1);
                    onStartChanged(newVal);
                  },
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _handleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(6),
                        bottomLeft: Radius.circular(6),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: rightPx - _handleWidth,
                top: 0,
                bottom: 0,
                width: _handleWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) {
                    if (duration <= 0) return;
                    final delta = (d.primaryDelta! / usable) * duration;
                    final newVal = (trimEnd + delta).clamp(
                      trimStart + 1,
                      duration,
                    );
                    onEndChanged(newVal);
                  },
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _handleColor,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared helper widgets
// ═════════════════════════════════════════════════════════════════════════════

class _DurationChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DurationChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final VoidCallback? onTap;
  const _Pill({
    required this.icon,
    required this.label,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          SmartReTranslator(
            text: label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width - 10) / 2;
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = color.withAlpha(30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * (progress > 0 ? progress : 0.25),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter o) =>
      o.progress != progress || o.color != color;
}

class _PulseRings extends StatelessWidget {
  final Color color;
  final double size;
  final IconData icon;
  const _PulseRings({
    required this.color,
    required this.size,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(15),
        ),
      ),
      Container(
        width: size * 0.76,
        height: size * 0.76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(25),
        ),
      ),
      Container(
        width: size * 0.54,
        height: size * 0.54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(40),
        ),
        child: Center(child: Icon(icon, size: 22, color: color)),
      ),
    ],
  );
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;
  const _TypeCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 10),
          SmartReTranslator(
            text: label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          SmartReTranslator(
            text: sub,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    ),
  );
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryGreen, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SmartReTranslator(
                text: label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              SmartReTranslator(
                text: sub,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MediaSourceSheet extends StatelessWidget {
  final bool hasMedia;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onRemove;
  const _MediaSourceSheet({
    required this.hasMedia,
    required this.onCamera,
    required this.onGallery,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        _PickerTile(
          icon: Icons.camera_alt_rounded,
          label: 'Camera',
          sub: 'Take a photo',
          onTap: onCamera,
        ),
        const SizedBox(height: 10),
        _PickerTile(
          icon: Icons.photo_library_rounded,
          label: 'Gallery',
          sub: 'Photo or video',
          onTap: onGallery,
        ),
        if (onRemove != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.errorColor.withAlpha(15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.errorColor.withAlpha(50)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.errorColor.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.errorColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  SmartReTranslator(
                    text: 'Remove Media',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.errorColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
