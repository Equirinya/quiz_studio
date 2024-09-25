import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'constants.dart';

class GameStreamBuilder extends StatefulWidget {
  const GameStreamBuilder({
    super.key,
    required this.gameId,
    required this.builder,
    this.fallback = const Center(child: CupertinoActivityIndicator()),
  });

  final String? gameId;
  final Widget Function(List<String> categories, List<int> gameQuestionPoints,
      List<List<Map<String, dynamic>>> questions, List<(int, int)> emptyFields) builder;
  final Widget fallback;

  @override
  State<GameStreamBuilder> createState() => _GameStreamBuilderState();
}

class _GameStreamBuilderState extends State<GameStreamBuilder> {
  FirebaseFirestore db = FirebaseFirestore.instance;
  final storage = FirebaseStorage.instance.ref();
  StreamSubscription? categoryDocsListener;
  QuerySnapshot<Map<String, dynamic>>? categoryDocs;
  List<StreamSubscription?> questionDocsListeners = [];
  List<QuerySnapshot<Map<String, dynamic>>?> questionDocs = [];
  bool initialized = false;
  DateTime lastMediaDownload = DateTime.now().subtract(const Duration(days: 1));

  @override
  void initState() {
    if (widget.gameId == null || widget.gameId!.isEmpty) return;
    () async {
      categoryDocsListener = db
          .collection(games)
          .doc(widget.gameId)
          .collection(categories)
          .where(active, isEqualTo: true)
          .snapshots()
          .listen((event) {
        categoryDocs = event;
        for (var listener in questionDocsListeners) {
          listener?.cancel();
        }
        questionDocsListeners = [];
        questionDocs = [];
        for (var (i, categoryDoc) in categoryDocs!.docs.indexed) {
          questionDocsListeners.add(db
              .collection(games)
              .doc(widget.gameId)
              .collection(categories)
              .doc(categoryDoc.id)
              .collection(questions)
              .snapshots()
              .listen((event) {
            if (questionDocs.length <= i) {
              questionDocs.addAll(List.filled(i - questionDocs.length + 1, null));
            }
            questionDocs[i] = event;

            checkIfReadyAndSetState();
          }));
        }
        checkIfReadyAndSetState();
      });
    }
    ();
    super.initState();
  }

  void checkIfReadyAndSetState() {
    if (categoryDocs == null || questionDocs.length < categoryDocs!.docs.length || questionDocs.any((e) => e == null)) return;
    setState(() {
      initialized = true;
    });
  }

  @override
  void dispose() {
    categoryDocsListener?.cancel();
    for (var listener in questionDocsListeners) {
      listener?.cancel();
    }
    questionDocsListeners = [];
    questionDocs = [];
    super.dispose();
  }

  Future<void> downloadMedia() async {
    final Directory appSupportDir = await getApplicationSupportDirectory();
    await Directory("${appSupportDir.absolute.path}/${widget.gameId}").create(recursive: true);
    for (var (i, questionCategoryDoc) in questionDocs.indexed) {
      for(var questionDoc in questionCategoryDoc!.docs) {
        final imagePath = questionDoc.data()[image] as String?;
        final musicPath = questionDoc.data()[music] as String?;

        if (imagePath != null && imagePath.isNotEmpty) {
          final filePath = "${appSupportDir.absolute.path}/${widget.gameId}/$imagePath";
          final file = File(filePath);
          if (!(await file.exists())) {
            var imageRef = storage.child('game_${widget.gameId!}').child(imagePath);
            final downloadTask = imageRef.writeToFile(file);
            downloadTask.snapshotEvents.listen((event) {
              if (event.state == TaskState.success) {
                setState(() {});
              }
            });
          }
        }

        if (musicPath != null && musicPath.isNotEmpty) {
          final filePath = "${appSupportDir.absolute.path}/${widget.gameId}/$musicPath";
          final file = File(filePath);
          if (!(await file.exists())) {
            var musicRef = storage.child('game_${widget.gameId!}').child(musicPath);
            final downloadTask = musicRef.writeToFile(file);
            downloadTask.snapshotEvents.listen((event) {
              if (event.state == TaskState.success) {
                setState(() {});
              }
            });
          }
        }

        //TODO delete all files that are not in the database
      }
    }

  }

  @override
  Widget build(BuildContext context) {
    if (widget.gameId == null || widget.gameId!.isEmpty) return widget.fallback;
    if (!initialized) return widget.fallback;
    if(lastMediaDownload.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) downloadMedia();
    List<int> gameQuestionPoints = questionDocs
        .map((e) => e!.docs)
        .expand((e) => e)
        .map((e) => (e.data()[pointsPlus] ?? 0) as int)
        .toSet()
        .toList()
      ..sort((a, b) => a - b);
    List<String> categories = categoryDocs!.docs.map((e) => e.data()[name] as String).toList();
    List<List<Map<String, dynamic>>> questions = [];
    for(var i = 0; i < categories.length; i++) {
      questions.add([]);
    }
    List<(int, int)> emptyFields = [];
    for (var (i, questionCategoryDoc) in questionDocs.indexed) {
      for (var (j, int points) in gameQuestionPoints.indexed) {
        var questionDoc =
            questionCategoryDoc!
                .docs
                .where((element) => element.data()[pointsPlus] == points)
                .firstOrNull;
        if (questionDoc == null) {
          emptyFields.add((i, j));
          questions[i].add({});
        }
        else {
          questions[i].add(questionDoc.data());
        }
      }
    }
    return widget.builder(categories, gameQuestionPoints, questions, emptyFields);
  }
}
