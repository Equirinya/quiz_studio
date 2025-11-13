import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quiz_show/database/game_stream.dart';
import 'package:quiz_show/pages/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/constants.dart';
import '../database/session_stream.dart';
import '../question_types/abstract_question.dart';

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
                        callback: (value) => setState(() {}),
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
                  await ref.set(<String, dynamic>{
                    game: "",
                    teams: [],
                    points: [],
                    currentState: HomePageState.overview.name,
                    selectedField: "-1:-1",
                    playedFields: [],
                    information: [],
                  }..addAll(resetSessionConfig));
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
                builder: (Map<String, dynamic> sessionData, teamsList, pointsList, selectedFieldData, selectedCategoryGroupIndex, state, playing,
                    enableBuzzerQueue, buzzeredTeam, playedFieldsList, revealed, buzzerSensitivityMap, buzzerTeamMap, gameRef, sessionRef) {
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        SwitchListTile(
                            dense: true,
                            title: Text("Queue Buzzers"),
                            value: enableBuzzerQueue,
                            onChanged: (value) => sessionRef.update({queueBuzzers: value})),
                        //Punktestände
                        Wrap(
                          spacing: 8,
                          children: [
                            for (var (index, team) in teamsList.indexed)
                              GestureDetector(
                                child: Card(
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
                                onLongPress: () => showDialog(
                                    context: context,
                                    builder: (context) {
                                      var textController = TextEditingController(text: (pointsList[index] ?? 0).toString());
                                      return AlertDialog(
                                        content: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                team,
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      TextButton(
                                                          onPressed: () async {
                                                            pointsList[index] -= 10;
                                                            sessionRef.update({
                                                              points: pointsList,
                                                            });
                                                            textController.text = pointsList[index].toString();
                                                          },
                                                          child: const Text("-10")),
                                                      TextButton(
                                                          onPressed: () async {
                                                            pointsList[index] -= 100;
                                                            sessionRef.update({
                                                              points: pointsList,
                                                            });
                                                            textController.text = pointsList[index].toString();
                                                          },
                                                          child: const Text("-100"))
                                                    ],
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 16.0),
                                                    child: SizedBox(
                                                      width: MediaQuery.of(context).size.width * 0.2,
                                                      child: TextField(
                                                        controller: textController,
                                                        autofocus: true,
                                                        maxLines: 1,
                                                        keyboardType: TextInputType.number,
                                                        style: Theme.of(context).textTheme.headlineSmall,
                                                        onSubmitted: (value) => sessionRef.update({
                                                          points: pointsList..[index] = int.tryParse((textController.text).trim()) ?? 0,
                                                        }),
                                                        onEditingComplete: () => sessionRef.update({
                                                          points: pointsList..[index] = int.tryParse((textController.text).trim()) ?? 0,
                                                        }),
                                                      ),
                                                    ),
                                                  ),
                                                  Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      TextButton(
                                                          onPressed: () async {
                                                            pointsList[index] += 10;
                                                            sessionRef.update({
                                                              points: pointsList,
                                                            });
                                                            textController.text = pointsList[index].toString();
                                                          },
                                                          child: const Text("+10")),
                                                      TextButton(
                                                          onPressed: () async {
                                                            pointsList[index] += 100;
                                                            sessionRef.update({
                                                              points: pointsList,
                                                            });
                                                            textController.text = pointsList[index].toString();
                                                          },
                                                          child: const Text("+100"))
                                                    ],
                                                  )
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                              ),
                          ],
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        if (gameRef == null)
                          const Center(
                            child: Text("No game selected"),
                          )
                        else
                          GameStreamBuilder(
                            key: ValueKey(gameRef.id),
                            gameId: gameRef.id,
                            builder: (categories, questions) {
                              var selectedCategoryType = categories[selectedCategoryGroupIndex].$1;
                              var selectedCategoryNames = categories[selectedCategoryGroupIndex].$2;
                              int categoryOffset = categories
                                  .sublist(0, selectedCategoryGroupIndex)
                                  .fold(0, (previousValue, element) => previousValue + element.$2.length);

                              if (selectedFieldData.$1 == -1 ||
                                  selectedFieldData.$1 > questions.length - 1 ||
                                  selectedFieldData.$2 > questions[selectedFieldData.$1].length - 1) {
                                selectedFieldData = (-1, -1);
                              }

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  SegmentedButton(
                                      segments: categories.indexed
                                          .map((e) =>
                                              ButtonSegment(value: e.$1, label: Text("${e.$1}. ${e.$2.$1.uiString}"), icon: Icon(e.$2.$1.icon)))
                                          .toList(),
                                      selected: {selectedCategoryGroupIndex},
                                      multiSelectionEnabled: false,
                                      emptySelectionAllowed: false,
                                      onSelectionChanged: (indices) => sessionRef.update({selectedCategoryGroup: indices.firstOrNull ?? 0})),
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      for (var (cIndex, categoryName) in selectedCategoryNames.indexed.map((e) => (e.$1 + categoryOffset, e.$2)))
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: <Widget>[
                                                Center(child: Text(categoryName, maxLines: 1, overflow: TextOverflow.clip)),
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
                                                                  }..addAll(resetSessionConfig));
                                                                  preview = (-1, -1);
                                                                }
                                                              : playedFieldsList.contains((cIndex, qIndex))
                                                                  ? () {
                                                                      sessionRef.update({
                                                                        playedFields: FieldValue.arrayRemove(["$cIndex:$qIndex"])
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
                                                                            playedFields: FieldValue.arrayUnion([
                                                                              if (selectedFieldData.$1 != -1)
                                                                                "${selectedFieldData.$1}:${selectedFieldData.$2}"
                                                                            ])
                                                                          }..addAll(resetSessionConfig));
                                                                        },
                                                      style: ElevatedButton.styleFrom(
                                                          backgroundColor: selectedFieldData == (cIndex, qIndex)
                                                              ? Theme.of(context).colorScheme.primaryContainer
                                                              : playedFieldsList.contains((cIndex, qIndex)) || questionDoc.isEmpty
                                                                  ? Theme.of(context).colorScheme.surface
                                                                  : preview != (cIndex, qIndex)
                                                                      ? Theme.of(context).colorScheme.surfaceContainerHigh
                                                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                                                          padding: const EdgeInsets.all(8)),
                                                      child: Text(questionDoc.isNotEmpty ? questionDoc[pointsPlus].toString() : "-"),
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
                                  if ((selectedFieldData.$1 != -1 && selectedFieldData.$2 != -1) || (preview.$1 != -1 && preview.$2 != -1))
                                    Question.fromData((selectedFieldData.$1 != -1 && selectedFieldData.$2 != -1)
                                            ? questions[selectedFieldData.$1][selectedFieldData.$2]
                                            : questions[preview.$1][preview.$2])
                                        .questionWidget(
                                            context: context,
                                            gameDir: Directory('${appSupportDir.absolute.path}/${gameRef.id}'),
                                            sessionData: sessionData,
                                            controllerView: true),
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
                                              if (buzzeredTeam.isNotEmpty && currentQuestion[pointsPlus] != null) {
                                                pointsList[buzzeredTeam.first] += (currentQuestion[pointsPlus] as num).toInt();
                                              }
                                              sessionRef.update({
                                                currentState: HomePageState.overview.name,
                                                selectedField: "-1:-1",
                                                playedFields: FieldValue.arrayUnion(
                                                    [if (selectedFieldData.$1 != -1) "${selectedFieldData.$1}:${selectedFieldData.$2}"]),
                                                points: pointsList
                                              }..addAll(resetSessionConfig));
                                            },
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    (Theme.of(context).brightness == Brightness.dark ? Colors.green[800]! : Colors.green[300]!)
                                                        .harmonizeWith(Theme.of(context).colorScheme.primary)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.check,
                                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                ),
                                                Text("Answer right", style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                                              ],
                                            )),
                                        ElevatedButton(
                                            onPressed: () async {
                                              var currentQuestion = questions[selectedFieldData.$1][selectedFieldData.$2];
                                              if (buzzeredTeam.isNotEmpty && currentQuestion[pointsMinus] != null) {
                                                pointsList[buzzeredTeam.first] -= ((currentQuestion as Map?)![pointsMinus] as num).toInt();
                                              }
                                              if (enableBuzzerQueue && buzzeredTeam.length > 1) {
                                                sessionRef.update({
                                                  buzzeredFrom: buzzeredTeam.sublist(1),
                                                  currentState: HomePageState.questionBuzzered.name,
                                                  points: pointsList,
                                                });
                                              } else {
                                                sessionRef.update({
                                                  currentState: HomePageState.question.name,
                                                  points: pointsList,
                                                  if (questions[selectedFieldData.$1][selectedFieldData.$2][music] != null &&
                                                      questions[selectedFieldData.$1][selectedFieldData.$2][music].isNotEmpty)
                                                    playingFrom: true,
                                                });
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.errorContainer),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.close, color: Theme.of(context).colorScheme.onErrorContainer),
                                                Text("Answer wrong", style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                                              ],
                                            )),
                                      ],
                                      if (state == HomePageState.questionBuzzered)
                                        if (selectedFieldData != (-1, -1))
                                          if (enableBuzzerQueue && buzzeredTeam.length > 1)
                                            ElevatedButton(
                                                onPressed: () {
                                                  sessionRef.update({
                                                    buzzeredFrom: buzzeredTeam.sublist(1),
                                                  });
                                                },
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.skip_next),
                                                    Text("Skip to next Buzzer"),
                                                  ],
                                                ))
                                          else
                                            ElevatedButton(
                                                onPressed: () {
                                                  sessionRef.update({
                                                    currentState: HomePageState.question.name,
                                                    if (questions[selectedFieldData.$1][selectedFieldData.$2][music] != null &&
                                                        questions[selectedFieldData.$1][selectedFieldData.$2][music].isNotEmpty)
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
                                      if (state == HomePageState.question || (state == HomePageState.questionBuzzered && enableBuzzerQueue)) ...[
                                        for (var (index, team) in teamsList.indexed.where((element) => !enableBuzzerQueue || !buzzeredTeam.contains(element.$1)))
                                          ElevatedButton(
                                              onPressed: () {
                                                sessionRef.update({buzzeredFrom: FieldValue.arrayUnion([index]), currentState: HomePageState.questionBuzzered.name});
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
                                              questions[selectedFieldData.$1][selectedFieldData.$2][music].isNotEmpty)) ...[
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
                                      if (state == HomePageState.questionBuzzered || state == HomePageState.question)
                                        ElevatedButton(
                                            onPressed: () async {
                                              sessionRef.update({
                                                currentState: HomePageState.overview.name,
                                                selectedField: "-1:-1",
                                                playedFields: FieldValue.arrayUnion(
                                                    [if (selectedFieldData.$1 != -1) "${selectedFieldData.$1}:${selectedFieldData.$2}"]),
                                              }..addAll(resetSessionConfig));
                                            },
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.close),
                                                Text("Close question"),
                                              ],
                                            )),
                                      if (selectedFieldData.$1 != -1)
                                        ...Question.fromData(questions[selectedFieldData.$1][selectedFieldData.$2])
                                            .controlButtons(sessionData, (value) => sessionRef.update(value)),
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
                : [
                    StreamBuilder(
                      stream: FirebaseFirestore.instance.collection(sessions).doc(prefs.getString("currentSession")).snapshots(),
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
                                                        var docRef =
                                                            FirebaseFirestore.instance.collection(sessions).doc(prefs.getString("currentSession"));
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
                                          await showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
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
                                        var docRef = FirebaseFirestore.instance.collection(sessions).doc(prefs.getString("currentSession"));
                                        var doc = await docRef.get();
                                        if (List.from(doc.data()?[teams] ?? []).contains(controller.text)) return;
                                        await docRef.update({
                                          teams:
                                              doc.data()?[teams] != null ? (List.from(doc.data()![teams])..add(controller.text)) : [controller.text],
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
