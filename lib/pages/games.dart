import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/constants.dart';
import 'games_detail.dart';
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
    return Scaffold(
      body: SessionStreamBuilder(
        session: prefs.getString("currentSession"),
        builder: (teamsList, pointsList, selectedFieldData, state, buzzeredTeam, playedFieldsList, revealed,buzzerSensitivityMap,
            buzzerTeamMap, gameRef, sessionRef) {
          return ListView.builder(
            itemCount: gamesDocs!.docs.length + 1,
            itemBuilder: (context, index) {
              if (index == gamesDocs!.docs.length) {
                return ListTile(
                  leading: const Icon(Icons.add),
                  title: Text("Create new game"),
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
              }

              var game = gamesDocs!.docs[index];
              return GamesListTile(
                gameName: game.data()[name] ?? unnamed,
                gameId: game.id,
                selected: game.id == gameRef.id,
                sessionRef: db.collection(sessions).doc(prefs.getString("currentSession")!),
              );
            },
          );
        },
      ),
    );
  }
}

class GamesListTile extends StatelessWidget {
  const GamesListTile(
      {super.key, required this.gameName, required this.gameId, required this.selected, required this.sessionRef});

  final String gameName;
  final String gameId;
  final bool selected;
  final DocumentReference sessionRef;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(gameName),
      leading: Checkbox(
        value: selected,
        onChanged: (value) {
          sessionRef.update({
            game: gameId,
          });
        },
      ),
      trailing: const Icon(Icons.arrow_forward_ios),
      tileColor: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => GamesDetailPage(gameId: gameId)));
      },
    );
  }
}
