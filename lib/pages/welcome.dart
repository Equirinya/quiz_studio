import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quiz_show/main.dart';

import '../database/constants.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final TextEditingController _usernameController = TextEditingController();
  String? error;
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    double smallerSide = min(size.width, size.height);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: smallerSide / 4,
                width: smallerSide / 4,
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.primary, BlendMode.srcIn),
                child: Image.asset("assets/icon/icon_transparent.png")),
              ),
              Text("Welcome to Quiz Studio!", style: Theme.of(context).textTheme.headlineSmall),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Choose your username",
                    ),
                  ),
                ),
              ),
              if (loading) const CupertinoActivityIndicator(),
              if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    loading = true;
                    error = null;
                  });
                  if (_usernameController.text.isEmpty) {
                    setState(() {
                      error = "Please enter a username";
                      loading = false;
                    });
                    return;
                  }
                  var query = await FirebaseFirestore.instance
                      .collection(users)
                      .where(username, isEqualTo: _usernameController.text)
                      .get();
                  if (query.docs.isNotEmpty) {
                    setState(() {
                      error = "Username already taken";
                      loading = false;
                    });
                    return;
                  }
                  await FirebaseFirestore.instance
                      .collection(users)
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .set({
                    username: _usernameController.text,
                    createdAt: DateTime.now(),
                  });
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => homePage()));
                  setState(() {
                    loading = false;
                    error = null;
                  });
                },
                child: const Text("Let's go!"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
