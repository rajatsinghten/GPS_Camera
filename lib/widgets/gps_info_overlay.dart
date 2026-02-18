import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gps_photo.dart';
import '../utils/theme.dart';

class GpsInfoOverlay extends StatelessWidget {
  final GpsPhoto photo;
  final bool compact;

  const GpsInfoOverlay({
    super.key,
    required this.photo,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactOverlay();
    }
    return _buildFullOverlay();
  }

  Widget _buildFullOverlay() {
    final dateFormat = DateFormat('dd MMM yyyy • HH:mm:ss');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coordinates row
          Row(
            children: [
              _buildIcon(Icons.my_location_rounded, AppTheme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  photo.formattedCoordinates,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Address row
          Row(
            children: [
              _buildIcon(Icons.place_rounded, AppTheme.accentGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  photo.address,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Time and altitude row
          Row(
            children: [
              _buildIcon(Icons.access_time_rounded, AppTheme.accentSecondary),
              const SizedBox(width: 8),
              Text(
                dateFormat.format(photo.timestamp),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              if (photo.altitude != null) ...[
                _buildIcon(Icons.terrain_rounded, Colors.amber),
                const SizedBox(width: 4),
                Text(
                  photo.formattedAltitude,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.my_location_rounded,
            color: AppTheme.accent,
            size: 12,
          ),
          const SizedBox(width: 6),
          Text(
            photo.formattedCoordinates,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}
