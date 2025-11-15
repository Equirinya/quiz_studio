import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'constants.dart';
import '../serial_connection.dart';

class SessionData{
  final Map<String,dynamic> sessionData;
  final List<String> teamsList;
  final List<int> pointsList;
  final (int, int) selectedFieldData;
  final int selectedCategoryGroupIndex;
  final HomePageState state;
  final bool? playing;
  final bool enableBuzzerQueue;
  final List<int> buzzeredTeam;
  final List<(int, int)> playedFieldsList;
  final int revealed;
  final Map<int, int> buzzerSensitivityMap;
  final Map<int, int> buzzerTeamMap;
  final DocumentReference? gameRef;
  final DocumentReference sessionRef;

  SessionData(this.sessionData, this.teamsList, this.pointsList, this.selectedFieldData, this.selectedCategoryGroupIndex, this.state, this.playing, this.enableBuzzerQueue, this.buzzeredTeam, this.playedFieldsList, this.revealed, this.buzzerSensitivityMap, this.buzzerTeamMap, this.gameRef, this.sessionRef);
}

class SessionStreamBuilder extends StatelessWidget {
  const SessionStreamBuilder({
    super.key,
    required this.session,
    required this.builder,
    this.fallback = const Center(child: Text(noSession)),
  });

  final String? session;
  final Widget Function(
      SessionData sessionData) builder;
  final Widget fallback;

  Future<void> downloadTeamSounds() async {
    final storage = FirebaseStorage.instance.ref().child("session_$session");
    final Directory appSupportDir = await getApplicationSupportDirectory();
    final Directory localDir = Directory('${appSupportDir.path}/session_$session');
    if(!(await localDir.exists())){
      localDir.create(recursive: true);
    }
    var files = await storage.listAll();
    print(storage.fullPath);
    print(files.items);
    for(var file in files.items){
      final localFile = File('${localDir.path}/${file.name}');
      if (!(await localFile.exists())) {
        final downloadTask = file.writeToFile(localFile);
      }
    }
    for(var localFile in localDir.listSync()){ //TODO maybe check if empty beforehand
      print(localFile.uri.pathSegments.last);
      if(!files.items.map((e) => e.name).contains(localFile.uri.pathSegments.last)){
        localFile.delete();
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
          int selectedCategoryGroupIndex = sessionSnapshot.data!.data()![selectedCategoryGroup] ?? 0;
          HomePageState state =
          HomePageState.values.firstWhere((element) => element.name == sessionSnapshot.data!.data()![currentState]);

          bool? playing = sessionSnapshot.data!.data()![playingFrom];
          bool enableBuzzerQueue = sessionSnapshot.data!.data()![queueBuzzers] ?? false;
          List<int> buzzeredTeam = sessionSnapshot.data!.data()![buzzeredFrom] != null ? List<int>.from(sessionSnapshot.data!.data()![buzzeredFrom]) : <int>[];
          List<(int, int)> playedFieldsList = sessionSnapshot.data!.data()![playedFields] != null
              ? List.from(sessionSnapshot.data!.data()![playedFields].map((e) {
            List<int> parts = e.split(":").map<int>((e) => int.tryParse(e) ?? -1).toList();
            return (parts[0], parts[1]);
          }))
              : List.empty();
          Map<int, int> buzzerSensitivityMap = Map.from(sessionSnapshot.data!.data()![buzzerSensitivity] ?? {}).map(
                (key, value) => MapEntry(int.tryParse(key)!, value),
          );
          //TODO move this to homedisplay or something like that
          for (MapEntry entry in buzzerSensitivityMap.entries) {
            SerialConnection().buzzerSensitivity[entry.key] = entry.value;
          }
          Map<int, int> buzzerTeamMap = Map.from(sessionSnapshot.data!.data()![buzzerTeam] ?? {}).map(
                (key, value) => MapEntry(int.tryParse(key)!, value),
          );
          int reveal = sessionSnapshot.data!.data()![revealed] ?? 0;

          DocumentReference? gameRef = sessionSnapshot.data!.data()?[game] != null && sessionSnapshot.data!.data()![game].isNotEmpty ? FirebaseFirestore.instance.collection(games).doc(sessionSnapshot.data!.data()![game]) : null;

          var sesData = SessionData(
              sessionSnapshot.data!.data()!,
              teamsList,
              pointsList,
              selectedFieldData,
              selectedCategoryGroupIndex,
              state,
              playing,
              enableBuzzerQueue,
              buzzeredTeam,
              playedFieldsList,
              reveal,
              buzzerSensitivityMap,
              buzzerTeamMap,
              gameRef,
              sessionSnapshot.data!.reference
          );
          return builder(sesData);
        });
  }
}
