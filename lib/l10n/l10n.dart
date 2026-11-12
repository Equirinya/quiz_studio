import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';
export 'names.dart';

/// The app's texts in the language around [BuildContext]: German or English.
extension L10nContext on BuildContext {
  /// English where no localizations are set up, as in most widget tests.
  AppLocalizations get l10n => Localizations.of<AppLocalizations>(this, AppLocalizations) ?? fallbackL10n;
}

/// The English texts, for code without a [BuildContext].
final AppLocalizations englishL10n = lookupAppLocalizations(const Locale('en'));

/// What [L10nContext.l10n] gives where no localizations are set up: English,
/// unless a screenshot tool draws the screens in another language.
AppLocalizations fallbackL10n = englishL10n;

/// The language the user picked in the account page; null follows the system.
class AppLanguage {
  AppLanguage._();

  static const String _key = 'app_language';

  /// The picked locale; null for the system's language.
  static final ValueNotifier<Locale?> locale = ValueNotifier(null);

  /// Reads the stored choice; call before the first frame.
  static Future<void> load() async {
    try {
      final code = (await SharedPreferences.getInstance()).getString(_key);
      locale.value = code == null ? null : Locale(code);
    } catch (_) {}
  }

  /// Picks [value] ('de', 'en') or the system's language (null), and keeps it.
  static Future<void> set(Locale? value) async {
    locale.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, value.languageCode);
      }
    } catch (_) {}
  }
}
