import 'dart:io';

import 'package:flutter/material.dart';
import 'package:quiz_show/question_types/abstract_question.dart';

import '../database/constants.dart';

class FreeQuestion extends Question {
  FreeQuestion(super.data);

  @override
  String explainString = """This is the most basic question type with no answer options and no further information.
  The buzzers can be disabled, e.g. for estimation questions.""";

  @override
  bool buzzerable() => !(data[noBuzzer] is bool ? data[noBuzzer] : false);

  @override
  String asText() => "${super.asText()}${buzzerable() ? "" : " \nThe buzzers are disabled for this question."}";

  @override
  List<Widget> controlButtons(gameState) => [];

  @override
  List<Widget> inputWidgets(BuildContext context, void Function(Map<String, dynamic> data) update, VoidCallback refresh) => [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: StatefulBuilder(
              builder: (context, setState) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Disable buzzers"),
                      Switch(value: (data[noBuzzer] is bool ? data[noBuzzer] : false), onChanged: (value) {
                        update({noBuzzer: value});
                        setState(() => data[noBuzzer] = value);
                      },)
                    ],
                  )),
        )
      ];
}
