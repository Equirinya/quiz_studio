import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// Longest side of a whiteboard picture as it is sent to the teams' devices.
const int kBackgroundMaxSide = 1280;

/// Upper bound for the encoded picture. It travels inside a Firestore
/// document (1 MiB at most) and as one message on the local network.
const int kBackgroundMaxBytes = 600 * 1024;

/// Shrinks a picture to something every team's device can be sent quickly:
/// at most [kBackgroundMaxSide] pixels on its longer side, as a JPEG no
/// larger than [kBackgroundMaxBytes]. Returns null when it cannot be read.
///
/// Decoding and scaling are done by the engine; only the JPEG encoding runs
/// in Dart, on an image that is already small.
Future<Uint8List?> prepareBackground(Uint8List original) async {
  try {
    final probe = await ui.instantiateImageCodec(original);
    final first = (await probe.getNextFrame()).image;
    final landscape = first.width >= first.height;
    final longest = landscape ? first.width : first.height;
    first.dispose();
    probe.dispose();

    final codec = await ui.instantiateImageCodec(
      original,
      targetWidth: longest > kBackgroundMaxSide && landscape ? kBackgroundMaxSide : null,
      targetHeight: longest > kBackgroundMaxSide && !landscape ? kBackgroundMaxSide : null,
    );
    final frame = (await codec.getNextFrame()).image;
    final pixels = await frame.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = frame.width, height = frame.height;
    frame.dispose();
    codec.dispose();
    if (pixels == null) return null;

    final image = img.Image.fromBytes(width: width, height: height, bytes: pixels.buffer, numChannels: 4);
    // Lower the quality until it fits; a form or a map survives that well.
    for (final quality in [82, 68, 52, 38]) {
      final jpeg = img.encodeJpg(image, quality: quality);
      if (jpeg.length <= kBackgroundMaxBytes) return jpeg;
    }
    return null;
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> prepareBackgroundFile(File file) async =>
    await file.exists() ? prepareBackground(await file.readAsBytes()) : null;
