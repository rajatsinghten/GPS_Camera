import 'dart:collection';

import 'package:flutter/foundation.dart';
import '../models/gps_photo.dart';
import '../services/photo_storage.dart';

class PhotoProvider extends ChangeNotifier {
  final List<GpsPhoto> _photos = [];

  /// Built once and reused. `List.unmodifiable(_photos)` allocated a fresh
  /// list on every access, and the gallery reads this several times per frame,
  /// including inside itemBuilder.
  late final List<GpsPhoto> _photosView = UnmodifiableListView(_photos);

  bool _hasRestored = false;

  List<GpsPhoto> get photos => _photosView;

  int get photoCount => _photos.length;

  /// Rebuilds the gallery from the composites already on disk.
  ///
  /// The composites were always persisted, but nothing ever read them back,
  /// so the in-app gallery started empty on every launch.
  Future<void> restoreSavedPhotos() async {
    if (_hasRestored) return;
    _hasRestored = true;

    try {
      final saved = await PhotoStorage.loadAll();
      // A capture may have landed while the directory was being read; in that
      // case don't clobber it.
      if (_photos.isNotEmpty || saved.isEmpty) return;
      _photos.addAll(saved);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to restore saved photos: $e');
    }
  }

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
