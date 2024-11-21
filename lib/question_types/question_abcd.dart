//TODO transform to accept other than 4 options and add music and images

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:quiz_show/question_types/abstract_question.dart';

import '../database/constants.dart';

class ABCDQuestion extends Question {
  ABCDQuestion(super.data);

  @override
  String explainString = """This question type shows right or wrong answer suggestions.
  The Gamemaster can slowly reveal those.""";

  @override
  String asText() => "${super.asText()}"
  "Possible answers:\n"
  "${data[answers] is! List ? "" : (List<String>.from(data[answers])).indexed.map((e) => "${data[answersCorrect]?[e.$1] is bool && data[answersCorrect]?[e.$1] ? "Correct:" : "Wrong:"} ${e.$2}\n").join()}";

  @override
  List<Widget> controlButtons(gameState) => [];

  @override
  List<Widget> inputWidgets(BuildContext context, void Function(Map<String, dynamic> data) update, VoidCallback refresh) => [
        const SizedBox(
          height: 16,
        ),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text("Answer ${i + 1}"),
                StatefulBuilder(builder: (context, setState) {
                  return Checkbox(
                    value: data[answersCorrect]?[i] ?? false,
                    onChanged: (value) {
                      // List<bool> oldList =
                      // List<bool>.from(data[answersCorrect] ?? [false, false, false, false]);
                      // oldList[i] = value ?? false;
                      // update({
                      //   answersCorrect: oldList,
                      // });
                      // await Future.delayed(const Duration(milliseconds: 10));
                      data[answersCorrect] ??= [false, false, false, false];
                      setState(() => data[answersCorrect]?[i] = value);
                      update({answersCorrect: data[answersCorrect]});
                    },
                  );
                }),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: data[answers]?[i]),
                    decoration: const InputDecoration(
                      labelText: "Answer",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      // List<String> currentAnswers = List<String>.from(
                      //     (await doc.reference.get()).data()?[answers] ?? ["", "", "", ""]);
                      // currentAnswers[i] = value;
                      // doc.reference.update({
                      //   answers: currentAnswers,
                      // });
                      data[answers] ??= ["", "", "", ""];
                      data[answers]?[i] = value;
                      update({answers: data[answers]});
                    },
                  ),
                ),
              ],
            ),
          ),
      ];

  @override
  double questionHeightPercentage() {
    return super.questionHeightPercentage() + 0.16; //TODO add calculations for images and different amount of answers
  }

  @override
  Widget questionWidget(
      {required BuildContext context, required Directory gameDir, bool controllerView = false, required Map<String, dynamic> sessionData}) {
    return Column(children: [
      super.questionWidget(gameDir: gameDir, controllerView: controllerView, sessionData: sessionData, context: context),
      Wrap(
        alignment: WrapAlignment.center,
        children: [
          for (var (i, answer) in List<String>.from(data[answers] ?? []).indexed)
            SizedBox(
              width: MediaQuery.of(context).size.width / 2 - 16,
              height: controllerView ? null : MediaQuery.of(context).size.height * 0.08,
              child: Visibility(
                visible: i < sessionData[revealed] || controllerView,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Card(
                  color: controllerView && i >= sessionData[revealed]
                      ? Theme.of(context).colorScheme.surfaceContainerLowest
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Visibility(
                            visible: (controllerView || sessionData[revealed] > data[answers].length),
                            maintainSize: true,
                            maintainAnimation: true,
                            maintainState: true,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Icon(
                                data[answersCorrect][i] ? Icons.check : Icons.close,
                                color: controllerView && sessionData[revealed] <= data[answers].length
                                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                                    : null,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              answer,
                              textAlign: TextAlign.center,
                              maxLines: controllerView ? 10 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontSize: controllerView ? null : MediaQuery.of(context).size.height * 0.026 - 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      )
    ]);
  }
}
