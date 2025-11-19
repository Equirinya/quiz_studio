import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:quiz_show/question_types/abstract_question.dart';
import 'package:quiz_show/widgets/media_upload.dart';

import '../database/constants.dart';
import '../database/session_stream.dart';

class FamilyFeudQuestion extends Question {
  FamilyFeudQuestion(super.data);

  @override
  String explainString = """This question type is inspired by family feud and shows a list of possible answers.""";

  @override
  String asText() => "${super.asText()}"
      "Information to be revealed:\n"
      "${data[information] is! List ? "" : (List<String>.from(data[information])).indexed.map((e) => "(${(List<double>.from(data[informationPercentage]).elementAtOrNull(e.$1)) ?? "-"} %) ${e.$2}\n").join()}";

  @override
  bool showDefaultAnswerButtons() => false;

  @override
  List<Widget> controlButtons(BuildContext context, SessionData sessionData, Future<void> Function(Map<String, dynamic> data) update) {
    List<String> infoList = List<String>.from(data[information] ?? []);
    List<double> infoPercentageList = List<double>.from(data[informationPercentage] ?? []);
    List<int> revealedInfos = List<int>.from(sessionData.sessionData[revealedList] ?? []);
    int _wrongAttempts = sessionData.sessionData[wrongAttempts] ?? 0;
    HomePageState state = sessionData.state;
    int informationLength = infoList.length;
    int columns = informationLength <= 5 ? 1 : 2;
    int rows = (informationLength / columns).ceil();

    return [
      if (state == HomePageState.questionBuzzered)
        if(_wrongAttempts < 2)
        ElevatedButton(
            onPressed: () {
              update({
                wrongAttempts: FieldValue.increment(1),
              });
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close),
                Text("Wrong Answer"),
              ],
            ))
      else if (_wrongAttempts == 2)
      ElevatedButton(
          onPressed: () {
            update({
              wrongAttempts: FieldValue.increment(1),
            });
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close),
              Text("Wrong Answer -> Next Team"),
            ],
          ))
      else if (_wrongAttempts == 3)
            ...[ElevatedButton(
                onPressed: () {
                  double accumulatedAnswerPercentage = revealedInfos.map((e) => infoPercentageList[e]).fold(0.0, (previousValue, element) => previousValue + element);
                  int pointsToAward = (accumulatedAnswerPercentage*data[pointsPlus]).round();
                  var pointsList = sessionData.pointsList;
                  pointsList[sessionData.buzzeredTeam.first] = (pointsList[sessionData.buzzeredTeam.first]) + pointsToAward;
                  update({
                    wrongAttempts: 0,
                    revealedList: List<int>.generate(informationLength, (index) => index),
                    currentState: HomePageState.answerRevealed.name,
                    points: pointsList,
                  });
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close),
                    Text("Wrong Answer"),
                  ],
                )),
              ElevatedButton(
                  onPressed: () {
                    double accumulatedAnswerPercentage = revealedInfos.map((e) => infoPercentageList[e]).fold(0.0, (previousValue, element) => previousValue + element);
                    int pointsToAward = (accumulatedAnswerPercentage*data[pointsPlus]).round();
                    var pointsList = sessionData.pointsList;
                    int opponentTeamIndex = sessionData.buzzeredTeam.elementAtOrNull(1) ?? (sessionData.teamsList.length == 2 ? (1 - sessionData.buzzeredTeam.first) : -1);
                    if(opponentTeamIndex != -1) pointsList[opponentTeamIndex] = (pointsList[opponentTeamIndex]) + pointsToAward;

                    update({
                      wrongAttempts: 0,
                      revealedList: List<int>.generate(informationLength, (index) => index),
                      currentState: HomePageState.answerRevealed.name,
                      points: pointsList,
                    });
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check),
                      Text("Right Answer"),
                    ],
                  ))],
      if( _wrongAttempts >= 1 && state == HomePageState.questionBuzzered)
        ElevatedButton(
            onPressed: () {
              update({
                wrongAttempts: 0,
              });
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh),
                Text("Reset Wrong Answers"),
              ],
            )),
      if (state == HomePageState.questionBuzzered)
        SizedBox(
            width: double.maxFinite,
            height: rows*48,
            child: Wrap(
              direction: Axis.vertical,
              alignment: WrapAlignment.start,
              children: [
                for (var (i, information) in infoList.indexed)
                  SizedBox(
                    width: MediaQuery.of(context).size.width / (infoList.length <= 5 ? 1 : 2) - 16,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: revealedInfos.contains(i) ? Theme.of(context).colorScheme.primaryContainer : null,
                      ),
                      onPressed: revealedInfos.contains(i)
                          ? () {
                              revealedInfos.remove(i);
                              update({
                                revealedList: revealedInfos,
                              });
                            }
                          : () {
                              revealedInfos.add(i);
                              Map<String,dynamic> updateData = {
                                revealedList: revealedInfos,
                              };
                              double accumulatedAnswerPercentage = revealedInfos.map((e) => infoPercentageList[e]).fold(0.0, (previousValue, element) => previousValue + element);
                              int pointsToAward = (accumulatedAnswerPercentage*data[pointsPlus]).round();
                              var pointsList = sessionData.pointsList;

                              if(infoList.indexed.every((element) => revealedInfos.contains(element.$1))){
                                pointsList[sessionData.buzzeredTeam.first] = (pointsList[sessionData.buzzeredTeam.first]) + pointsToAward;
                                updateData[currentState] = HomePageState.answerRevealed.name;
                                updateData[points] = pointsList;
                              }
                              update(updateData);
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          children: [
                            Text(
                              '${infoPercentageList[i]}%',
                            ),
                            Expanded(
                              child: Text(
                                information,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ))
    ];
  }

  @override
  List<String?> mediaPaths() {
    return super.mediaPaths();
  }

  @override
  List<Widget> inputWidgets(BuildContext context, String gameId, Future<void> Function(Map<String, dynamic> data) update, VoidCallback refresh) {
    List<String> infoList = List<String>.from(data[information] ?? []);
    List<double> infoPercentageList = List<double>.from(data[informationPercentage] ?? []);
    return [
      const SizedBox(
        height: 16,
      ),
      Text("Answers:", style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
      ReorderableListView.builder(
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        buildDefaultDragHandles: false,
        itemBuilder: (context, i) => Padding(
          key: ValueKey("answers_${data[documentId]}_$i"),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: i,
                child: Icon(
                  Icons.drag_indicator,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: TextEditingController(text: infoPercentageList[i].toString()),
                  decoration: InputDecoration(
                    labelText: "Value ${i + 1}",
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) async {
                    data[informationPercentage] ??= [];
                    if (data[informationPercentage]!.length <= i) {
                      return;
                    }
                    data[informationPercentage]![i] = double.tryParse(value) ?? 0.0;
                    update({informationPercentage: data[informationPercentage]});
                  },
                ),
              ),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: infoList[i]),
                  decoration: InputDecoration(
                    labelText: "Information ${i + 1}",
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) async {
                    data[information] ??= [];
                    if (data[information]!.length <= i) {
                      return;
                    }
                    data[information]![i] = value;
                    update({information: data[information]});
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  data[information].removeAt(i);
                  data[informationPercentage].removeAt(i);
                  await update({information: data[information], informationPercentage: data[informationPercentage]});
                  refresh();
                },
              ),
            ],
          ),
        ),
        itemCount: infoList.length,
        onReorder: (oldIndex, newIndex) async {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final String item = infoList.removeAt(oldIndex);
          infoList.insert(newIndex, item);
          data[information] = infoList;
          data[informationPercentage].insert(newIndex, (data[informationPercentage] as List?)?.removeAt(oldIndex) ?? 0.0);
          await update({
            information: data[information],
            informationImage: data[informationPercentage],
          });
        },
        footer: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () async {
              data[information] ??= [];
              data[informationPercentage] ??= [];
              data[information].add("");
              data[informationPercentage].add(0.0);
              await update({
                information: data[information],
                informationPercentage: data[informationPercentage],
              });
              refresh();
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Add Information"),
            ),
          ),
        ),
      ),
    ];
  }

  @override
  double questionHeightPercentage() {
    double questionfactor;
    questionfactor = super.questionHeightPercentage();
    questionfactor += 0.05; //for the xxx
    int informationLength = data[information]?.length ?? 0;
    int columns = informationLength <= 5 ? 1 : 2;
    int rows = (informationLength / columns).ceil();
    questionfactor += 0.08 * rows;
    return questionfactor;
  }

  @override
  Widget questionWidget(
      {required BuildContext context, required Directory gameDir, bool controllerView = false, required Map<String, dynamic> sessionData}) {
    List<String> informationStrings = List<String>.from(data[information] ?? []);
    List<double> infoPercentages = List<double>.from(data[informationPercentage] ?? []);
    int columns = informationStrings.length <= 5 ? 1 : 2;
    int rows = (informationStrings.length / columns).ceil();
    var size = MediaQuery.of(context).size;
    List<int> revealedInfos = List<int>.from(sessionData[revealedList] ?? []);
    int _wrongAttempts = sessionData[wrongAttempts] ?? 0;

    return Column(children: [
      super.questionWidget(gameDir: gameDir, controllerView: controllerView, sessionData: sessionData, context: context),
      SizedBox(
        height: size.height * 0.06,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < _wrongAttempts; i++) Icon(Icons.close, color: Theme.of(context).colorScheme.error, size: size.height * 0.05),
          ],
        ),
      ),
      Visibility(
        visible: !controllerView,
        child: SizedBox(
          height: (size.height * 0.08*rows) + 8,
          child: Wrap(
            direction: Axis.vertical,
            alignment: WrapAlignment.start,
            children: [
              for (var (i, information) in informationStrings.indexed)
                SizedBox(
                  width: size.width / columns - 16,
                  height: size.height * 0.08,
                  child: Card(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: size.height * 0.1,
                            child: Visibility(
                              visible: revealedInfos.contains(i),
                              child: Center(
                                child: Text(
                                  '${infoPercentages[i]}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.bold, fontSize: controllerView ? null : size.height * 0.03 - 2, color: Theme.of(context).colorScheme.tertiary),
                                ),
                              ),
                            ),
                          ),
                          VerticalDivider(
                            thickness: 4,
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          Expanded(
                            child: Visibility(
                              visible: revealedInfos.contains(i),
                              child: Text(
                                information,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: controllerView ? null : size.height * 0.04 - 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      )
    ]);
  }
}
