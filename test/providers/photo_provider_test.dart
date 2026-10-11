import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/models/gps_photo.dart';
import 'package:gps_camera/providers/photo_provider.dart';

void main() {
  GpsPhoto buildPhoto({
    String imagePath = '/tmp/source.jpg',
    String? compositePath,
    int rotation = 0,
  }) {
    return GpsPhoto(
      imagePath: imagePath,
      latitude: 17.385044,
      longitude: 78.486671,
      altitude: 542.3,
      address: 'Banjara Hills, Hyderabad, Telangana, India',
      locationName: 'Hyderabad',
      timestamp: DateTime(2026, 10, 11, 14, 30),
      compositePath: compositePath,
      windSpeed: 12.4,
      humidity: 61.2,
      magneticField: 43.7,
      watermarkRotation: rotation,
    );
  }

  test('starts empty', () {
    final provider = PhotoProvider();
    expect(provider.photos, isEmpty);
    expect(provider.photoCount, 0);
  });

  test('addPhoto puts the newest photo first', () {
    final provider = PhotoProvider()
      ..addPhoto(buildPhoto(imagePath: '/tmp/first.jpg'))
      ..addPhoto(buildPhoto(imagePath: '/tmp/second.jpg'));

    expect(provider.photoCount, 2);
    expect(provider.photos.first.imagePath, '/tmp/second.jpg');
  });

  test('addPhoto notifies listeners', () {
    final provider = PhotoProvider();
    var notifications = 0;
    provider.addListener(() => notifications++);

    provider.addPhoto(buildPhoto());

    expect(notifications, 1);
  });

  test('removePhoto returns the removed photo and shrinks the list', () {
    final provider = PhotoProvider()
      ..addPhoto(buildPhoto(imagePath: '/tmp/keep.jpg'))
      ..addPhoto(buildPhoto(imagePath: '/tmp/drop.jpg'));

    final removed = provider.removePhoto(0);

    expect(removed?.imagePath, '/tmp/drop.jpg');
    expect(provider.photoCount, 1);
    expect(provider.photos.single.imagePath, '/tmp/keep.jpg');
  });

  test('removePhoto returns null and does nothing when out of range', () {
    final provider = PhotoProvider()..addPhoto(buildPhoto());

    expect(provider.removePhoto(-1), isNull);
    expect(provider.removePhoto(5), isNull);
    expect(provider.photoCount, 1);
  });

  test('updateComposite keeps every other field', () {
    final provider = PhotoProvider()
      ..addPhoto(buildPhoto(rotation: 3));

    provider.updateComposite(0, '/docs/GPS_9.png');
    final updated = provider.photos.single;

    expect(updated.compositePath, '/docs/GPS_9.png');
    // These are the fields the old hand-rolled copy in updateComposite
    // dropped on the floor.
    expect(updated.locationName, 'Hyderabad');
    expect(updated.windSpeed, 12.4);
    expect(updated.humidity, 61.2);
    expect(updated.magneticField, 43.7);
    expect(updated.watermarkRotation, 3);
  });

  test('updateComposite ignores an out-of-range index', () {
    final provider = PhotoProvider()..addPhoto(buildPhoto());

    provider.updateComposite(4, '/docs/GPS_9.png');

    expect(provider.photos.single.compositePath, isNull);
  });

  test('photos cannot be mutated through the getter', () {
    final provider = PhotoProvider()..addPhoto(buildPhoto());

    expect(() => provider.photos.clear(), throwsUnsupportedError);
    expect(provider.photoCount, 1);
  });
}
