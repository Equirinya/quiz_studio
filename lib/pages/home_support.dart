import 'package:flutter/material.dart';
import 'package:quiz_show/pages/about.dart';
import 'package:quiz_show/pages/companion.dart';
import 'package:quiz_show/pages/games.dart';
import 'package:quiz_show/pages/session_controller.dart';
import 'package:quiz_show/pages/settings.dart';

class HomeSupportPage extends StatefulWidget {
  const HomeSupportPage({super.key});

  @override
  State<HomeSupportPage> createState() => _HomeSupportPageState();
}

class _HomeSupportPageState extends State<HomeSupportPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Studio"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => openSettings(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          GamesPage(),
          SessionPage(),
          CompanionPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.quiz),
            icon: Icon(Icons.quiz_outlined),
            label: "Games",
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.gamepad),
            icon: Icon(Icons.gamepad_outlined),
            label: "Session",
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.phone_android),
            icon: Icon(Icons.phone_android_outlined),
            label: "Companion",
          ),
        ],
      ),
    );
  }
}
