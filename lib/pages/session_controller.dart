import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
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
  late Directory appSupportDir;
  bool initialized = false;
  (int, int) preview = (-1, -1);

  @override
  void initState() {
    () async {
      prefs = await SharedPreferences.getInstance();
      appSupportDir = await getApplicationSupportDirectory();
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
                        fallback: noSession,
                        callback: (value) => setState(() {

                        }),
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
          SettingsSubPageCategory(
            title: "Game Controller",
            settings: [
              SessionStreamBuilder(
                key: ValueKey(prefs.getString("currentSession")),
                session: prefs.getString("currentSession"),
                builder: (teamsList, pointsList, selectedFieldData, state, playing, buzzeredTeam, playedFieldsList,
                    revealedAnswers, buzzerSensitivityMap, buzzerTeamMap, gameRef, sessionRef) {
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
                                  child: Column(
                                    children: [
                                      Text(
                                        team,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(left: 16.0),
                                            child: Text(
                                              (pointsList[index] ?? 0).toString(),
                                              style: Theme.of(context).textTheme.headlineSmall,
                                            ),
                                          ),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                  onPressed: () async {
                                                    pointsList[index] += 100;
                                                    sessionRef.update({
                                                      points: pointsList,
                                                    });
                                                  },
                                                  child: const Text("+100")),
                                              TextButton(
                                                  onPressed: () async {
                                                    pointsList[index] -= 100;
                                                    sessionRef.update({
                                                      points: pointsList,
                                                    });
                                                  },
                                                  child: const Text("-100"))
                                            ],
                                          )
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        if(gameRef == null) const Center(
                          child: Text("No game selected"),
                        )
                        else GameStreamBuilder(
                          key: ValueKey(gameRef.id),
                          gameId: gameRef.id,
                          builder: (categories, gameQuestionPoints, questions, emptyFields) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    for (var (cIndex, categoryName) in categories.indexed)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: <Widget>[
                                              Center(
                                                  child: Text(categoryName, maxLines: 1, overflow: TextOverflow.clip)),
                                              for (var (qIndex, questionDoc) in questions[cIndex].indexed)
                                                Padding(
                                                  padding: const EdgeInsets.all(2.0),
                                                  child: ElevatedButton(
                                                    onPressed: questionDoc.isEmpty
                                                        ? null
                                                        : selectedFieldData == (cIndex, qIndex)
                                                            ? () {
                                                                sessionRef.update({
                                                                  currentState: HomePageState.overview.name,
                                                                  selectedField: "-1:-1",
                                                                  revealed: 0,
                                                                });
                                                                preview = (-1, -1);
                                                              }
                                                            : playedFieldsList.contains((cIndex, qIndex))
                                                                ? () {
                                                                    sessionRef.update({
                                                                      playedFields:
                                                                          FieldValue.arrayRemove(["$cIndex:$qIndex"])
                                                                    });
                                                                  }
                                                                : preview != (cIndex, qIndex)
                                                                    ? () => setState(() {
                                                                          preview = (cIndex, qIndex);
                                                                        })
                                                                    : () {
                                                                        preview = (-1, -1);
                                                                        sessionRef.update({
                                                                          currentState: HomePageState.question.name,
                                                                          selectedField: "$cIndex:$qIndex",
                                                                          revealed: 0,
                                                                          playingFrom: null,
                                                                          playedFields: FieldValue.arrayUnion([
                                                                            if (selectedFieldData.$1 != -1)
                                                                              "${selectedFieldData.$1}:${selectedFieldData.$2}"
                                                                          ])
                                                                        });
                                                                      },
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor: selectedFieldData == (cIndex, qIndex)
                                                            ? Theme.of(context).colorScheme.primaryContainer
                                                            : playedFieldsList.contains((cIndex, qIndex)) ||
                                                                    questionDoc.isEmpty
                                                                ? Theme.of(context).colorScheme.surface
                                                                : preview != (cIndex, qIndex)
                                                                    ? Theme.of(context).colorScheme.surfaceContainerHigh
                                                                    : Theme.of(context)
                                                                        .colorScheme
                                                                        .surfaceContainerHighest,
                                                        padding: const EdgeInsets.all(8)),
                                                    child: Text(questionDoc.isNotEmpty
                                                        ? questionDoc[pointsPlus].toString()
                                                        : "-"),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 16,
                                ),
                                if ((selectedFieldData.$1 != -1 && selectedFieldData.$2 != -1) ||
                                    (preview.$1 != -1 && preview.$2 != -1))
                                  QuestionDisplay(
                                    gameId: gameRef.id,
                                    questionData: (selectedFieldData.$1 != -1 && selectedFieldData.$2 != -1)
                                        ? questions[selectedFieldData.$1][selectedFieldData.$2]
                                        : questions[preview.$1][preview.$2],
                                    controllerView: true,
                                    reveal: revealedAnswers,
                                    appSupportDir: appSupportDir,
                                  ),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (state == HomePageState.overview)
                                      ElevatedButton(
                                          onPressed: () {
                                            sessionRef.update({currentState: HomePageState.buzzerTest.name});
                                          },
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.tune),
                                              Text("Buzzer Test"),
                                            ],
                                          ))
                                    else if (state == HomePageState.buzzerTest)
                                      ElevatedButton(
                                          onPressed: () {
                                            sessionRef.update({currentState: HomePageState.overview.name});
                                          },
                                          child: const Text("Stop Buzzer Test")),
                                    if (state == HomePageState.questionBuzzered) ...[
                                      ElevatedButton(
                                          onPressed: () async {
                                            var currentQuestion = questions[selectedFieldData.$1][selectedFieldData.$2];
                                            if (buzzeredTeam != null && currentQuestion[pointsPlus] != null) {
                                              pointsList[buzzeredTeam] += (currentQuestion[pointsPlus] as num).toInt();
                                            }
                                            sessionRef.update({
                                              currentState: HomePageState.overview.name,
                                              selectedField: "-1:-1",
                                              revealed: 0,
                                              playedFields: FieldValue.arrayUnion([
                                                if (selectedFieldData.$1 != -1)
                                                  "${selectedFieldData.$1}:${selectedFieldData.$2}"
                                              ]),
                                              points: pointsList
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: (Theme.of(context).brightness == Brightness.dark
                                                      ? Colors.green[800]!
                                                      : Colors.green[300]!)
                                                  .harmonizeWith(Theme.of(context).colorScheme.primary)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check,
                                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                              ),
                                              Text("Answer right",
                                                  style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onPrimaryContainer)),
                                            ],
                                          )),
                                      ElevatedButton(
                                          onPressed: () async {
                                            var currentQuestion = questions[selectedFieldData.$1][selectedFieldData.$2];
                                            if (buzzeredTeam != null && currentQuestion[pointsMinus] != null) {
                                              pointsList[buzzeredTeam] -=
                                                  ((currentQuestion as Map?)![pointsMinus] as num).toInt();
                                            }
                                            sessionRef.update({
                                              currentState: HomePageState.question.name,
                                              points: pointsList,
                                              if (questions[selectedFieldData.$1][selectedFieldData.$2][music] !=
                                                      null &&
                                                  questions[selectedFieldData.$1][selectedFieldData.$2][music]
                                                      .isNotEmpty)
                                                playingFrom: true,
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(context).colorScheme.errorContainer),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.close, color: Theme.of(context).colorScheme.onErrorContainer),
                                              Text("Answer wrong",
                                                  style:
                                                      TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                                            ],
                                          )),
                                    ],
                                    if (state == HomePageState.questionBuzzered)
                                      if (selectedFieldData != (-1, -1))
                                        ElevatedButton(
                                            onPressed: () {
                                              sessionRef.update({
                                                currentState: HomePageState.question.name,
                                                if (questions[selectedFieldData.$1][selectedFieldData.$2][music] !=
                                                        null &&
                                                    questions[selectedFieldData.$1][selectedFieldData.$2][music]
                                                        .isNotEmpty)
                                                  playingFrom: true,
                                              });
                                            },
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.undo),
                                                Text("Reopen Question"),
                                              ],
                                            )),
                                    if (state == HomePageState.question) ...[
                                      for (var (index, team) in teamsList.indexed)
                                        ElevatedButton(
                                            onPressed: () {
                                              sessionRef.update({
                                                buzzeredFrom: index,
                                                currentState: HomePageState.questionBuzzered.name
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(8)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(MdiIcons.bullseye),
                                                Text("Buzzer $team"),
                                              ],
                                            ))
                                    ],
                                    if ((state == HomePageState.questionBuzzered || state == HomePageState.question) &&
                                        selectedFieldData.$1 != -1 &&
                                        (questions[selectedFieldData.$1][selectedFieldData.$2][music] != null &&
                                            questions[selectedFieldData.$1][selectedFieldData.$2][music]
                                                .isNotEmpty)) ...[
                                      if (playing == null || !playing)
                                        ElevatedButton(
                                            onPressed: () {
                                              sessionRef.update({
                                                playingFrom: true,
                                              });
                                            },
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.play_circle),
                                                Text("Play"),
                                              ],
                                            ))
                                      else ...[
                                        ElevatedButton(
                                            onPressed: () {
                                              sessionRef.update({
                                                playingFrom: false,
                                              });
                                            },
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.pause_circle),
                                                Text("Pause"),
                                              ],
                                            )),
                                        ElevatedButton(
                                            onPressed: () {
                                              sessionRef.update({
                                                playingFrom: null,
                                              });
                                            },
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.stop_circle),
                                                Text("Stop"),
                                              ],
                                            ))
                                      ]
                                    ],
                                    if ((state == HomePageState.questionBuzzered || state == HomePageState.question) &&
                                        selectedFieldData.$1 != -1 &&
                                        (questions[selectedFieldData.$1][selectedFieldData.$2][type] ==
                                                QuestionType.abcd.name ||
                                            questions[selectedFieldData.$1][selectedFieldData.$2][type] ==
                                                QuestionType.progressingReveal.name)) ...[
                                      ElevatedButton(
                                          onPressed: revealedAnswers > 0
                                              ? () {
                                                  sessionRef.update({
                                                    revealed: FieldValue.increment(-1),
                                                  });
                                                }
                                              : null,
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.navigate_before),
                                              Text("Unreveal"),
                                            ],
                                          )),
                                      ElevatedButton(
                                          onPressed: () {
                                            sessionRef.update({
                                              revealed: FieldValue.increment(1),
                                            });
                                          },
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text("Reveal"),
                                              Icon(Icons.navigate_next),
                                            ],
                                          ))
                                    ],
                                    if (state == HomePageState.questionBuzzered || state == HomePageState.question)
                                      ElevatedButton(
                                          onPressed: () async {
                                            sessionRef.update({
                                              currentState: HomePageState.overview.name,
                                              selectedField: "-1:-1",
                                              revealed: 0,
                                              playedFields: FieldValue.arrayUnion([
                                                if (selectedFieldData.$1 != -1)
                                                  "${selectedFieldData.$1}:${selectedFieldData.$2}"
                                              ]),
                                            });
                                          },
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.close),
                                              Text("Close question"),
                                            ],
                                          )),
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
              )
            ],
          ),
          SettingsSubPageCategory(
            title: "Teams",
            settings: prefs.getString("currentSession") == null
                ? const [
                    ListTile(
                      title: Text("No session selected"),
                    )
            ]
                :
            [
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
                                leading: const Icon(Icons.group),
                                onTap: () async {
                                  await showDialog(
                                      context: context,
                                      builder: (context) {
                                        TextEditingController controller = TextEditingController(text: team);
                                        return AlertDialog(
                                          icon: const Icon(Icons.edit),
                                          title: const Text("Edit team name"),
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
                                                        ? (List.from(doc.data()![teams])..[index] = controller.text)
                                                        : [controller.text],
                                                  });
                                                  Navigator.of(context).pop();
                                                },
                                                child: const Text("Bestätigen")),
                                          ],
                                        );
                                      });
                                  setState(() {});
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    await showDialog(context: context, builder: (context) => AlertDialog(
                                      icon: const Icon(Icons.warning),
                                      title: const Text("Delete team"),
                                      content: Text("Do you really want to delete the team $team?"),
                                      actions: [
                                        TextButton(
                                            onPressed: () async {
                                              await FirebaseFirestore.instance
                                                  .collection(sessions)
                                                  .doc(prefs.getString("currentSession"))
                                                  .update({
                                                teams: teamsList..removeAt(index),
                                                points: List.from(snapshot.data![points])..removeAt(index)
                                              });
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text("Yes")),
                                        ElevatedButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text("No")),
                                      ],
                                    ));
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
