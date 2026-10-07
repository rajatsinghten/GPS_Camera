import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// Owns the app-private `gps_photos` directory that holds the composite PNGs
/// shown in the in-app gallery.
class PhotoStorage {
  PhotoStorage._();

  static const directoryName = 'gps_photos';

  static Future<Directory> directory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$directoryName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Removes a photo's files from disk and drops them from the image cache.
  ///
  /// Missing files are not treated as an error - the OS may already have
  /// reaped the source capture, and the gallery entry is going away anyway.
  static Future<void> deleteFiles({
    required String? compositePath,
    required String? imagePath,
  }) async {
    for (final path in {compositePath, imagePath}) {
      if (path == null || path.isEmpty) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
        await FileImage(file).evict();
      } catch (e) {
        debugPrint('Failed to delete $path: $e');
      }
    }
  }
}
