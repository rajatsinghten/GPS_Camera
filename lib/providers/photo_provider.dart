import 'package:flutter/foundation.dart';
import '../models/gps_photo.dart';

class PhotoProvider extends ChangeNotifier {
  final List<GpsPhoto> _photos = [];

  List<GpsPhoto> get photos => List.unmodifiable(_photos);

  int get photoCount => _photos.length;

  void addPhoto(GpsPhoto photo) {
    _photos.insert(0, photo);
    notifyListeners();
  }

  /// Removes the photo at [index] and returns it so the caller can clean up
  /// the files backing it. Returns null when [index] is out of range.
  GpsPhoto? removePhoto(int index) {
    if (index < 0 || index >= _photos.length) return null;
    final removed = _photos.removeAt(index);
    notifyListeners();
    return removed;
  }

  void updateComposite(int index, String compositePath) {
    if (index >= 0 && index < _photos.length) {
      final old = _photos[index];
      _photos[index] = GpsPhoto(
        imagePath: old.imagePath,
        latitude: old.latitude,
        longitude: old.longitude,
        altitude: old.altitude,
        address: old.address,
        timestamp: old.timestamp,
        compositePath: compositePath,
      );
      notifyListeners();
    }
  }
}
