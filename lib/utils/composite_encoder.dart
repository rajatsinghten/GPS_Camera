import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Raw RGBA pixels and their dimensions, in a shape that is safe to hand to a
/// background isolate.
///
/// The bytes are expected in Flutter's `ImageByteFormat.rawRgba` layout, which
/// is *premultiplied*. That is only equivalent to straight RGBA while the
/// composite stays fully opaque, which it is today because it is drawn over an
/// opaque black container. If the composite ever gains transparency, switch
/// the source to `rawStraightRgba` or unpremultiply before encoding.
class CompositePixels {
  const CompositePixels({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Encodes raw RGBA pixels to PNG.
///
/// Run this through `compute` rather than calling it inline: PNG encoding of a
/// ~1400x1900 composite is CPU bound and blocked the UI thread for roughly
/// half a second after every capture.
Uint8List encodeCompositePng(CompositePixels pixels) {
  final frame = img.Image.fromBytes(
    width: pixels.width,
    height: pixels.height,
    bytes: pixels.bytes.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodePng(frame);
}
