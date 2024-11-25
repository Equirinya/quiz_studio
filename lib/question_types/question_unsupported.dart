import 'package:flutter/material.dart';
import 'package:quiz_show/question_types/abstract_question.dart';

class UnsupportedQuestion extends Question {
  @override
  String explainString = "The loaded question type is not supported by this version.\nTry updating quiz studio.";

  UnsupportedQuestion(super.data);

  @override
  List<Widget> controlButtons(Map<String, dynamic> sessionData, Future<void> Function(Map<String, dynamic> data) update) => [];

  @override
  List<Widget> inputWidgets(
          BuildContext context, String gameId, Future<void> Function(Map<String, dynamic> data) update, VoidCallback refresh) =>
      [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
            Text("This question type is not supported by this version.",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.error))
          ],
        )
      ];
}
