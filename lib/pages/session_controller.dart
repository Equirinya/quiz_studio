import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quiz_show/database/game_stream.dart';
import 'package:quiz_show/pages/settings.dart';
import 'package:quiz_show/widgets/question.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/constants.dart';
import '../database/session_stream.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({super.key});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  late SharedPreferences prefs;
  bool initialized = false;

  @override
  void initState() {
    () async {
      prefs = await SharedPreferences.getInstance();
      setState(() {
        initialized = true;
      });
    }();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const CupertinoActivityIndicator();
    return Scaffold(
      body: ListView(
        children: [
          SettingsSubPageCategory(
            title: "Session",
            settings: [
              FutureBuilder(
                future: FirebaseFirestore.instance.collection(sessions).get(),
                builder: (context, snapshot) => snapshot.hasData && snapshot.data != null
                    ? StringSelectionSetting(
                        setting: "currentSession",
                        title: "Current Session",
                        icon: Icons.workspaces,
                        options: snapshot.data!.docs //TODO improve
                            .map(
                              (e) => e.id,
                            )
                            .toList())
                    : const ListTile(
                        title: Text("Current Session Loading..."),
                        leading: Icon(Icons.workspaces),
                      ),
              ),
              ListTile(
                //TODO move to side of session selection
                title: Text("Create new session"),
                leading: const Icon(Icons.add),
                subtitle: const Text("Create a new empty session"),
                onTap: () async {
                  DocumentReference ref = FirebaseFirestore.instance.collection(sessions).doc();
                  await ref.set({
                    game: "",
                    teams: [],
                    points: [],
                    currentState: HomePageState.overview.name,
                    selectedField: "-1:-1",
                    playedFields: [],
                    revealed: 0,
                    information: [],
                  });
                  await prefs.setString("currentSession", ref.id);
                  setState(() {});
                },
              ),
            ],
          ),
          SessionStreamBuilder(
            session: prefs.getString("currentSession"),
            builder: (teamsList, pointsList, selectedFieldData, state, buzzeredTeam, playedFieldsList, revealed,
                buzzerSensitivityMap, buzzerTeamMap, gameRef, sessionRef) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (var (index, team) in teamsList.indexed)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: 200,
                                child: Column(
                                  children: [
                                    Text(
                                      team,
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      (pointsList[index] ?? 0).toString(),
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                    ElevatedButton(
                                        onPressed: () async {
                                          pointsList[index] += 100;
                                          sessionRef.update({
                                            points: pointsList,
                                          });
                                        },
                                        child: const Text("+100")),
                                    ElevatedButton(
                                        onPressed: () async {
                                          pointsList[index] -= 100;
                                          sessionRef.update({
                                            points: pointsList,
                                          });
                                        },
                                        child: const Text("-100")),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    GameStreamBuilder(
                      gameId: gameRef.id,
                      builder: (categories, gameQuestionPoints, questions, emptyFields) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selectedFieldData.$1 != -1 && selectedFieldData.$2 != -1)
                              QuestionDisplay(
                                questionData: questions[selectedFieldData.$1][selectedFieldData.$2],
                                controllerView: true,
                                reveal: revealed,
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                for (var (cIndex, categoryName) in categories.indexed)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          Center(child: Text(categoryName)),
                                          for (var (qIndex, questionDoc) in questions[cIndex].indexed)
                                            Padding(
                                              padding: const EdgeInsets.all(4.0),
                                              child: ElevatedButton(
                                                onPressed: selectedFieldData == (cIndex, qIndex)
                                                    ? () {
                                                        sessionRef.update({
                                                          currentState: HomePageState.overview.name,
                                                          selectedField: "-1:-1",
                                                        });
                                                      }
                                                    : playedFieldsList.contains((cIndex, qIndex))
                                                        ? () {
                                                            sessionRef.update({
                                                              playedFields: FieldValue.arrayRemove(["$cIndex:$qIndex"])
                                                            });
                                                          }
                                                        : () {
                                                            sessionRef.update({
                                                              currentState: HomePageState.question.name,
                                                              selectedField: "$cIndex:$qIndex",
                                                              playedFields: FieldValue.arrayUnion([
                                                                if (selectedFieldData.$1 != -1)
                                                                  "${selectedFieldData.$1}:${selectedFieldData.$2}"
                                                              ])
                                                            });
                                                          },
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor: selectedFieldData == (cIndex, qIndex)
                                                        ? Theme.of(context).colorScheme.primaryContainer
                                                        : playedFieldsList.contains((cIndex, qIndex))
                                                            ? Theme.of(context).colorScheme.surface
                                                            : Theme.of(context).colorScheme.surfaceContainerHigh),
                                                child: Text(questionDoc[pointsPlus].toString()),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (state == HomePageState.questionBuzzered)
                                  ElevatedButton(
                                      onPressed: () async {
                                        var currentQuestion = questions[selectedFieldData.$1][selectedFieldData.$2];
                                        if (buzzeredTeam != null && currentQuestion[pointsPlus] != null) {
                                          pointsList[buzzeredTeam] += (currentQuestion[pointsPlus] as num).toInt();
                                        }
                                        sessionRef.update({
                                          currentState: HomePageState.overview.name,
                                          selectedField: "-1:-1",
                                          playedFields: FieldValue.arrayUnion([
                                            if (selectedFieldData.$1 != -1)
                                              "${selectedFieldData.$1}:${selectedFieldData.$2}"
                                          ]),
                                          points: pointsList
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.harmonizeWith(Theme.of(context).colorScheme.primary)),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check),
                                          Text("Answer right"),
                                        ],
                                      )),
                                if (state == HomePageState.questionBuzzered)
                                  ElevatedButton(
                                      onPressed: () async {
                                        var currentQuestion = questions[selectedFieldData.$1][selectedFieldData.$2];
                                        if (buzzeredTeam != null && currentQuestion[pointsMinus] != null) {
                                          pointsList[buzzeredTeam] -=
                                              ((currentQuestion as Map?)![pointsMinus] as num).toInt();
                                        }
                                        sessionRef.update({
                                          currentState: HomePageState.question.name,
                                          playedFields: FieldValue.arrayUnion([
                                            if (selectedFieldData.$1 != -1)
                                              "${selectedFieldData.$1}:${selectedFieldData.$2}"
                                          ]),
                                          points: pointsList
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).colorScheme.error),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.close),
                                          Text("Answer wrong"),
                                        ],
                                      )),
                                if (state != HomePageState.overview)
                                  ElevatedButton(
                                      onPressed: () async {
                                        sessionRef.update({
                                          currentState: HomePageState.overview.name,
                                          selectedField: "-1:-1",
                                          playedFields: FieldValue.arrayUnion([
                                            if (selectedFieldData.$1 != -1)
                                              "${selectedFieldData.$1}:${selectedFieldData.$2}"
                                          ]),
                                        });
                                      },
                                      child: const Text("Close question")),
                                if (state == HomePageState.questionBuzzered)
                                  if (selectedFieldData != (-1, -1))
                                    ElevatedButton(
                                        onPressed: () {
                                          sessionRef.update({currentState: HomePageState.question.name});
                                        },
                                        child: const Text("Reopen Question")),
                                if (state == HomePageState.question) ...[
                                  for (var (index, team) in teamsList.indexed)
                                    ElevatedButton(
                                        onPressed: () {
                                          sessionRef.update(
                                              {buzzeredFrom: index, currentState: HomePageState.questionBuzzered.name});
                                        },
                                        child: Text("Buzzer Team $team"))
                                ],
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          SettingsSubPageCategory(
            title: "Teams",
            settings: [
              StreamBuilder(
                stream:
                    FirebaseFirestore.instance.collection(sessions).doc(prefs.getString("currentSession")).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    if (snapshot.data!.data() != null && snapshot.data!.data()![teams] != null) {
                      List<String> teamsList = List.from(snapshot.data!.data()![teams]);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (index, team) in teamsList.indexed)
                            ListTile(
                                title: Text(team),
                                subtitle: Text("Points: ${snapshot.data![points][index]}"),
                                leading: Icon(Icons.group),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection(sessions)
                                        .doc(prefs.getString("currentSession"))
                                        .update({
                                      teams: teamsList..removeAt(index),
                                      points: List.from(snapshot.data![points])..removeAt(index)
                                    });
                                    setState(() {});
                                  },
                                )),
                        ],
                      );
                    } else {
                      return const ListTile(
                        title: Text("No teams"),
                        leading: Icon(Icons.group),
                      );
                    }
                  } else {
                    return const ListTile(
                      title: Text("Teams Loading..."),
                      leading: Icon(Icons.group),
                    );
                  }
                },
              ),
              ListTile(
                title: const Text("Create new team"),
                leading: const Icon(Icons.add),
                subtitle: const Text("Create a new empty team"),
                onTap: () async {
                  await showDialog(
                      context: context,
                      builder: (context) {
                        TextEditingController controller = TextEditingController();
                        return AlertDialog(
                          title: const Text("Create new team"),
                          content: TextField(
                            controller: controller,
                            decoration: const InputDecoration(labelText: "Team Name"),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text("Abbrechen")),
                            TextButton(
                                onPressed: () async {
                                  var docRef = FirebaseFirestore.instance
                                      .collection(sessions)
                                      .doc(prefs.getString("currentSession"));
                                  var doc = await docRef.get();
                                  if (List.from(doc.data()?[teams] ?? []).contains(controller.text)) return;
                                  await docRef.update({
                                    teams: doc.data()?[teams] != null
                                        ? (List.from(doc.data()![teams])..add(controller.text))
                                        : [controller.text],
                                    points: doc.data()?[points] != null ? (List.from(doc.data()![points])..add(0)) : [0]
                                  });
                                  Navigator.of(context).pop();
                                  setState(() {});
                                },
                                child: const Text("Bestätigen")),
                          ],
                        );
                      });
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
