import 'package:flutter/material.dart';

/// App-wide look: orange-seeded tonal palette with soft, rounded surfaces.
/// Pages keep using default widgets, so the feel is set here once.
ThemeData buildAppTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.deepOrangeAccent, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    splashFactory: InkSparkle.splashFactory,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

/// Fixed-width text, for commands and raw data. "monospace" alone is only a
/// family name on Linux and Android; elsewhere the fallbacks find one.
const String kMonospaceFamily = 'monospace';
const List<String> kMonospaceFallback = ['Consolas', 'Cascadia Mono', 'Menlo', 'SF Mono', 'Courier New'];


/// Serif text, for the silent-film cards. "serif" is a family name on Linux
/// and Android; elsewhere the fallbacks find one.
const String kSerifFamily = 'serif';
const List<String> kSerifFallback = ['Georgia', 'Times New Roman', 'Noto Serif', 'DejaVu Serif'];
