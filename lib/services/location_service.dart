import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Why a location request could not be completed.
///
/// The distinction matters: "location services are off" needs a different
/// message (and a different fix) than "the user denied permission".
enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  lookupFailed,
}

class LocationException implements Exception {
  const LocationException(this.reason, [this.cause]);

  final LocationFailure reason;
  final Object? cause;

  /// A short, user-facing explanation suitable for the viewfinder placeholder.
  String get userMessage {
    switch (reason) {
      case LocationFailure.serviceDisabled:
        return 'Location services are off';
      case LocationFailure.permissionDenied:
        return 'Location permission denied';
      case LocationFailure.permissionDeniedForever:
        return 'Location permission blocked';
      case LocationFailure.lookupFailed:
        return 'Waiting for GPS fix...';
    }
  }

  @override
  String toString() {
    final suffix = cause == null ? '' : ': $cause';
    return 'LocationException(${reason.name}$suffix)';
  }
}

class LocationService {
  LocationService._();

  /// Throws a [LocationException] when location access is unavailable.
  static Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationFailure.permissionDeniedForever);
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(LocationFailure.permissionDenied);
    }
  }

  static Future<Position> getCurrentPosition() async {
    await ensurePermission();
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
    } catch (e) {
      throw LocationException(LocationFailure.lookupFailed, e);
    }
  }

  /// Returns the best address string the platform can produce, or `null` when
  /// nothing usable came back.
  ///
  /// A failed lookup returns `null` rather than a sentinel string so a
  /// placeholder can never be written into a saved photo's watermark.
  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final parts = <String>[
        if (place.street != null && place.street!.isNotEmpty) place.street!,
        if (place.subLocality != null && place.subLocality!.isNotEmpty)
          place.subLocality!,
        if (place.locality != null && place.locality!.isNotEmpty)
          place.locality!,
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty)
          place.administrativeArea!,
        if (place.country != null && place.country!.isNotEmpty) place.country!,
      ];

      if (parts.isEmpty) return null;
      return parts.join(', ');
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
      return null;
    }
  }

  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    );
  }
}
