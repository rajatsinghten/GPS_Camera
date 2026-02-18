class GpsPhoto {
  final String imagePath;
  final double latitude;
  final double longitude;
  final double? altitude;
  final String address;
  final DateTime timestamp;
  final String? compositePath;

  GpsPhoto({
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.address,
    required this.timestamp,
    this.compositePath,
  });

  String get formattedCoordinates {
    final latDir = latitude >= 0 ? 'N' : 'S';
    final lngDir = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(6)}° $latDir, ${longitude.abs().toStringAsFixed(6)}° $lngDir';
  }

  String get formattedAltitude {
    if (altitude == null) return 'N/A';
    return '${altitude!.toStringAsFixed(1)} m';
  }
}
