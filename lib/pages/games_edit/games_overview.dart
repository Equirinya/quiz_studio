import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../database/constants.dart';

class GamesOverview extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> gameDoc;
  final List<(CategoryType, List<QueryDocumentSnapshot<Map<String, dynamic>>>)> categoriesDocs;
  final TabController tabController;

  const GamesOverview({super.key, required this.gameDoc, required this.tabController, required this.categoriesDocs});

  @override
  Widget build(BuildContext context) {
    FirebaseFirestore db = FirebaseFirestore.instance;
    TextEditingController gameNameController = TextEditingController(text: gameDoc.data()?[name]);
    var flattenedCategoriesDocs = categoriesDocs.expand((e) => e.$2).toList();

    //TODO default points
    return ReorderableListView.builder(
      //header = gameSettings: GameName, delete game
      buildDefaultDragHandles: false,
      header: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: TextField(
                  controller: gameNameController,
                  decoration: const InputDecoration(
                    labelText: "Game Name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () {
                gameDoc.reference.update({name: gameNameController.text});
              },
            ),
            if (gameDoc.data()?[AccessType.admin.name].contains(FirebaseAuth.instance.currentUser?.uid))
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      icon: const Icon(Icons.delete),
                      title: const Text('Delete Game'),
                      content: const Text('Are you sure you want to delete this game?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                            Future.delayed(const Duration(milliseconds: 200), () {
                              gameDoc.reference.delete();
                            });
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      //Category groups:
      itemBuilder: (context, groupIndex) => Card(
          key: ValueKey("group_$groupIndex"),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top:8),
                    child: Stack(
                      children: [
                        Center(
                          child: ReorderableDragStartListener(
                            index: groupIndex,
                            child: Icon(
                              Icons.drag_handle_outlined,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top:4.0, left: 8.0, right: 4.0),
                              child: Icon(
                                size: 16,
                                categoriesDocs[groupIndex].$1.icon,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              categoriesDocs[groupIndex].$1.uiString,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  for (var (cIndex, categoryDoc) in [...categoriesDocs[groupIndex].$2, null].indexed) ...[
                    DragTarget<DocumentSnapshot<Map<String, dynamic>>>(
                      builder: (context, candidateData, rejectedData) {
                        bool visible = candidateData.isNotEmpty &&
                            candidateData.any((e) =>
                                e != null &&
                                e.data() != null &&
                                (e.data()![categoryGroup] != groupIndex ||
                                    (e.data()![categoryIndex] != cIndex && e.data()![categoryIndex] != cIndex - 1)));

                        return Container(
                          height: 8,
                          width: double.infinity,
                          color: visible ? Theme.of(context).colorScheme.surfaceBright : Colors.transparent,
                        );
                      },
                      onWillAcceptWithDetails: (details) =>
                          details.data.data() != null &&
                          (details.data.data()![categoryGroup] != groupIndex ||
                              (details.data.data()![categoryIndex] != cIndex && details.data.data()![categoryIndex] != cIndex - 1)),
                      onAcceptWithDetails: (details) {
                        var draggedDoc = details.data;
                        Map<String, dynamic> draggedData = draggedDoc.data()!;
                        int oldGroupIndex = draggedData[categoryGroup] ?? 0;

                        WriteBatch batch = db.batch();
                        if (oldGroupIndex != groupIndex) {
                          //need to reindex old group
                          var oldGroupCategories = categoriesDocs[oldGroupIndex].$2;
                          for (var (oldCIndex, oldCategoryDoc) in oldGroupCategories.indexed.skip(draggedData[categoryIndex] ?? 0)) {
                            batch.update(oldCategoryDoc.reference, {categoryIndex: oldCIndex - 1});
                          }
                          //need to reindex new group
                          var newGroupCategories = categoriesDocs[groupIndex].$2;
                          for (var (newCIndex, newCategoryDoc) in newGroupCategories.indexed.skip(cIndex)) {
                            batch.update(newCategoryDoc.reference, {categoryIndex: newCIndex + 1});
                          }
                          var newGroupIndex = groupIndex;
                          //if dragged item was last item in group, the group disappears and the later groups need to be reindexed
                          if (oldGroupCategories.length == 1) {
                            newGroupIndex -= 1;
                            for (var i = oldGroupIndex + 1; i < categoriesDocs.length; i++) {
                              var groupCats = categoriesDocs[i].$2;
                              for (var catDoc in groupCats) {
                                batch.update(catDoc.reference, {categoryGroup: i - 1});
                              }
                            }
                          }
                          batch.update(draggedDoc.reference, {categoryGroup: newGroupIndex, categoryIndex: cIndex, categoryType: categoriesDocs[groupIndex].$1.databaseString()});
                        } else {
                          //same group, just reindex within
                          var groupCategories = categoriesDocs[groupIndex].$2;
                          int oldIndex = draggedData[categoryIndex] ?? 0;

                          if (oldIndex < cIndex) {
                            // items with index in (oldIndex, cIndex] -> -1
                            for (var (idx, doc) in groupCategories.indexed) {
                              if (idx > oldIndex && idx <= cIndex) {
                                batch.update(doc.reference, {categoryIndex: idx - 1});
                              }
                            }
                            batch.update(draggedDoc.reference, {categoryIndex: cIndex-1});
                          } else if (oldIndex > cIndex) {
                            // items with index in [cIndex, oldIndex) -> +1
                            for (var (idx, doc) in groupCategories.indexed) {
                              if (idx >= cIndex && idx < oldIndex) {
                                batch.update(doc.reference, {categoryIndex: idx + 1});
                              }
                            }
                            batch.update(draggedDoc.reference, {categoryIndex: cIndex});
                          }
                        }
                        batch.commit();
                      },
                    ),
                    if (categoryDoc != null)
                      LongPressDraggable<DocumentSnapshot<Map<String, dynamic>>>(
                        data: categoryDoc,
                        dragAnchorStrategy: pointerDragAnchorStrategy,
                        feedback: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(categoryDoc.data()[name]),
                          ),
                        ),
                        onDragUpdate: (details) {
                          if (details.globalPosition.dy < 100 || details.globalPosition.dy > MediaQuery.of(context).size.height - 20) {
                            //move the listview
                            ScrollableState? scrollableState = Scrollable.of(context);
                            final position = scrollableState.position;
                            if (details.globalPosition.dy < 100) {
                              position.moveTo(position.pixels - 5);
                            } else if (details.globalPosition.dy > MediaQuery.of(context).size.height - 20) {
                              position.moveTo(position.pixels + 5);
                            }
                          }
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => tabController.animateTo(1 + flattenedCategoriesDocs.indexWhere((doc) => doc.id == categoryDoc.id)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Card(
                                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Checkbox(
                                            value: categoryDoc.data()[active] ?? false,
                                            onChanged: (value) => categoryDoc.reference.update({active: value ?? true})),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(categoryDoc.data()[name], style: Theme.of(context).textTheme.bodyLarge),
                                              // "Visible to ... " generation
                                              Builder(builder: (context) {
                                                Iterable<String> fullAccess = List<String>.from([AccessType.admin, AccessType.full]
                                                    .map((e) => gameDoc.data()?[e.name] ?? [])
                                                    .expand((element) => element));
                                                String creator = categoryDoc.data()[createdBy] ?? "";
                                                Iterable<String> limitedAccess = List<String>.from(gameDoc.data()?[AccessType.limited.name] ?? []);
                                                Iterable<String> categoryAccess = List<String>.from(categoryDoc.data()[access] ?? []);
                                                Iterable<String> combinedAccess = categoryAccess
                                                    .toSet()
                                                    .intersection(limitedAccess.toSet())
                                                    .union(fullAccess.toSet())
                                                  ..add(creator);

                                                return FutureBuilder(
                                                  future: Future.wait(
                                                      combinedAccess.where((e) => e.isNotEmpty).map((e) => db.collection(users).doc(e).get())),
                                                  builder: (context, snapshot) {
                                                    if (!snapshot.hasData || snapshot.data == null) return const Text('Visible to: Loading...');
                                                    return Text(
                                                        'Visible to: ${snapshot.data!.map((e) => e.data()?[username] ?? 'Unknown').join(', ')}',
                                                        style: Theme.of(context).textTheme.bodySmall);
                                                  },
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ],
                                    ),
                                  )),
                            ),
                          ),
                        ),
                      )
                  ],
                  Center(
                    child: OutlinedButton(
                        onPressed: () {
                          FirebaseFirestore.instance.collection(games).doc(gameDoc.id).collection(categories).add({
                            name: "New Category",
                            categoryGroup: groupIndex,
                            categoryType: categoriesDocs[groupIndex].$1.databaseString(),
                            createdBy: FirebaseAuth.instance.currentUser!.uid,
                            createdAt: FieldValue.serverTimestamp(),
                            active: true,
                          });
                        },
                        child: Text("Add Category")),
                  ),
                  SizedBox(height: 8)
                ],
              ),
            ],
          )),
      itemCount: categoriesDocs.length,
      onReorder: (oldIndex, newIndex) {
        //all categories in this game need to be updated with new index
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        for (var categoryDoc in flattenedCategoriesDocs) {
          int currentIndex = categoryDoc.data()[categoryGroup] ?? 0;
          if (currentIndex == oldIndex) {
            categoryDoc.reference.update({categoryGroup: newIndex});
          } else if (currentIndex >= newIndex && currentIndex < oldIndex) {
            categoryDoc.reference.update({categoryGroup: currentIndex + 1});
          } else if (currentIndex <= newIndex && currentIndex > oldIndex) {
            categoryDoc.reference.update({categoryGroup: currentIndex - 1});
          }
        }
      },
      footer: Center(
        child: Padding(
          padding: const EdgeInsets.only(left:4, right:4, bottom:32, top:4),
          child: Wrap(
            alignment: WrapAlignment.center,
            runSpacing: 8,
            spacing: 8,
            children: [
              for (var type in CategoryType.values)
                OutlinedButton(
                  onPressed: () {
                    FirebaseFirestore.instance.collection(games).doc(gameDoc.id).collection(categories).add({
                      name: "New ${type.uiString}",
                      categoryGroup: categoriesDocs.length,
                      categoryType: type.databaseString(),
                      createdBy: FirebaseAuth.instance.currentUser!.uid,
                      createdAt: FieldValue.serverTimestamp(),
                      active: true,
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Add ${type.uiString}"),
                      SizedBox(width: 4),
                      Icon(type.icon),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
