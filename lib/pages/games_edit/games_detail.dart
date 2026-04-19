import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_show/pages/games_edit/games_overview.dart';
import 'package:quiz_show/question_types/abstract_question.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/game_stream.dart';
import 'games_access.dart';
import 'games_categories.dart';
import '../../database/constants.dart' as dbStrings;
import '../../database/constants.dart';

class GamesDetailPage extends StatefulWidget {
  const GamesDetailPage({super.key, required this.gameId});

  final String gameId;

  @override
  State<GamesDetailPage> createState() => _GamesDetailPageState();
}

class _GamesDetailPageState extends State<GamesDetailPage> with TickerProviderStateMixin {
  TabController? tabController;
  FirebaseFirestore db = FirebaseFirestore.instance;
  StreamSubscription? gameDocListener;
  DocumentSnapshot<Map<String, dynamic>>? gameDoc;
  StreamSubscription? categoriesListener;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> categoriesDocs = [];
  StreamSubscription? categoryGroupsListener;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> categoryGroupsDocs = [];
  List<(CategoryGroupData?, List<QueryDocumentSnapshot<Map<String, dynamic>>>)>? sortedCategoriesDocs;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? flattenedCategoriesDocs;
  late SharedPreferences prefs;
  bool initialized = false;

  TextEditingController newCategoryController = TextEditingController();

  @override
  void initState() {
    tabController = TabController(length: 1, vsync: this);
    () async {
      prefs = await SharedPreferences.getInstance();
      gameDocListener = db.collection(games).doc(widget.gameId).snapshots().listen((event) {
        gameDoc = event;
        checkIfReadyAndSetState();
      });
      //TODO only request categories that user has access to
      categoriesListener = db.collection(games).doc(widget.gameId).collection(categories).orderBy(createdAt).snapshots().listen((event) {
        categoriesDocs = event.docs;
        checkIfReadyAndSetState();
      });

      categoryGroupsListener = db.collection(games).doc(widget.gameId).collection(categoryGroups).orderBy(categoryGroupIndex).snapshots().listen((
        event,
      ) {
        categoryGroupsDocs = event.docs;
        if (event.docChanges.any((change) => change.oldIndex != change.newIndex || change.type != DocumentChangeType.modified)) {
          checkIfReadyAndSetState();
        }
      });
    }();
    super.initState();
  }

  void checkIfReadyAndSetState() {
    if (gameDoc == null || categoriesDocs == null || categoryGroupsDocs == null) return;
    var categoryGroupData = categoryGroupsDocs!.map((e) => CategoryGroupData(e.data(), e.reference)).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    sortedCategoriesDocs = sortCategories(categoriesDocs!, categoryGroupData);
    flattenedCategoriesDocs = sortedCategoriesDocs!.expand((tuple) => tuple.$2).toList();
    int index = tabController?.index ?? 0;
    if (index >= flattenedCategoriesDocs!.length + 1) {
      index = flattenedCategoriesDocs!.length;
    }
    tabController = TabController(length: flattenedCategoriesDocs!.length + 1, vsync: this, initialIndex: index);
    setState(() {
      initialized = true;
    });
  }

  @override
  void dispose() {
    gameDocListener?.cancel();
    categoriesListener?.cancel();
    categoryGroupsListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const Center(child: CupertinoActivityIndicator());
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(right: 32.0),
          child: Text(gameDoc!.data()?[name] ?? unnamed, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: () async {
              String text = gameDoc?.data()?[name] ?? '';
              for (var categoryDoc in flattenedCategoriesDocs!) {
                text += "\n\n--- Kategorie: " + categoryDoc.data()[name] + ' ---\n';
                for (var questionDoc
                    in (await db
                            .collection(games)
                            .doc(widget.gameId)
                            .collection(dbStrings.categories)
                            .doc(categoryDoc.id)
                            .collection(dbStrings.questions)
                            .orderBy(pointsPlus)
                            .get())
                        .docs) {
                  text += Question.fromData(questionDoc.data()).asText();
                  text += '\n';
                }
              }
              await Clipboard.setData(ClipboardData(text: text));
            },
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Manage Access'),
                  content: GamesAccessPage(gameId: widget.gameId),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                ),
              );
            },
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: tabController,
          // indicator: BoxDecoration(
          //   borderRadius: BorderRadius.circular(50), // Creates border
          //   color: Theme.of(context).colorScheme.primaryContainer,
          // ),
          isScrollable: true,
          tabs: [
            const Tab(text: overview),
            for (String name in flattenedCategoriesDocs!.map((e) => e.data()[name]))
              Tab(text: name.length < 35 ? name : "${name.substring(0, 35)}..."),
            // const Tab(
            //   text: newCategory,
            //   icon: Icon(Icons.add),
            // ),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          GamesOverview(gameDoc: gameDoc!, categoriesDocs: sortedCategoriesDocs!, tabController: tabController!),
          for (var category in flattenedCategoriesDocs!) GamesCategoriesEditPage(gameId: widget.gameId, categoryId: category.id),
        ],
      ),
    );
  }
}
