// import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import '../database/constants.dart';
import 'package:quiz_show/pages/home_display.dart';
import 'package:quiz_show/pages/home_support.dart';
import 'package:quiz_show/pages/welcome.dart';
import 'database/firebase_options.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (kDebugMode) {
        print("Signed in with anonymous account.");
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case "operation-not-allowed":
          if (kDebugMode) {
            print("Anonymous auth hasn't been enabled for this project.");
          }
          break;
        default:
          if (kDebugMode) {
            print("Unknown auth error ${e.code} : ${e.message}");
          }
      }
    }
  }

  DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore.instance.collection(users).doc(FirebaseAuth.instance.currentUser!.uid).get();
  bool firstTime = !userDoc.exists;
  if(!firstTime) {
    userDoc.reference.update({lastLogin: DateTime.now()});
  }

  runApp(MyApp(firstTime: firstTime));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.firstTime});

  final bool firstTime;

  @override
  Widget build(BuildContext context) {
    Color seedColor = Colors.deepOrangeAccent;
    ThemeMode themeMode = ThemeMode.system;
    ColorScheme lightColorScheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light);
    ColorScheme darkColorScheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark);

    // if (Platform.isWindows) {
    //   return fluent.FluentApp(
    //     debugShowCheckedModeBanner: false,
    //     theme: fluent.FluentThemeData(
    //       brightness: Brightness.light,
    //       accentColor: lightColorScheme.primary.toAccentColor(),
    //     ),
    //     darkTheme: fluent.FluentThemeData(
    //       brightness: Brightness.dark,
    //       accentColor: lightColorScheme.primary.toAccentColor(),
    //     ),
    //     themeMode: themeMode,
    //   home: HomePage(),
    //   );
    // }




    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
      ),
      themeMode: themeMode,
      home: firstTime? const WelcomePage() : homePage(),
    );
  }
}

Widget homePage() => Platform.isAndroid || Platform.isIOS ? const HomeSupportPage() : const HomeDisplayPage();


