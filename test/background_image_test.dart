import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quiz_show/features/session/background_image.dart';

/// A noisy picture, the worst case for a JPEG encoder.
Uint8List photo(int width, int height) {
  final image = img.Image(width: width, height: height);
  var seed = 7;
  for (final pixel in image) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    pixel
      ..r = seed & 0xff
      ..g = (seed >> 8) & 0xff
      ..b = (seed >> 16) & 0xff;
  }
  return img.encodePng(image);
}

void main() {
  // Decoding goes through the engine, which needs real async, not the fake
  // clock of a widget test.
  testWidgets('a large picture is shrunk to what a device can be sent', (tester) async {
    final result = await tester.runAsync(() => prepareBackground(photo(2600, 1300)));
    expect(result, isNotNull);
    expect(result!.length, lessThanOrEqualTo(kBackgroundMaxBytes));
    final decoded = img.decodeJpg(result)!;
    expect(decoded.width, kBackgroundMaxSide);
    expect(decoded.height, kBackgroundMaxSide ~/ 2);
  });

  testWidgets('an upright picture is limited by its height', (tester) async {
    final result = await tester.runAsync(() => prepareBackground(photo(900, 1800)));
    final decoded = img.decodeJpg(result!)!;
    expect((decoded.width, decoded.height), (kBackgroundMaxSide ~/ 2, kBackgroundMaxSide));
  });

  testWidgets('a small picture keeps its size', (tester) async {
    final result = await tester.runAsync(() => prepareBackground(photo(320, 200)));
    final decoded = img.decodeJpg(result!)!;
    expect((decoded.width, decoded.height), (320, 200));
  });

  testWidgets('something that is not a picture gives nothing, not an exception', (tester) async {
    expect(await tester.runAsync(() => prepareBackground(Uint8List.fromList([1, 2, 3, 4]))), isNull);
  });
}
