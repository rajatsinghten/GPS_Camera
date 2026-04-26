import 'dart:io';
import 'package:flutter/material.dart';
import '../models/gps_photo.dart';
import '../utils/theme.dart';

class PhotoCard extends StatelessWidget {
  final GpsPhoto photo;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const PhotoCard({
    super.key,
    required this.photo,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.borderColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo
            Hero(
              tag: 'photo_${photo.imagePath}',
              child: Image.file(
                File(photo.compositePath ?? photo.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.cardDark,
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: AppTheme.textSecondary,
                    size: 32,
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
