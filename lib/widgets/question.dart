import 'dart:io';
import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../database/constants.dart';

//TODO waveforms: https://trac.ffmpeg.org/wiki/Waveform

class QuestionDisplay extends StatelessWidget {
  const QuestionDisplay({
    super.key,
    required this.gameId,
    required this.questionData,
    this.controllerView = false,
    required this.reveal,
    required this.appSupportDir,
  });

  final String gameId;
  final Map<String, dynamic> questionData;
  final bool controllerView;
  final int reveal;
  final Directory appSupportDir;

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
                              File('${appSupportDir.absolute.path}/$gameId/${questionData[image]}'),
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
          if (questionData[type] == QuestionType.progressingReveal.name)
            Builder(
              builder: (context) {
                List<String> informationStrings = List<String>.from(questionData[information] ?? []);
                var root = sqrt(informationStrings.length);
                int columns = root < 4 ? root.ceil() : root.floor();
                return Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (var (i, information) in informationStrings.indexed)
                      SizedBox(
                        width: size.width / columns - 16,
                        height: controllerView ? null : size.height*0.08,
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
                                    maxLines: controllerView? 10 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    information,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: controllerView ? null :size.height*0.024 -2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (questionData[type] == QuestionType.abcd.name)
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (var (i, answer) in List<String>.from(questionData[answers] ?? []).indexed)
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 2 - 16,
                    height: controllerView ? null : size.height*0.08,
                    child: Visibility(
                      visible: i < reveal || controllerView,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: Card(
                        color: controllerView && i >= reveal
                            ? Theme.of(context).colorScheme.surfaceContainerLowest
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  Visibility(
                                    visible: (controllerView || reveal > questionData[answers].length),
                                    maintainSize: true,
                                    maintainAnimation: true,
                                    maintainState: true,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal:8.0),
                                      child: Icon(questionData[answersCorrect][i] ? Icons.check : Icons.close,
                                          color: controllerView && reveal <= questionData[answers].length?
                                              Theme.of(context).colorScheme.surfaceContainerHighest : null,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    answer,
                                    textAlign: TextAlign.center,
                                    maxLines: controllerView? 10 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: controllerView ? null : size.height*0.026 -2),
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
