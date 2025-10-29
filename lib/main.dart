// import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:quiz_show/pages/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/constants.dart';
import 'package:quiz_show/pages/home_display.dart';
import 'package:quiz_show/pages/home_support.dart';
import 'package:quiz_show/pages/welcome.dart';
import 'database/firebase_options.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    windowManager.setTitle("Quiz Studio");
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );



  FirebaseFirestore.instance.settings = Settings(
    // Curiously, it is necessary to enable persistence to avoid a crash where the database of
    // this cache is not found. However, it is necessary to clear this same cache to avoid the crash due to it being corrupted.
    // #12987
    persistenceEnabled: Platform.isWindows,
  );

  // Curiously, it is necessary to enable persistence to avoid a crash where the database of
  // this cache is not found. However, it is necessary to clear this same cache
  // to avoid the crash due to it being corrupted.
  if (Platform.isWindows) {
    await FirebaseFirestore.instance.clearPersistence();
  }


  bool signedIn = FirebaseAuth.instance.currentUser != null;
  await Future.delayed(const Duration(milliseconds: 100));
  signedIn = FirebaseAuth.instance.currentUser != null;
  print("Signed in: $signedIn");

  final prefs = await SharedPreferences.getInstance();
  final bool userCreated = prefs.getBool('userCreated') ?? false;

  if(!signedIn){
    try {
      final userCredential =
      await FirebaseAuth.instance.signInAnonymously();
      print("Signed in with temporary account.");
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case "operation-not-allowed":
          print("Anonymous auth hasn't been enabled for this project.");
          break;
        default:
          print("Unknown error.");
      }
    }

  }

  // if((userCreated || signedIn) && userCreated != signedIn){
  //   print("User created: $userCreated, signed in: $signedIn");
  //   prefs.setBool('userCreated', false);
  //   signedIn = false;
  //   try{
  //     await FirebaseAuth.instance.currentUser!.delete();
  //   }catch(e){
  //     print(e);
  //   }
  //   try{
  //     await FirebaseAuth.instance.signOut();
  //   }catch(e){
  //     print(e);
  //   }
  // }
  // if (signedIn) {
  //   DocumentSnapshot<Map<String, dynamic>> userDoc =
  //       await FirebaseFirestore.instance.collection(users).doc(FirebaseAuth.instance.currentUser!.uid).get();
  //   bool firstTime = !userDoc.exists;
  //   if (!firstTime) {
  //     userDoc.reference.update({lastLogin: DateTime.now()});
  //   }
  // }
  runApp(MyApp(signedIn: signedIn));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.signedIn});

  final bool signedIn;

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
      home: !signedIn ? WelcomePage(infoText: "",onFinished: () {},) : homePage(),
    );
  }
}

Widget homePage() => Platform.isAndroid || Platform.isIOS ? const HomeSupportPage() : const HomeDisplayPage();
