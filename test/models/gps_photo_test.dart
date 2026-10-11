import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/models/gps_photo.dart';

void main() {
  GpsPhoto buildPhoto() => GpsPhoto(
    imagePath: '/tmp/source.jpg',
    latitude: 17.385044,
    longitude: 78.486671,
    altitude: 542.3,
    address: 'Road No 1, Banjara Hills, Hyderabad, Telangana, India',
    locationName: 'Hyderabad',
    timestamp: DateTime(2026, 10, 11, 14, 30, 15),
    compositePath: '/docs/gps_photos/GPS_1.png',
    windSpeed: 12.4,
    humidity: 61.2,
    magneticField: 43.7,
    watermarkRotation: 2,
  );

  group('formatting', () {
    test('renders coordinates with hemisphere suffixes', () {
      expect(
        buildPhoto().formattedCoordinates,
        '17.385044\u00B0 N, 78.486671\u00B0 E',
      );
    });

    test('uses southern and western hemispheres for negatives', () {
      final photo = buildPhoto().copyWith(
        latitude: -33.8688,
        longitude: -70.6693,
      );
      expect(
        photo.formattedCoordinates,
        '33.868800\u00B0 S, 70.669300\u00B0 W',
      );
    });

    test('falls back to dashes when telemetry is missing', () {
      final photo = GpsPhoto(
        imagePath: '/tmp/source.jpg',
        latitude: 1,
        longitude: 1,
        address: '',
        timestamp: DateTime(2026, 10, 11),
      );

      expect(photo.formattedAltitude, '-- m');
      expect(photo.formattedWind, '-- km/h');
      expect(photo.formattedHumidity, '--%');
      expect(photo.formattedMagnetic, '-- \u00B5T');
    });
  });

  group('copyWith', () {
    test('preserves every field it is not given', () {
      final original = buildPhoto();
      final copy = original.copyWith(compositePath: '/docs/GPS_2.png');

      expect(copy.compositePath, '/docs/GPS_2.png');
      expect(copy.imagePath, original.imagePath);
      expect(copy.latitude, original.latitude);
      expect(copy.longitude, original.longitude);
      expect(copy.altitude, original.altitude);
      expect(copy.address, original.address);
      expect(copy.locationName, original.locationName);
      expect(copy.timestamp, original.timestamp);
      expect(copy.windSpeed, original.windSpeed);
      expect(copy.humidity, original.humidity);
      expect(copy.magneticField, original.magneticField);
      expect(copy.watermarkRotation, original.watermarkRotation);
    });
  });

  group('json', () {
    test('round-trips every field', () {
      final original = buildPhoto();
      final restored = GpsPhoto.fromJson(original.toJson());

      expect(restored.imagePath, original.imagePath);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.altitude, original.altitude);
      expect(restored.address, original.address);
      expect(restored.locationName, original.locationName);
      expect(restored.timestamp, original.timestamp);
      expect(restored.compositePath, original.compositePath);
      expect(restored.windSpeed, original.windSpeed);
      expect(restored.humidity, original.humidity);
      expect(restored.magneticField, original.magneticField);
      expect(restored.watermarkRotation, original.watermarkRotation);
    });

    test('survives a partial payload without throwing', () {
      final restored = GpsPhoto.fromJson({'latitude': 17.4});

      expect(restored.latitude, 17.4);
      expect(restored.imagePath, '');
      expect(restored.watermarkRotation, 0);
    });

    test('reads back integers written as doubles', () {
      final restored = GpsPhoto.fromJson({
        'latitude': 17,
        'longitude': 78,
        'altitude': 500,
        'windSpeed': 12,
        'watermarkRotation': 2.0,
      });

      expect(restored.latitude, 17.0);
      expect(restored.watermarkRotation, 2);
    });
  });
}
