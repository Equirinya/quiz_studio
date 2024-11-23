import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quiz_show/question_types/abstract_question.dart';

import 'constants.dart';

class MediaDownloader {
  static final MediaDownloader _instance = MediaDownloader._internal();
  Map<String, DateTime> lastGameMediaDownload = {};
  final storage = FirebaseStorage.instance.ref();

  factory MediaDownloader() {
    return _instance;
  }

  MediaDownloader._internal();

  Future<void> downloadGameMedia(String gameId, List<QuerySnapshot<Map<String, dynamic>>?> questionDocs) async {
    if(lastGameMediaDownload[gameId]?.isAfter(DateTime.now().subtract(const Duration(minutes: 1))) ?? false) return;
    if(gameId.isEmpty) return;
    if(questionDocs.isEmpty) return;
    questionDocs = List.from(questionDocs);
    lastGameMediaDownload[gameId] = DateTime.now();
    final Directory appSupportDir = await getApplicationSupportDirectory();
    await Directory("${appSupportDir.absolute.path}/$gameId").create(recursive: true);
    for (var questionCategoryDoc in questionDocs) {
      for(var questionDoc in questionCategoryDoc!.docs) {
        for(var mediaPath in Question.fromData(questionDoc.data()).mediaPaths()) {
          if (mediaPath != null && mediaPath.isNotEmpty) {
            final filePath = "${appSupportDir.absolute.path}/$gameId/$mediaPath";
            final file = File(filePath);
            if (!(await file.exists())) {
              var mediaRef = storage.child('game_$gameId').child(mediaPath);
              print("Downloading media $mediaPath for question ${questionDoc.id}");
              final bytes = await mediaRef.getData();
              if (bytes == null) {
                if (kDebugMode) {
                  print("Failed to download image for question ${questionDoc.id}");
                }
                continue;
              }
              await file.writeAsBytes(bytes);
              // await Future.delayed(const Duration(seconds: 3));
            }
          }
        }
        //TODO delete all files that are not in the database
      }
    }

  }

}