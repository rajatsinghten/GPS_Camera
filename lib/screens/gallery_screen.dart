import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gps_photo.dart';
import '../providers/photo_provider.dart';
import '../utils/theme.dart';
import '../widgets/gps_info_overlay.dart';
import '../widgets/map_snippet.dart';
import '../widgets/photo_card.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        title: const Text('GPS Gallery'),
        actions: [
          Consumer<PhotoProvider>(
            builder: (context, provider, _) {
              if (provider.photos.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      '${provider.photoCount} photos',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<PhotoProvider>(
        builder: (context, provider, _) {
          if (provider.photos.isEmpty) {
            return _buildEmptyState();
          }
          return _buildPhotoGrid(context, provider);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.borderColor.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Icon(
              Icons.photo_camera_rounded,
              color: AppTheme.accent.withValues(alpha: 0.5),
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No GPS Photos Yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take your first geotagged photo\nusing the camera tab',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(BuildContext context, PhotoProvider provider) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: provider.photos.length,
      itemBuilder: (context, index) {
        final photo = provider.photos[index];
        return PhotoCard(
          photo: photo,
          onTap: () => _openPhotoDetail(context, photo, index),
        );
      },
    );
  }

  void _openPhotoDetail(BuildContext context, GpsPhoto photo, int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _PhotoDetailScreen(photo: photo, index: index),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

class _PhotoDetailScreen extends StatelessWidget {
  final GpsPhoto photo;
  final int index;

  const _PhotoDetailScreen({required this.photo, required this.index});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppTheme.dangerRed,
              ),
            ),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo
            Hero(
              tag: 'photo_${photo.imagePath}',
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.file(
                  File(photo.compositePath ?? photo.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.cardDark,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: AppTheme.textSecondary,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // GPS info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: AppTheme.glassDecoration,
                clipBehavior: Clip.antiAlias,
                child: GpsInfoOverlay(photo: photo),
              ),
            ),

            // Map
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MapSnippet(
                latitude: photo.latitude,
                longitude: photo.longitude,
                height: 220,
                zoom: 15,
                interactive: true,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppTheme.borderColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        title: const Text(
          'Delete Photo',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to delete this geotagged photo?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<PhotoProvider>().removePhoto(index);
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to gallery
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.dangerRed),
            ),
          ),
        ],
      ),
    );
  }
}
