import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/gps_photo.dart';
import '../providers/photo_provider.dart';
import '../utils/theme.dart';
import '../widgets/gps_watermark.dart';

class ReviewScreen extends StatefulWidget {
  final GpsPhoto photo;

  const ReviewScreen({super.key, required this.photo});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _compositeKey = GlobalKey();
  bool _isSaving = false;
  bool _saved = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _captureComposite() async {
    try {
      // Wait for map tiles to load
      await Future.delayed(const Duration(milliseconds: 500));

      final boundary = _compositeKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Composite capture error: $e');
      return null;
    }
  }

  Future<void> _savePhoto() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final bytes = await _captureComposite();
      if (bytes == null) throw Exception('Failed to capture composite');

      // Save to phone gallery
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: 'GPS_${DateTime.now().millisecondsSinceEpoch}',
      );

      final success = result != null && (result['isSuccess'] == true);

      if (!success) {
        throw Exception('Gallery save failed');
      }

      // Also save to app documents for in-app gallery
      final directory = await getApplicationDocumentsDirectory();
      final gpsDir = Directory('${directory.path}/gps_photos');
      if (!await gpsDir.exists()) {
        await gpsDir.create(recursive: true);
      }
      final fileName = 'GPS_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${gpsDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        final provider = context.read<PhotoProvider>();
        final savedPhoto = GpsPhoto(
          imagePath: widget.photo.imagePath,
          latitude: widget.photo.latitude,
          longitude: widget.photo.longitude,
          altitude: widget.photo.altitude,
          address: widget.photo.address,
          locationName: widget.photo.locationName,
          timestamp: widget.photo.timestamp,
          compositePath: file.path,
          windSpeed: widget.photo.windSpeed,
          humidity: widget.photo.humidity,
          magneticField: widget.photo.magneticField,
        );
        provider.addPhoto(savedPhoto);

        setState(() {
          _isSaving = false;
          _saved = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Photo saved to gallery with GPS data'),
                ),
              ],
            ),
            backgroundColor: AppTheme.cardDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save photo: $e'),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _sharePhoto() async {
    try {
      final bytes = await _captureComposite();
      if (bytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/GPS_Photo_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text:
              '📍 ${widget.photo.address}\n📐 ${widget.photo.formattedCoordinates}',
        ),
      );
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Review Photo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 22),
            onPressed: _sharePhoto,
          ),
        ],
      ),
      body: Column(
        children: [
          // Composite preview
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: RepaintBoundary(
                    key: _compositeKey,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          // Photo
                          Image.file(
                            File(widget.photo.imagePath),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.cardDark,
                              height: 400,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                          // Watermark positioned at bottom-right
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: GpsWatermark(photo: widget.photo),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(
                top: BorderSide(
                  color: AppTheme.borderColor.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // Retake
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.replay_rounded,
                    label: 'Retake',
                    onTap: () => Navigator.of(context).pop(),
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: 12),
                // Save
                Expanded(
                  flex: 2,
                  child: _buildActionButton(
                    icon: _saved
                        ? Icons.check_circle_rounded
                        : Icons.save_rounded,
                    label: _saved
                        ? 'Saved ✓'
                        : (_isSaving ? 'Saving...' : 'Save to Gallery'),
                    onTap: _saved ? null : _savePhoto,
                    isPrimary: true,
                    isLoading: _isSaving,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isPrimary = false,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary
              ? (_saved
                  ? AppTheme.accentGreen.withValues(alpha: 0.2)
                  : AppTheme.accent.withValues(alpha: 0.15))
              : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary
                ? (_saved
                    ? AppTheme.accentGreen.withValues(alpha: 0.5)
                    : AppTheme.accent.withValues(alpha: 0.4))
                : AppTheme.borderColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: AppTheme.accent,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(
                icon,
                color: isPrimary
                    ? (_saved ? AppTheme.accentGreen : AppTheme.accent)
                    : AppTheme.textSecondary,
                size: 20,
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary
                    ? (_saved ? AppTheme.accentGreen : AppTheme.accent)
                    : AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
