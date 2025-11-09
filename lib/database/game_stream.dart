import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quiz_show/database/media_downloader.dart';

import '../pages/games_edit/games_detail.dart';
import 'constants.dart';

class GameStreamBuilder extends StatefulWidget {
  const GameStreamBuilder({
    super.key,
    required this.gameId,
    required this.builder,
    this.fallback = const Center(child: CupertinoActivityIndicator()),
  });

  final String? gameId;
  final Widget Function(List<(CategoryType, List<String>)> categories, List<List<Map<String, dynamic>>> questions) builder;
  final Widget fallback;

  @override
  State<GameStreamBuilder> createState() => _GameStreamBuilderState();
}

class _GameStreamBuilderState extends State<GameStreamBuilder> {
  FirebaseFirestore db = FirebaseFirestore.instance;
  StreamSubscription? categoryDocsListener;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? categoryDocs;
  List<(CategoryType, List<QueryDocumentSnapshot<Map<String, dynamic>>>)> sortedCategories = [];
  List<StreamSubscription?> questionDocsListeners = [];
  List<QuerySnapshot<Map<String, dynamic>>?> questionDocs = [];
  bool initialized = false;

  @override
  void initState() {
    if (widget.gameId == null || widget.gameId!.isEmpty) return;
    () async {
      categoryDocsListener =
          db.collection(games).doc(widget.gameId).collection(categories).where(active, isEqualTo: true).snapshots().listen((event) {
        sortedCategories = sortCategories(event.docs);
        categoryDocs = sortedCategories.expand((tuple) => tuple.$2).toList();
        for (var listener in questionDocsListeners) {
          listener?.cancel();
        }
        questionDocsListeners = [];
        questionDocs = [];
        for (var (i, categoryDoc) in categoryDocs!.indexed) {
          questionDocsListeners.add(
              db.collection(games).doc(widget.gameId).collection(categories).doc(categoryDoc.id).collection(questions).snapshots().listen((event) {
            if (questionDocs.length <= i) {
              questionDocs.addAll(List.filled(i - questionDocs.length + 1, null));
            }
            questionDocs[i] = event;

            checkIfReadyAndSetState();
          }));
        }
        checkIfReadyAndSetState();
      });
    }();
    super.initState();
  }

  void checkIfReadyAndSetState() {
    if (categoryDocs == null || questionDocs.length < categoryDocs!.length || questionDocs.any((e) => e == null)) return;
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

  @override
  Widget build(BuildContext context) {
    MediaDownloader().downloadGameMedia(widget.gameId!, questionDocs);
    if (widget.gameId == null || widget.gameId!.isEmpty) return widget.fallback;
    if (!initialized) return widget.fallback;

    List<(CategoryType, List<String>)> categories =
        sortedCategories.map((e) => (e.$1, e.$2.map((e2) => e2.data()[name] as String).toList())).toList();
    List<List<Map<String, dynamic>>> questions = questionDocs.map((e) => e!.docs.map((e2) => e2.data()..[documentId] = e2.id).toList()).toList();
    return widget.builder(categories, questions);
  }
}
