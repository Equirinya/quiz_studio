import 'dart:math';

import 'package:flutter/material.dart';

import '../database/constants.dart';

class QuestionDisplay extends StatelessWidget {
  const QuestionDisplay({
    super.key,
    required this.questionData,
    this.controllerView = false,
    required this.reveal,
  });

  final Map<String, dynamic> questionData;
  final bool controllerView;
  final int reveal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Badge(
            alignment: Alignment.topLeft,
            isLabelVisible: questionData[description] != null && questionData[description].isNotEmpty,
            label: (questionData[description]) != null
                ? Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(questionData[description], style: const TextStyle(fontSize: 16)),
                  )
                : null,
            largeSize: 32,
            child: Card(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width * 0.6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      textAlign: TextAlign.center,
                      questionData[question] ?? "",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                )),
          ),
          if (questionData[type] == QuestionType.progressingReveal)
            Builder(
              builder: (context) {
                var root = sqrt(questionData[information].length);
                int columns = root < 4 ? root.ceil() : root.floor();
                return Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (var (i, information) in questionData[information].indexed)
                      SizedBox(
                        width: MediaQuery.of(context).size.width / columns - 16,
                        child: Visibility(
                          visible: i < reveal,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: Card(
                            color: controllerView && i >= reveal
                                ? Theme.of(context).colorScheme.surfaceContainerLowest
                                : Theme.of(context).colorScheme.surfaceContainerLow,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                information,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (questionData[type] == QuestionType.progressingReveal)
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (var (i, answer) in questionData[answers].indexed)
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 2 - 16,
                    child: Visibility(
                      visible: i < reveal,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: Card(
                        color: controllerView && i >= reveal
                            ? Theme.of(context).colorScheme.surfaceContainerLowest
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (controllerView || reveal >= questionData[answers].length)
                                Icon(questionData[answersCorrect][i] ? Icons.check : Icons.close),
                              Text(
                                answer,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          if(controllerView && questionData[answerHint] != null && questionData[answerHint].isNotEmpty) Card(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width * 0.6,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    textAlign: TextAlign.center,
                    questionData[answerHint] ?? "",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ))
        ],
      ),
    );
  }
}
