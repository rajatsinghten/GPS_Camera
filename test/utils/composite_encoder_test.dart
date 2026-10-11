import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/utils/composite_encoder.dart';

void main() {
  /// The 8-byte PNG magic number.
  const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  test('encodes raw RGBA pixels into a PNG', () {
    final pixels = CompositePixels(
      bytes: Uint8List.fromList([
        255, 0, 0, 255, // red
        0, 255, 0, 255, // green
        0, 0, 255, 255, // blue
        255, 255, 255, 255, // white
      ]),
      width: 2,
      height: 2,
    );

    final png = encodeCompositePng(pixels);

    expect(png.length, greaterThan(pngSignature.length));
    expect(png.sublist(0, pngSignature.length), pngSignature);
  });

  test('encodes a single pixel', () {
    final pixels = CompositePixels(
      bytes: Uint8List.fromList([0, 0, 0, 255]),
      width: 1,
      height: 1,
    );

    expect(
      encodeCompositePng(pixels).sublist(0, pngSignature.length),
      pngSignature,
    );
  });
}
