import 'dart:collection';

import 'package:flutter/foundation.dart';
import '../models/gps_photo.dart';

class PhotoProvider extends ChangeNotifier {
  final List<GpsPhoto> _photos = [];

  // Built once and reused. `List.unmodifiable(_photos)` allocated a fresh
  // list on every access, and the gallery reads this several times per frame,
  // including inside itemBuilder.
  late final List<GpsPhoto> _photosView = UnmodifiableListView(_photos);

  List<GpsPhoto> get photos => _photosView;

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
    if (index < 0 || index >= _photos.length) return;
    // copyWith keeps every field. The previous inline reconstruction silently
    // dropped locationName, windSpeed, humidity, magneticField and
    // watermarkRotation.
    _photos[index] = _photos[index].copyWith(compositePath: compositePath);
    notifyListeners();
  }
}
