class GpsPhoto {
  final String imagePath;
  final double latitude;
  final double longitude;
  final double? altitude;
  final String address;
  final String locationName;
  final DateTime timestamp;
  final String? compositePath;
  final double? windSpeed;
  final double? humidity;
  final double? magneticField;
  final int watermarkRotation;

  GpsPhoto({
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.address,
    this.locationName = '',
    required this.timestamp,
    this.compositePath,
    this.windSpeed,
    this.humidity,
    this.magneticField,
    this.watermarkRotation = 0,
  });

  String get formattedCoordinates {
    final latDir = latitude >= 0 ? 'N' : 'S';
    final lngDir = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(6)}° $latDir, ${longitude.abs().toStringAsFixed(6)}° $lngDir';
  }

  String get formattedAltitude {
    if (altitude == null) return '-- m';
    return '${altitude!.toStringAsFixed(1)} m';
  }

  String get formattedWind {
    if (windSpeed == null) return '-- km/h';
    return '${windSpeed!.toStringAsFixed(0)} km/h';
  }

  String get formattedHumidity {
    if (humidity == null) return '--%';
    return '${humidity!.toStringAsFixed(0)}%';
  }

  String get formattedMagnetic {
    if (magneticField == null) return '-- µT';
    return '${magneticField!.toStringAsFixed(0)} µT';
  }
}
