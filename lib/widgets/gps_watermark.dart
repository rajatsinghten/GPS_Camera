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

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map cutout on the left
            SizedBox(
              width: 110,
              child: _buildMapCutout(),
            ),
            // Data panel on the right
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Location name header
                    Text(
                      photo.locationName.isNotEmpty
                          ? photo.locationName
                          : _extractLocationName(photo.address),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Street address
                    Text(
                      photo.address,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Coordinates
                    Row(
                      children: [
                        Icon(Icons.my_location, color: Colors.white.withValues(alpha: 0.6), size: 10),
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
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Timestamp
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.white.withValues(alpha: 0.6), size: 10),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(photo.timestamp),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Telemetry row divider
                    Container(
                      height: 0.5,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 5),

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
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
