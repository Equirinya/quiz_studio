// Draws the pictures that come with the app into assets/cards/:
//   flutter test tool/default_images_test.dart --update-goldens
// then converts them to JPEG (see the end of this file). Run again only to
// change a picture; the app ships the files, not this code.
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/game/cards.dart';

const _fonts = '/home/jacob/development/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  Future<ByteData> read(String name) => Future.value(ByteData.view(File('$_fonts/$name').readAsBytesSync().buffer));
  final roboto = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']) {
    if (File('$_fonts/$name').existsSync()) roboto.addFont(read(name));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();
}

/// Look of each picture: icon, and the two colours of its background.
const Map<String, (IconData, Color, Color)> _looks = {
  'correct': (Icons.check_rounded, Color(0xFF1FA35C), Color(0xFF0B5D33)),
  'wrong': (Icons.close_rounded, Color(0xFFE5484D), Color(0xFF7A1418)),
  'times_up': (Icons.alarm_rounded, Color(0xFFFF9F2E), Color(0xFF9C3D00)),
  'get_ready': (Icons.rocket_launch_rounded, Color(0xFF3E8BFF), Color(0xFF12307A)),
  'thinking': (Icons.psychology_rounded, Color(0xFF7C6CF2), Color(0xFF2B1F7A)),
  'bonus': (Icons.star_rounded, Color(0xFFFF4FA8), Color(0xFF7A0F4B)),
  'drumroll': (Icons.music_note_rounded, Color(0xFFC0563B), Color(0xFF4A170C)),
  'applause': (Icons.celebration_rounded, Color(0xFFFFC21A), Color(0xFFB04A00)),
  'quiet': (Icons.volume_off_rounded, Color(0xFF5E7C8C), Color(0xFF1C2B33)),
  'break': (Icons.local_cafe_rounded, Color(0xFF2BB3A3), Color(0xFF0A4A44)),
  'final_round': (Icons.flag_rounded, Color(0xFF9B59D9), Color(0xFF2E0E4D)),
  'winner': (Icons.emoji_events_rounded, Color(0xFFF2C14E), Color(0xFF7A4A00)),
};

/// Rays from the middle, as behind a game show's logo.
class _Rays extends CustomPainter {
  const _Rays(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.longestSide;
    final paint = Paint()..color = color;
    const rays = 24;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * pi / rays;
      final b = a + pi / rays;
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx, centre.dy)
          ..lineTo(centre.dx + cos(a) * radius, centre.dy + sin(a) * radius)
          ..lineTo(centre.dx + cos(b) * radius, centre.dy + sin(b) * radius)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Rays old) => false;
}

class _Picture extends StatelessWidget {
  const _Picture(this.image);

  final BuiltinImage image;

  @override
  Widget build(BuildContext context) {
    final (icon, light, dark) = _looks[image.id]!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: [light, dark], radius: 0.95, center: const Alignment(0, -0.15)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _Rays(Colors.white.withValues(alpha: 0.07))),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 16))],
                ),
                child: Icon(icon, size: 210, color: dark),
              ),
              const SizedBox(height: 44),
              Text(
                image.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 104,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 6))],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(_loadFonts);

  for (final image in builtinImages) {
    testWidgets(image.id, (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: _Picture(image)));
      await expectLater(find.byType(_Picture), matchesGoldenFile('../assets/cards/${image.id}.png'));
    });
  }
}

// After rendering:
//   cd assets/cards && for f in *.png; do convert "$f" -quality 86 "${f%.png}.jpg" && rm "$f"; done
