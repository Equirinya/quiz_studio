// The screens of the other screenshot tools, in German, to check that the
// German texts fit:
//   flutter test tool/german_screenshots_test.dart --update-goldens
// Writes tool/screenshots_de/ (ignored by git). Only the app's own texts are
// German; Flutter's (tooltips such as "Back") stay English here.
import 'package:flutter/widgets.dart';
import 'package:quiz_show/l10n/l10n.dart';

import 'editor_layout_screenshots_test.dart' as editor_layout;
import 'rating_screenshot_test.dart' as rating;
import 'screenshot_test.dart' as screens;
import 'standing_screenshots_test.dart' as standing;

void main() {
  fallbackL10n = lookupAppLocalizations(const Locale('de'));
  screens.shotDir = 'screenshots_de';
  rating.shotDir = 'screenshots_de';
  editor_layout.shotDir = 'screenshots_de';
  standing.shotDir = 'screenshots_de';
  screens.main();
  rating.main();
  editor_layout.main();
  standing.main();
}
