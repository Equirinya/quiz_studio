import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_show/pages/games_edit/games_overview.dart';
import 'package:quiz_show/question_types/abstract_question.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'games_access.dart';
import 'games_categories.dart';
import '../../database/constants.dart';

class GamesDetailPage extends StatefulWidget {
  const GamesDetailPage({super.key, required this.gameId});

  final String gameId;

  @override
  State<GamesDetailPage> createState() => _GamesDetailPageState();
}

class _GamesDetailPageState extends State<GamesDetailPage>
    with TickerProviderStateMixin {
  TabController? tabController;
  FirebaseFirestore db = FirebaseFirestore.instance;
  StreamSubscription? gameDocListener;
  DocumentSnapshot<Map<String, dynamic>>? gameDoc;
  StreamSubscription? categoriesListener;
  List<(CategoryType, List<QueryDocumentSnapshot<Map<String, dynamic>>>)>? categoriesDocs;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? flattenedCategoriesDocs;
  late SharedPreferences prefs;
  bool initialized = false;

  TextEditingController newCategoryController = TextEditingController();

  @override
  void initState() {
    tabController = TabController(length: 1, vsync: this);
    () async {
      prefs = await SharedPreferences.getInstance();
      gameDocListener =
          db.collection(games).doc(widget.gameId).snapshots().listen((event) {
        gameDoc = event;
        checkIfReadyAndSetState();
      });
      //TODO only request categories that user has access to
      categoriesListener = db
          .collection(games)
          .doc(widget.gameId)
          .collection(categories)
          .orderBy(createdAt)
          .snapshots()
          .listen((event) {
        int index = tabController?.index ?? 0;
        if(index >= event.docs.length + 1){
          index = event.docs.length;
        }
        tabController = TabController(
            length: event.docs.length + 1, vsync: this, initialIndex: index);
        categoriesDocs = sortCategories(event.docs);
        flattenedCategoriesDocs = categoriesDocs!.expand((tuple) => tuple.$2).toList();
        checkIfReadyAndSetState();
      });
    }();
    super.initState();
  }

  void checkIfReadyAndSetState() {
    if (gameDoc == null || categoriesDocs == null) return;
    setState(() {
      initialized = true;
    });
  }

  @override
  void dispose() {
    gameDocListener?.cancel();
    categoriesListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const Center(child: CupertinoActivityIndicator());

    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(right: 32.0),
          child: Text(gameDoc!.data()?[name] ?? unnamed,
              overflow: TextOverflow.ellipsis),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: () async {
              String text = gameDoc?.data()?[name] ?? '';
              for (var categoryDoc in flattenedCategoriesDocs!) {
                text +=
                    "\n\n--- Kategorie: " + categoryDoc.data()[name] + ' ---\n';
                for (var questionDoc in (await db
                        .collection(games)
                        .doc(widget.gameId)
                        .collection(categories)
                        .doc(categoryDoc.id)
                        .collection(questions)
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
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    )
                  ],
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
            const Tab(
              text: overview,
            ),
            for (String name in flattenedCategoriesDocs!.map((e) => e.data()[name]))
              Tab(
                text: name.length < 35 ? name : "${name.substring(0, 35)}...",
              ),
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
          GamesOverview(
            gameDoc: gameDoc!,
            categoriesDocs: categoriesDocs!,
            tabController: tabController!,
          ),
          for (var category in flattenedCategoriesDocs!)
            GamesCategoriesEditPage(
                gameId: widget.gameId, categoryId: category.id),

          //categorys should now be created in the overview page
          // ListView(
          //   children: [
          //     Padding(
          //       padding: const EdgeInsets.all(16.0),
          //       child: TextField(
          //         controller: newCategoryController,
          //         decoration: const InputDecoration(
          //             hintText: 'Category Name', border: OutlineInputBorder()),
          //       ),
          //     ),
          //     Padding(
          //       padding: const EdgeInsets.all(8.0),
          //       child: ElevatedButton(
          //           onPressed: () async {
          //             await db
          //                 .collection(games)
          //                 .doc(widget.gameId)
          //                 .collection(categories)
          //                 .add({
          //               name: newCategoryController.text,
          //               active: true,
          //               createdAt: FieldValue.serverTimestamp(),
          //               createdBy: FirebaseAuth.instance.currentUser?.uid,
          //             });
          //             newCategoryController.clear();
          //           },
          //           child: const Padding(
          //             padding: EdgeInsets.all(8.0),
          //             child: Text('Create Category'),
          //           )),
          //     ),
          //   ],
          // )
        ],
      ),
    );
  }
}


List<(CategoryType, List<QueryDocumentSnapshot<Map<String, dynamic>>>)>
sortCategories(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> categoriesDocs) {
  //first group by categoryGroup ascending, making sure that the categoryType is the same and use that as the String in tuple
  // then within the groups sort by categoryIndex ascending, then by createdAt ascending
  Map<int, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};
  for (var doc in categoriesDocs) {
    int group = doc.data()[categoryGroup] ?? 0;
    if (!grouped.containsKey(group)) {
      grouped[group] = [];
    }
    grouped[group]!.add(doc);
  }
  var sortedGroups =
  (grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
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
  var mapped = sortedGroups.map((e) {
    CategoryType finalCategoryType;
    var categoryTypes =
    e.value.map((doc) => doc.data()[categoryType] as String?);
    var set = categoryTypes.toSet();
    if (set.length == 1 && set.first != null) {
      finalCategoryType = CategoryType.values.firstWhere((element) => element.databaseString() == categoryTypes.first!, orElse: () => CategoryType.wheel);
    } else {
      print(
          "Warning: Mixed or null category types in group ${e.key}, defaulting to wheel. Found types: $set");
      finalCategoryType = CategoryType.wheel;
    }

    return (finalCategoryType, e.value);
  }).toList();

  return mapped;
}

