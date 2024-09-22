import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'constants.dart';
import '../serial_connection.dart';

class SessionStreamBuilder extends StatelessWidget {
  const SessionStreamBuilder({
    super.key,
    required this.session,
    required this.builder,
    this.fallback = const Center(child: Text(noSession)),
  });

  final String? session;
  final Widget Function(
      List<String> teamsList,
      List<int> pointsList,
      (int, int) selectedFieldData,
      HomePageState state,
      int? buzzeredTeam,
      List<(int, int)> playedFieldsList,
      int revealed,
      Map<int, int> buzzerSensitivityMap,
      Map<int, int> buzzerTeamMap,
      DocumentReference gameRef,
      DocumentReference sessionRef,
      ) builder;
  final Widget fallback;

  Future<void> downloadTeamSounds() async {
    final storage = FirebaseStorage.instance.ref().child("session_$session");
    final Directory appSupportDir = await getApplicationSupportDirectory();
    var files = await storage.listAll();
    for(var file in files.items){
      final localFile = File('${appSupportDir.path}/$session/${file.name}');
      if (!(await localFile.exists())) {
        final downloadTask = file.writeToFile(localFile);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (session == null) return fallback;
    downloadTeamSounds();
    return StreamBuilder(
        stream: FirebaseFirestore.instance.collection(sessions).doc(session!).snapshots(),
        builder: (context, sessionSnapshot) {
          if (!sessionSnapshot.hasData || sessionSnapshot.data == null || sessionSnapshot.data!.data() == null) {
            return fallback;
          }

          List<String> teamsList = sessionSnapshot.data!.data()![teams] != null
              ? List.from(sessionSnapshot.data!.data()![teams])
              : List.empty();
          List<int> pointsList = sessionSnapshot.data!.data()![points] != null
              ? List.from(sessionSnapshot.data!.data()![points])
              : List.filled(teamsList.length, 0);

          (int, int) selectedFieldData;
          if (sessionSnapshot.data!.data()![selectedField] != null) {
            List<int> parts = (sessionSnapshot.data!.data()![selectedField])
                .split(":")
                .map<int>((e) => (int.tryParse(e) ?? -1))
                .toList();
            selectedFieldData = (parts[0], parts[1]);
          } else {
            selectedFieldData = (-1, -1);
          }
          HomePageState state =
          HomePageState.values.firstWhere((element) => element.name == sessionSnapshot.data!.data()![currentState]);
          int? buzzeredTeam = sessionSnapshot.data!.data()![buzzeredFrom];
          List<(int, int)> playedFieldsList = sessionSnapshot.data!.data()![playedFields] != null
              ? List.from(sessionSnapshot.data!.data()![playedFields].map((e) {
            List<int> parts = e.split(":").map<int>((e) => int.tryParse(e) ?? -1).toList();
            return (parts[0], parts[1]);
          }))
              : List.empty();
          Map<int, int> buzzerSensitivityMap = Map.from(sessionSnapshot.data!.data()![buzzerSensitivity]).map(
                (key, value) => MapEntry(int.tryParse(key)!, value),
          );
          for (MapEntry entry in buzzerSensitivityMap.entries) {
            SerialConnection().buzzerSensitivity[entry.key] = entry.value;
          }
          Map<int, int> buzzerTeamMap = Map.from(sessionSnapshot.data!.data()![buzzerTeam]).map(
                (key, value) => MapEntry(int.tryParse(key)!, value),
          );
          int reveal = sessionSnapshot.data!.data()![revealed] ?? 0;

          DocumentReference gameRef = FirebaseFirestore.instance.collection(games).doc(sessionSnapshot.data!.data()![game]);

          return builder(teamsList, pointsList, selectedFieldData, state, buzzeredTeam, playedFieldsList,reveal,
              buzzerSensitivityMap, buzzerTeamMap, gameRef,sessionSnapshot.data!.reference);
        });
  }
}
