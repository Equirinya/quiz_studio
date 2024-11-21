//TODO add music and images
//TODO if images are revealed show add option to show them large as diashow
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:quiz_show/question_types/abstract_question.dart';

import '../database/constants.dart';

class ProgressingRevealQuestion extends Question {
  ProgressingRevealQuestion(super.data);

  @override
  String explainString = """This question type lets the gamemaster piece by piece reveal more information.""";

  @override
  String asText() => """${super.asText()}
  Information to be revealed:
  ${data[information] is! List<String> ? "" : (data[information] as List<String>).indexed.map((e) => "(${e.$1 + 1}) ${e.$2}").join('\n')}""";

  @override
  List<Widget> controlButtons(gameState) => [];

  @override
  List<Widget> inputWidgets(
          BuildContext context, Future<void> Function(Map<String, dynamic> data) update, VoidCallback refresh) =>
      [
        const SizedBox(
          height: 16,
        ),
        Text("Information",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
        for (final (i, String informationString) in (List<String>.from(data[information] ?? [])).indexed)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: informationString),
                    decoration: InputDecoration(
                      labelText: "Information ${i + 1}",
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) async {
                      // List<String> currentInfos =
                      // List<String>.from((await doc.reference.get()).data()?[information] ?? []);
                      // if (currentInfos.length <= i) {
                      //   setState(() {});
                      //   return;
                      // }
                      // currentInfos[i] = value;
                      // doc.reference.update({
                      //   information: currentInfos,
                      // });
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
                    // List<String> currentInfos =
                    //     List<String>.from((await doc.reference.get()).data()?[information] ?? []);
                    // currentInfos.removeAt(i);
                    // doc.reference.update({
                    //   information: currentInfos,
                    // }).then((value) => setState(() {}));
                    data[information].removeAt(i);
                    await update({
                      information: data[information],
                    });
                    refresh();
                  },
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () async {
              data[information] ??= [];
              data[information].add("");
              await update({
                information: data[information],
              });
              refresh();
              // List<String> currentInfos = List<String>.from((await doc.reference.get()).data()?[information] ?? []);
              // doc.reference.update({
              //   information: currentInfos..add(""),
              // }).then((value) => setState(() {}));
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Add Information"),
            ),
          ),
        ),
      ];

  @override
  double questionHeightPercentage() {
    double questionfactor = super.questionHeightPercentage();
    int informationLength = data[information]?.length ?? 0;
    var root = sqrt(informationLength);
    int columns = root < 4 ? root.ceil() : root.floor();
    int rows = (informationLength / columns).ceil();
    questionfactor += 0.08 * rows;
    return questionfactor;
  }

  @override
  Widget questionWidget(
      {required BuildContext context,
      required Directory gameDir,
      bool controllerView = false,
      required Map<String, dynamic> sessionData}) {

    List<String> informationStrings = List<String>.from(data[information] ?? []);
    var root = sqrt(informationStrings.length);
    int columns = root < 4 ? root.ceil() : root.floor();
    var size = MediaQuery.of(context).size;
    int reveal = sessionData[revealed];

    return Column(children: [
      super
          .questionWidget(gameDir: gameDir, controllerView: controllerView, sessionData: sessionData, context: context),
      Wrap(
        alignment: WrapAlignment.center,
        children: [
          for (var (i, information) in informationStrings.indexed)
            SizedBox(
              width: size.width / columns - 16,
              height: controllerView ? null : size.height * 0.08,
              child: Visibility(
                visible: i < reveal || controllerView,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Card(
                  color: controllerView && i >= reveal
                      ? Theme.of(context).colorScheme.surfaceContainerLowest
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          maxLines: controllerView ? 10 : 2,
                          overflow: TextOverflow.ellipsis,
                          information,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontSize: controllerView ? null : size.height * 0.024 - 2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      )
    ]);
  }
}
