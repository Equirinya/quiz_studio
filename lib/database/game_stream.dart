import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quiz_show/database/media_downloader.dart';

import '../pages/games_edit/games_detail.dart';
import 'constants.dart' as dbString;
import 'constants.dart';

class GameStreamBuilder extends StatefulWidget {
  const GameStreamBuilder({
    super.key,
    required this.gameId,
    required this.builder,
    this.fallback = const Center(child: CupertinoActivityIndicator()),
  });

  final String? gameId;
  final Widget Function(List<(CategoryGroupData?, List<QueryDocumentSnapshot<Map<String, dynamic>>>)> categories, List<List<Map<String, dynamic>>> questions) builder;
  final Widget fallback;

  @override
  State<GameStreamBuilder> createState() => _GameStreamBuilderState();
}

class _GameStreamBuilderState extends State<GameStreamBuilder> {
  FirebaseFirestore db = FirebaseFirestore.instance;
  StreamSubscription? categoryDocsListener;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? categoryDocs;
  List<(CategoryGroupData?, List<QueryDocumentSnapshot<Map<String, dynamic>>>)> sortedCategories = [];
  List<StreamSubscription?> questionDocsListeners = [];
  List<QuerySnapshot<Map<String, dynamic>>?> questionDocs = [];
  bool initialized = false;

  @override
  void initState() {
    if (widget.gameId == null || widget.gameId!.isEmpty) return;
    () async {
      categoryDocsListener =
          db.collection(games).doc(widget.gameId).collection(categories).where(active, isEqualTo: true).snapshots().listen((event) async {
        var categoryGroupDocs = await db.collection(games).doc(widget.gameId).collection(categoryGroups).get();
        sortedCategories = sortCategories(event.docs, categoryGroupDocs.docs);
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

    List<List<Map<String, dynamic>>> questions = questionDocs
        .map((e) => (e!.docs..sort((a, b) => (a[pointsPlus] as int? ?? 0).compareTo(b[pointsPlus] ?? 0)))
            .map((e2) => e2.data()..[documentId] = e2.id)
            .toList())
        .toList();
    return widget.builder(sortedCategories, questions);
  }
}

class CategoryGroupData {
  final dbString.CategoryGroupType type;
  final String id;
  final DocumentReference reference;
  int index;
  String name;
  Color? color;
  Color? accentColor;
  final List<String> mediaPaths;

  String? text;
  String? imagePath;
  String? musicPath;

  String? connections;

  final Map<String, dynamic> data;

  CategoryGroupData(this.data, this.reference)
      : name = data[dbString.name],
        id = reference.id,
        index = data[dbString.categoryGroupIndex],
        color = data[dbString.color] != null ? Color(data[dbString.color]) : null,
        accentColor = data[dbString.accentColor] != null ? Color(data[dbString.accentColor]) : null,
        imagePath = data[dbString.imagePath],
        musicPath = data[dbString.musicPath],
        text = data[dbString.text],
        connections = data[dbString.connections],
        mediaPaths = [data[dbString.imagePath], data[dbString.musicPath]].whereType<String>().toList(),
        type = dbString.CategoryGroupType.values
            .firstWhere((e) => e.databaseString() == data[dbString.categoryGroupType], orElse: () => dbString.CategoryGroupType.wheel);
}

List<(CategoryGroupData?, List<QueryDocumentSnapshot<Map<String, dynamic>>>)> sortCategories(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> categoriesDocs, List<QueryDocumentSnapshot<Map<String, dynamic>>> categoryGroupDocs) {
  //first group by categoryGroup ascending, making sure that the categoryType is the same and use that as the String in tuple
  // then within the groups sort by categoryIndex ascending, then by createdAt ascending
  Map<CategoryGroupData?, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {null:[]};
  for(var groupDoc in categoryGroupDocs){
    CategoryGroupData categoryGroupData = CategoryGroupData(groupDoc.data(), groupDoc.reference);
    grouped[categoryGroupData] = [];
  }
  for (var doc in categoriesDocs) {
    dynamic group = doc.data()[categoryGroup];
    grouped.entries.firstWhere((e) => e.key?.id == group, orElse: () => grouped.entries.first).value.add(doc);
  }
  var sortedGroups = grouped.entries.toList()
    ..sort((a, b) {
      var aIndex = a.key?.data[categoryGroupIndex];
      var bIndex = b.key?.data[categoryGroupIndex];
      if (aIndex == null) return -1;
      if (bIndex == null) return 1;
      return aIndex.compareTo(bIndex);
    });
  for (var entry in sortedGroups) {
    entry.value.sort((a, b) {
      int indexA = a.data()[categoryIndex] ?? 0;
      int indexB = b.data()[categoryIndex] ?? 0;
      if (indexA != indexB) {
        return indexA.compareTo(indexB);
      } else {
        DateTime createdAtA = a.data()[createdAt]?.toDate() ?? DateTime.now();
        DateTime createdAtB = b.data()[createdAt]?.toDate() ?? DateTime.now();
        return createdAtA.compareTo(createdAtB);
      }
    });
  }

  sortedGroups.removeWhere((element) => element.key == null && element.value.isEmpty);
  print(sortedGroups);
  return sortedGroups.map((e) => (e.key, e.value)).toList();
}
