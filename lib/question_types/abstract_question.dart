import 'dart:io';

import 'package:flutter/material.dart';
import 'package:quiz_show/question_types/question_abcd.dart';
import 'package:quiz_show/question_types/question_free.dart';
import 'package:quiz_show/question_types/question_progressing_reveal.dart';
import 'package:quiz_show/question_types/question_unsupported.dart';

import '../database/constants.dart';

enum QuestionType {
  free("Free Question"),
  abcd("ABCD"),
  progressingReveal("Progressing Reveal"),
  unsupported("Unsupported");

  final String uiString;
  Question instanceQuestion(Map<String, dynamic> data) => Question.fromType(this, data);

  const QuestionType(this.uiString);
  factory QuestionType.fromString(String? type) => QuestionType.values.firstWhere((element) => element.name == type, orElse: () => QuestionType.unsupported);
}

abstract class Question{
  final Map<String, dynamic> data;

  List<Widget> controlButtons(dynamic gameState);

  Widget questionWidget({required BuildContext context, required Directory gameDir,bool controllerView = false, required Map<String,dynamic> sessionData}) => BaseQuestionCard(questionData: data, controllerView: controllerView, gameDir: gameDir);
  double questionHeightPercentage(){
    double questionfactor = 0.1;
    if (data[image] != null &&
        data[image]!.isNotEmpty) {
      questionfactor += 0.4;
    }
    // else if (data[music] != null &&
    //     data!.isNotEmpty) {
    //   questionfactor += 0.2;
    // }
    return questionfactor;
  }

  List<Widget> inputWidgets(BuildContext context, Future<void> Function(Map<String, dynamic> data) update, VoidCallback refresh);

  bool buzzerable() => true;

  abstract String explainString;

  String asText() => """Points if correct: ${data[pointsPlus] ?? 0}, Points if wrong: ${data[pointsMinus] ?? 0}
  ${data[question]}${data[image] != null && data[image] is String && (data[image] as String).isNotEmpty ? " includes image" : ""}${data[image] != null && data[music] is String && (data[music] as String).isNotEmpty ? " includes sound" : ""} 
  ${data[description] != null && data[description] is String && (data[description] as String).isNotEmpty ? "Description: ${data[description]}" : ""}
  ${data[answerHint] != null && data[answerHint] is String && (data[answerHint] as String).isNotEmpty ? "Answer hint: ${data[answerHint]}" : ""}""";
  @override
  String toString() => "QuestionType: ${asText()}";

  factory Question.fromType(QuestionType? type, Map<String, dynamic> data){
    switch(type){
      case QuestionType.free:
        return FreeQuestion(data);
      case QuestionType.abcd:
        return ABCDQuestion(data);
      case QuestionType.progressingReveal:
        return ProgressingRevealQuestion(data);
      default:
        return UnsupportedQuestion(data);
    }
  }

  factory Question.fromData(Map<String, dynamic> data) => Question.fromType(QuestionType.fromString(data[type]), data);

  Question(this.data);
}

class BaseQuestionCard extends StatelessWidget {

//TODO waveforms: https://trac.ffmpeg.org/wiki/Waveform https://github.com/arthenica/ffmpeg-kit/issues/8#issuecomment-2126598680

  const BaseQuestionCard({
    super.key,
    required this.questionData,
    required this.controllerView,
    required this.gameDir,
  });

  final Map<String, dynamic> questionData;
  final bool controllerView;
  final Directory gameDir;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox(
      width: size.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Badge(
            alignment: Alignment.topLeft,
            isLabelVisible: questionData[description] != null && questionData[description].isNotEmpty,
            label: (questionData[description]) != null
                ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
              child: Text(questionData[description], style: TextStyle(fontSize: controllerView ? 16 : size.height*0.03)),
            )
                : null,
            largeSize: controllerView ? 32 : size.height * 0.06,
            offset: Offset(-size.width*0.03, -(controllerView ? 24.0 :size.height * 0.025)),
            child: Card(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: size.width * 0.6,
                    maxWidth: size.width * 0.9,
                    minHeight: size.height * 0.1,
                    maxHeight: size.height * 0.5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if(questionData[image] != null && questionData[image].isNotEmpty)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: controllerView ? size.width * 0.5 : size.width * 0.7,
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                            child: Image.file(
                              File('${gameDir.absolute.path}/${questionData[image]}'),
                              errorBuilder: (context, error, stackTrace) => const SizedBox(),
                              height: size.height * 0.55,
                            ),
                          ),
                        ),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                textAlign: TextAlign.center,
                                maxLines: controllerView? 10 : (questionData[image] != null && questionData[image].isNotEmpty) ? 4 : 2,
                                overflow: TextOverflow.ellipsis,
                                questionData[question]?? "",
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: controllerView ? null : size.height*0.04),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ),
          if(controllerView && questionData[answerHint] != null && questionData[answerHint].isNotEmpty) Card(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width * 0.6,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    textAlign: TextAlign.center,
                    questionData[answerHint] ?? "",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ))
        ],
      ),
    );
  }
}
