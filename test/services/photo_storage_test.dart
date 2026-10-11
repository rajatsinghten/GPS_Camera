import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/services/photo_storage.dart';

void main() {
  group('timestampFromPath', () {
    test('recovers the capture time from a GPS_ filename', () {
      const millis = 1791734415000;

      expect(
        PhotoStorage.timestampFromPath('/docs/gps_photos/GPS_$millis.png'),
        DateTime.fromMillisecondsSinceEpoch(millis),
      );
    });

    test('ignores a directory that looks like a filename', () {
      const millis = 1791734415000;

      expect(
        PhotoStorage.timestampFromPath('GPS_$millis.png/GPS_1.png'),
        DateTime.fromMillisecondsSinceEpoch(1),
      );
    });

    test('falls back to now when the name does not carry a timestamp', () {
      final before = DateTime.now();

      final result = PhotoStorage.timestampFromPath('/docs/GPS_photo.png');

      expect(result.isBefore(before), isFalse);
    });
  });
}
