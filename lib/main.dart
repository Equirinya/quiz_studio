import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'core/crash_log.dart';
import 'core/theme.dart';
import 'core/version_gate.dart';
import 'features/auth/auth_gate.dart';
import 'features/games/media_service.dart';
import 'features/games/pages/games_page.dart';
import 'features/session/pages/sessions_page.dart';
import 'features/session/presenter_window.dart';
import 'features/settings/account_page.dart';
import 'firebase_options.dart';

void main(List<String> args) async {
  // A second window showing a show the main window runs; see PresenterWindow.
  final window = PresenterWindowArgs.tryParse(args);
  if (window != null) return runPresenterWindow(window);
  WidgetsFlutterBinding.ensureInitialized();
  await CrashLog.init();
  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    windowManager.setTitle("Quiz Studio");
  }
  // The video player's native side, for video cards on the presenter.
  MediaKit.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (Platform.isWindows) {
    // Firestore's on-disk cache gets corrupted on some Windows machines and
    // then crashes the app natively (flutterfire#12987). Games are held in
    // memory while presenting anyway, so keep Firestore's cache in memory too.
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  }
  await MediaService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      // An installed version below `config/app.minRequiredVersion` never
      // reaches onboarding or the app.
      home: const VersionGate(child: AuthGate(child: HomePage())),
    );
  }
}

/// Games to write, sessions to run.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Studio"),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: "Account",
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountPage())),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: const [GamesPage(), SessionsPage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.quiz_outlined), selectedIcon: Icon(Icons.quiz), label: "Games"),
          NavigationDestination(icon: Icon(Icons.live_tv_outlined), selectedIcon: Icon(Icons.live_tv), label: "Sessions"),
        ],
      ),
    );
  }
}
