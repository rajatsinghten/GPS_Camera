import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

import '../models/gps_photo.dart';

/// Owns the app-private `gps_photos` directory that holds the composite PNGs
/// shown in the in-app gallery.
///
/// Each composite is stored as a `GPS_<millis>.png` with a matching
/// `GPS_<millis>.json` sidecar holding the photo's metadata. Sidecars rather
/// than one central index so a single corrupt file cannot take out the whole
/// gallery.
class PhotoStorage {
  PhotoStorage._();

  static const directoryName = 'gps_photos';

  static Future<Directory> directory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$directoryName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Writes [bytes] as a composite PNG alongside its metadata sidecar and
  /// returns the path of the written PNG.
  static Future<String> saveComposite(
    GpsPhoto photo,
    Uint8List bytes, {
    required DateTime timestamp,
  }) async {
    final dir = await directory();
    final stem = 'GPS_${timestamp.millisecondsSinceEpoch}';

    final png = File('${dir.path}/$stem.png');
    await png.writeAsBytes(bytes, flush: true);

    final metadata = photo.copyWith(compositePath: png.path).toJson();
    await File('${dir.path}/$stem.json').writeAsString(jsonEncode(metadata));

    return png.path;
  }

  /// Every composite the app has saved, newest first.
  static Future<List<GpsPhoto>> loadAll() async {
    final dir = await directory();
    final photos = <GpsPhoto>[];

    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.png')) continue;

      final sidecar = File(
        '${entity.path.substring(0, entity.path.length - '.png'.length)}.json',
      );

      GpsPhoto? photo;
      if (await sidecar.exists()) {
        try {
          final decoded = jsonDecode(await sidecar.readAsString());
          if (decoded is Map<String, dynamic>) {
            photo = GpsPhoto.fromJson(decoded);
          }
        } catch (e) {
          debugPrint('Unreadable photo metadata ${sidecar.path}: $e');
        }
      }

      // A PNG with no readable sidecar is still a photo worth showing, so
      // rebuild what we can from the filename.
      photo ??= GpsPhoto(
        imagePath: entity.path,
        latitude: 0,
        longitude: 0,
        address: '',
        timestamp: timestampFromPath(entity.path),
        compositePath: entity.path,
      );

      // The source capture lives in the OS temp directory and may already have
      // been reaped, so never hand out a path that no longer resolves.
      if (photo.imagePath.isEmpty || !File(photo.imagePath).existsSync()) {
        photo = photo.copyWith(
          imagePath: entity.path,
          compositePath: entity.path,
        );
      }

      photos.add(photo);
    }

    photos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return photos;
  }

  /// Recovers the capture time from a `GPS_<millis>.png` filename.
  @visibleForTesting
  static DateTime timestampFromPath(String path) {
    final match = RegExp(r'GPS_(\d+)\.png$').firstMatch(path);
    final millis = match == null ? null : int.tryParse(match.group(1)!);
    if (millis == null) return DateTime.now();
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Removes a photo's files from disk and drops them from the image cache.
  ///
  /// Missing files are not treated as an error - the OS may already have
  /// reaped the source capture, and the gallery entry is going away anyway.
  static Future<void> deleteFiles({
    required String? compositePath,
    required String? imagePath,
  }) async {
    final seen = <String>{};

    for (final path in {compositePath, imagePath}) {
      if (path == null || path.isEmpty) continue;
      if (!seen.add(path)) continue;

      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
        await FileImage(file).evict();
      } catch (e) {
        debugPrint('Failed to delete $path: $e');
      }
    }

    // Drop the sidecar next to the composite too, otherwise loadAll() would
    // keep resurrecting the metadata for a file that is gone.
    if (compositePath != null && compositePath.endsWith('.png')) {
      try {
        final sidecar = File(
          '${compositePath.substring(0, compositePath.length - '.png'.length)}.json',
        );
        if (await sidecar.exists()) await sidecar.delete();
      } catch (e) {
        debugPrint('Failed to delete sidecar for $compositePath: $e');
      }
    }
  }
}
