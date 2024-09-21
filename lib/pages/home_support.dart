import 'package:flutter/material.dart';
import 'package:quiz_show/pages/about.dart';
import 'package:quiz_show/pages/games.dart';
import 'package:quiz_show/pages/session_controller.dart';

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
            icon: const Icon(Icons.info),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(appBar: AppBar(), body: const AboutPage()),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          GamesPage(),
          SessionPage()
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
        ],
      ),
    );
  }
}
