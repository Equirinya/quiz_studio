import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/constants.dart';
import 'games_edit/games_detail.dart';
import '../database/session_stream.dart';

class GamesPage extends StatefulWidget {
  const GamesPage({super.key});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  late SharedPreferences prefs;
  FirebaseFirestore db = FirebaseFirestore.instance;
  bool initialized = false;
  StreamSubscription? gamesListener;
  QuerySnapshot<Map<String, dynamic>>? gamesDocs;

//TODO pagination
  @override
  void initState() {
    () async {
      prefs = await SharedPreferences.getInstance();
      String userId = FirebaseAuth.instance.currentUser!.uid;
      gamesListener = db
          .collection(games)
          .where(Filter.or(
              Filter(AccessType.admin.name, arrayContains: userId),
              Filter(AccessType.full.name, arrayContains: userId),
              Filter(AccessType.limited.name, arrayContains: userId)))
          .orderBy(createdAt)
          .snapshots()
          .listen((event) {
        gamesDocs = event;
        setState(() {
          initialized = true;
        });
      });
    }();
    super.initState();
  }

  @override
  void dispose() {
    gamesListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const Center(child: CupertinoActivityIndicator());
    Widget newGameButton = ListTile(
      leading: const Icon(Icons.add),
      title: const Text("Create new game"),
      onTap: () {
        db.collection(games).add({
          name: "New Game",
          locked: false,
          AccessType.admin.name: [FirebaseAuth.instance.currentUser!.uid],
          AccessType.full.name: [],
          AccessType.limited.name: [],
          createdAt: FieldValue.serverTimestamp(),
          createdBy: FirebaseAuth.instance.currentUser!.uid,
        });
      },
    );
    return Scaffold(
      body: SessionStreamBuilder(
        session: prefs.getString("currentSession"),
        builder: (sessionData) {
          return ListView.builder(
            itemCount: gamesDocs!.docs.length + 1,
            itemBuilder: (context, index) {
              if (index == gamesDocs!.docs.length) {
                return newGameButton;
              }

              var game = gamesDocs!.docs[index];
              return GamesListTile(
                gameName: game.data()[name] ?? unnamed,
                gameId: game.id,
                selected: game.id == sessionData.gameRef?.id,
                sessionRef: db.collection(sessions).doc(prefs.getString("currentSession")!),
              );
            },
          );
        },
        fallback: ListView.builder(
      itemCount: gamesDocs!.docs.length + 1,
        itemBuilder: (context, index) {
          if (index == gamesDocs!.docs.length) {
            return newGameButton;
          }

          var game = gamesDocs!.docs[index];
          return GamesListTile(
            gameName: game.data()[name] ?? unnamed,
            gameId: game.id,
            selected: false,
          );
        },
      ),
      ),
    );
  }
}

class GamesListTile extends StatelessWidget {
  const GamesListTile(
      {super.key, required this.gameName, required this.gameId, required this.selected, this.sessionRef});

  final String gameName;
  final String gameId;
  final bool selected;
  final DocumentReference? sessionRef;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(gameName),
      leading: sessionRef != null ?Checkbox(
        value: selected,
        onChanged: (value) {
          sessionRef!.update({
            game: gameId,
            selectedField: "-1:-1",
            currentState: HomePageState.overview.name,
          });
        },
      ) : null,
      trailing: const Icon(Icons.arrow_forward_ios),
      tileColor: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => GamesDetailPage(gameId: gameId)));
      },
    );
  }
}
