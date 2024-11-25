//TODO add music and images
//TODO if images are revealed show add option to show them large as diashow
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quiz_show/question_types/abstract_question.dart';
import 'package:quiz_show/widgets/media_upload.dart';

import '../database/constants.dart';

class ProgressingRevealQuestion extends Question {
  ProgressingRevealQuestion(super.data);

  @override
  String explainString = """This question type lets the gamemaster piece by piece reveal more information.""";

  @override
  String asText() => "${super.asText()}"
      "Information to be revealed:\n"
      "${data[information] is! List ? "" : (List<String>.from(data[information])).indexed.map((e) => "(${e.$1 + 1}) ${e
      .$2}\n").join()}";

  //TODO implement reveal buttons here and then add image scroll buttons
  //on reveal set image show to newest image
  @override
  List<Widget> controlButtons(Map<String, dynamic> sessionData, Future<void> Function(Map<String, dynamic> data) update) {
    int revealedInfos = sessionData[revealed];
    int imageFocus = sessionData[informationImageFocus] ?? 0;
    return [
      ElevatedButton(
          onPressed: revealedInfos > 0
              ? () {
            update({
              revealed: FieldValue.increment(-1),
              if(imageFocus > revealedInfos - 1)
                informationImageFocus: revealedInfos - 1,
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
          onPressed: revealedInfos <= (data[information]?.length ?? 0)
              ?
            () {
            update({
              revealed: FieldValue.increment(1),
              informationImageFocus: revealedInfos + 1,
            });
          } : null,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Reveal"),
              Icon(Icons.navigate_next),
            ],
          )),
      ElevatedButton(
          onPressed: revealedInfos > 0 && imageFocus > 0
              ? () {
            update({
              informationImageFocus: FieldValue.increment(-1),
            });
          }
              : null,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.navigate_before),
              Text("Image back"),
            ],
          )),
      ElevatedButton(
          onPressed: imageFocus < revealedInfos ? () {
            update({
              informationImageFocus: FieldValue.increment(1),
            });
          } : null,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Image next"),
              Icon(Icons.navigate_next),
            ],
          ))
    ];
  }

  @override
  List<String?> mediaPaths() {
    return super.mediaPaths()
      ..addAll(List<String?>.from(data[informationImage] ?? []))..addAll(List<String?>.from(data[informationMusic] ?? []));
  }

  @override
  List<Widget> inputWidgets(BuildContext context, String gameId,
      Future<void> Function(Map<String, dynamic> data) update, VoidCallback refresh) =>
      [
        const SizedBox(
          height: 16,
        ),
        Text("Information",
            style: Theme
                .of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Theme
                .of(context)
                .colorScheme
                .primary)),
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
                MediaUploadIconButton(uploadType: MediaUploadType.image,
                    gameId: gameId,
                    databaseMediaIndex: (data[informationImage] as List?)?.elementAtOrNull(i),
                    updateDB: (value) async {
                      data[informationImage] ??= [];
                      if (data[informationImage]!.length <= i) {
                        return;
                      }
                      data[informationImage]![i] = value;
                      await update({informationImage: data[informationImage]});
                      refresh();
                    }),
                MediaUploadIconButton(uploadType: MediaUploadType.music,
                    gameId: gameId,
                    databaseMediaIndex: (data[informationMusic] as List?)?.elementAtOrNull(i),
                    updateDB: (value) async {
                      data[informationMusic] ??= [];
                      if (data[informationMusic]!.length <= i) {
                        return;
                      }
                      data[informationMusic]![i] = value;
                      await update({informationMusic: data[informationMusic]});
                      refresh();
                    }),
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
              data[informationImage] ??= [];
              data[informationMusic] ??= [];
              data[information].add("");
              data[informationImage].add("");
              data[informationMusic].add("");
              await update({
                information: data[information],
                informationImage: data[informationImage],
                informationMusic: data[informationMusic],
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
    double questionfactor;
    if (data[informationImage] is List &&
        (data[informationImage] as List).any((e) => e != null && e is String && e.isNotEmpty)) {
      questionfactor = 0.1;
      questionfactor += 0.4;
      questionfactor += 0.2;
    }
    else {
      questionfactor = super.questionHeightPercentage();
      int informationLength = data[information]?.length ?? 0;
      var root = sqrt(informationLength);
      int columns = root < 4 ? root.ceil() : root.floor();
      int rows = (informationLength / columns).ceil();
      questionfactor += 0.08 * rows;
    }
    return questionfactor;
  }

  @override
  Widget questionWidget({required BuildContext context,
    required Directory gameDir,
    bool controllerView = false,
    required Map<String, dynamic> sessionData}) {
    if (data[informationImage] is List &&
        (data[informationImage] as List).any((e) => e != null && e is String && e.isNotEmpty)) {
      int reveal = sessionData[revealed] ?? 0;
      int? imageFocus = sessionData[informationImageFocus];
      List<String> informationImages = List<String>.from(data[informationImage] ?? []);
      String? imageOverride = imageFocus != null && imageFocus <= informationImages.length && imageFocus > 0
          ? informationImages[imageFocus - 1]
          : null;
      return Column(
        children: [
          BaseQuestionCard(questionData: data, sessionData: sessionData, controllerView: controllerView, gameDir: gameDir, imageOverride: imageOverride),
          SizedBox(
            height: MediaQuery
                .of(context)
                .size
                .height * 0.15,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var (i, informationImage) in informationImages.indexed)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: MediaQuery
                          .of(context)
                          .size
                          .width / max(informationImages.length+2, 7),
                      height: MediaQuery
                          .of(context)
                          .size
                          .width / max(informationImages.length+2, 7) / 16 * 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: i < reveal || controllerView ? Image.file(
                          File('${gameDir.absolute.path}/$informationImage'),
                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
                          fit: BoxFit.cover,
                          color: controllerView && i >= reveal ? Theme
                              .of(context)
                              .colorScheme
                              .surfaceContainerLowest.withAlpha(170) : null,
                          colorBlendMode: controllerView && i >= reveal ? BlendMode.srcOver   : null,
                        ) : Container(
                          color: Theme
                              .of(context)
                              .colorScheme
                              .surfaceContainerLow,
                          child: Center(
                            child: Text("?", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: MediaQuery
                                .of(context)
                                .size
                                .height*0.05)),
                          ),
                        )
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    else {
      List<String> informationStrings = List<String>.from(data[information] ?? []);
      var root = sqrt(informationStrings.length);
      int columns = root < 4 ? root.ceil() : root.floor();
      var size = MediaQuery
          .of(context)
          .size;
      int reveal = sessionData[revealed];

      return Column(
          children: [
            super
                .questionWidget(
                gameDir: gameDir, controllerView: controllerView, sessionData: sessionData, context: context),
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
                            ? Theme
                            .of(context)
                            .colorScheme
                            .surfaceContainerLowest
                            : Theme
                            .of(context)
                            .colorScheme
                            .surfaceContainerLow,
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
                                style: Theme
                                    .of(context)
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
}
