import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/gps_photo.dart';

class GpsWatermark extends StatelessWidget {
  final GpsPhoto photo;

  const GpsWatermark({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy HH:mm:ss');

    return RotatedBox(
      quarterTurns: photo.watermarkRotation,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Map Bubble (Square)
            Container(
              width: 125,
              height: 125,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildMapCutout(),
            ),
            
            const SizedBox(width: 5), // Padding between boxes
            
            // Info Bubble (Rectangle)
            Flexible(
              child: Container(
                height: 125, // Match Map Bubble height
                padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                  children: [
                    // Location name header
                    Text(
                      photo.locationName.isNotEmpty
                          ? photo.locationName
                          : _extractLocationName(photo.address),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Street address
                    Text(
                      photo.address,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Coordinates & Time
                    Row(
                      children: [
                        Icon(Icons.my_location, color: Colors.white.withValues(alpha: 0.5), size: 10),
                        const SizedBox(width: 4),
                        Text(
                          photo.formattedCoordinates,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.access_time, color: Colors.white.withValues(alpha: 0.5), size: 10),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('HH:mm').format(photo.timestamp),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Telemetry row divider
                    Container(
                      height: 0.5,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 8),

                    // Telemetry row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTelemetryItem(Icons.air, photo.formattedWind, 'Wind'),
                        _buildTelemetryItem(Icons.water_drop_outlined, photo.formattedHumidity, 'Hum'),
                        _buildTelemetryItem(Icons.terrain, photo.formattedAltitude, 'Alt'),
                        _buildTelemetryItem(Icons.explore_outlined, photo.formattedMagnetic, 'Mag'),
                      ],
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

  Widget _buildMapCutout() {
    final center = LatLng(photo.latitude, photo.longitude);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.gpscamera.app',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTelemetryItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 12),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _extractLocationName(String address) {
    // Extract the first meaningful part as location name
    final parts = address.split(',');
    if (parts.length >= 2) {
      // Take the locality or the first two parts
      return parts.length > 2 ? parts[2].trim() : parts[0].trim();
    }
    return parts.first.trim();
  }
}
