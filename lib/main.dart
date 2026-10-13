import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme.dart';
import 'core/version_gate.dart';
import 'core/widgets/dialogs.dart';
import 'features/auth/auth_gate.dart';
import 'features/games/media_service.dart';
import 'features/games/pages/games_page.dart';
import 'features/session/pages/sessions_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    windowManager.setTitle("Quiz Studio");
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

  Future<void> _signOut() async {
    final guest = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
    final sure = await confirm(
      context,
      title: "Sign out",
      message: guest
          ? "You are signed in as a guest. Signing out loses this account and the games only it can access."
          : "You can sign in again with your email address and password.",
      action: "Sign out",
    );
    if (sure) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Studio"),
        actions: [IconButton(icon: const Icon(Icons.logout), tooltip: "Sign out", onPressed: _signOut)],
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
