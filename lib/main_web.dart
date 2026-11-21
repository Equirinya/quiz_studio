import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/fullscreen/fullscreen_button.dart';
import 'core/theme.dart';
import 'features/player/pages/join_session_page.dart';
import 'firebase_options.dart';
import 'l10n/l10n.dart';

/// The web app for teams' devices, at equirinya.github.io/quiz_studio/app/:
/// joining a show as a team and playing along (buzzer, answers, drawing with
/// a pen), nothing else. Built with `flutter build web -t lib/main_web.dart`.
///
/// A code opens it as `app/?join=session/{id}/player/{token}/{team}`, which
/// docs/open.html links to; the code can also be typed in.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Teams join as guests, like the app's "Join a show" without an account.
  if (FirebaseAuth.instance.currentUser == null) await FirebaseAuth.instance.signInAnonymously();
  await AppLanguage.load();
  final join = Uri.base.queryParameters['join'];
  runApp(CompanionWebApp(initialLink: join == null || join.isEmpty ? null : 'quiz-studio://$join'));
}

class CompanionWebApp extends StatelessWidget {
  const CompanionWebApp({super.key, this.initialLink});

  /// The code the page was opened with, joined right away.
  final String? initialLink;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppLanguage.locale,
      builder: (context, locale, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => context.l10n.appTitle,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          // Light or dark as the device is: the page behind follows.
          matchPageBackground(Theme.of(context).colorScheme.surface);
          return child ?? const SizedBox();
        },
        home: JoinSessionPage(initialLink: initialLink, asGuest: true),
      ),
    );
  }
}
