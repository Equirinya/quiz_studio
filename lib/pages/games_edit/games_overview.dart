import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quiz_show/database/audio_controller.dart';
import 'package:quiz_show/widgets/media_upload.dart';
import '../../database/constants.dart';
import '../../database/game_stream.dart';

class GamesOverview extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> gameDoc;
  final List<(CategoryGroupData?, List<QueryDocumentSnapshot<Map<String, dynamic>>>)> categoriesDocs;
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
                  decoration: const InputDecoration(labelText: "Game Name", border: OutlineInputBorder()),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () {
                gameDoc.reference.update({name: gameNameController.text});
              },
            ),
            IconButton(
              icon: Icon(Icons.music_note),
              onPressed: () {
                showSetMusicDialog(
                  context: context,
                  gameId: gameDoc.id,
                  ref: gameDoc.reference,
                );
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
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
      itemBuilder: (context, groupIndex) {
        CategoryGroupData? groupData = categoriesDocs[groupIndex].$1;
        CategoryGroupType type = groupData?.type ?? CategoryGroupType.wheel;
        List<QueryDocumentSnapshot<Map<String, dynamic>>> categoriesInGroup = categoriesDocs[groupIndex].$2;
        return Card(
          key: ValueKey("group_$groupIndex"),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Stack(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0, left: 8.0, right: 4.0),
                              child: Icon(size: 16, type.icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            Expanded(
                              child: TextField(
                                controller: TextEditingController(text: groupData?.name ?? "Ungrouped Categories"),
                                decoration: const InputDecoration(border: InputBorder.none),
                                onChanged: (value) => groupData?.reference.update({name: value}),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if(groupData != null)IconButton(
                              onPressed: () => showSetMusicDialog(
                                context: context,
                                gameId: gameDoc.id,
                                ref: groupData.reference,
                              ),
                              icon: Icon(Icons.music_note),
                            ),
                            if(groupData != null) IconButton(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  content: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        Text("Select Colors", style: Theme.of(context).textTheme.titleMedium),
                                        Text("Primary Color"),
                                        ColorPicker(
                                          onColorChanged: (value) {
                                            groupData?.reference.update({color: value.value32bit});
                                            groupData?.color = value;
                                          },
                                          color: groupData?.color ?? Theme.of(context).colorScheme.primary,
                                          pickersEnabled: const <ColorPickerType, bool>{
                                            ColorPickerType.both: false,
                                            ColorPickerType.primary: false,
                                            ColorPickerType.accent: false,
                                            ColorPickerType.wheel: true,
                                          },
                                        ),
                                        SizedBox(height: 16),
                                        Text("Accent Color"),
                                        ColorPicker(
                                          onColorChanged: (value) {
                                            groupData?.reference.update({accentColor: value.value32bit});
                                            groupData?.accentColor = value;
                                          },
                                          color: groupData?.accentColor ?? Theme.of(context).colorScheme.tertiary,
                                          pickersEnabled: const <ColorPickerType, bool>{
                                            ColorPickerType.both: false,
                                            ColorPickerType.primary: false,
                                            ColorPickerType.accent: false,
                                            ColorPickerType.wheel: true,
                                          },
                                        ),
                                        SizedBox(height: 16),
                                        OutlinedButton(
                                          onPressed: () {
                                            groupData?.reference.update({
                                              color: Theme.of(context).colorScheme.primary.value32bit,
                                              accentColor: Theme.of(context).colorScheme.tertiary.value32bit,
                                            });
                                            groupData?.color = Theme.of(context).colorScheme.primary;
                                            groupData?.accentColor = Theme.of(context).colorScheme.tertiary;
                                          },
                                          child: Text("Reset"),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              icon: Icon(Icons.color_lens),
                            ),
                            if (categoriesInGroup.isEmpty)
                              IconButton(
                                onPressed: () async {
                                  await groupData?.reference.delete();
                                },
                                icon: Icon(Icons.delete),
                              ),
                          ],
                        ),
                        Center(
                          child: ReorderableDragStartListener(
                            index: groupIndex,
                            child: Icon(Icons.drag_handle_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (groupData != null) Padding(padding: const EdgeInsets.all(4.0), child: groupData.getOptionWidget()),
                  for (var (cIndex, categoryDoc) in [...categoriesDocs[groupIndex].$2, null].indexed) ...[
                    DragTarget<DocumentSnapshot<Map<String, dynamic>>>(
                      builder: (context, candidateData, rejectedData) {
                        bool visible =
                            candidateData.isNotEmpty &&
                            candidateData.any(
                              (e) =>
                                  e != null &&
                                  e.data() != null &&
                                  (e.data()![categoryGroup] != groupData?.id ||
                                      (e.data()![categoryIndex] != cIndex && e.data()![categoryIndex] != cIndex - 1)),
                            );

                        return Container(
                          height: 8,
                          width: double.infinity,
                          color: visible ? Theme.of(context).colorScheme.surfaceBright : Colors.transparent,
                        );
                      },
                      onWillAcceptWithDetails: (details) =>
                          details.data.data() != null &&
                          (details.data.data()![categoryGroup] != groupData?.id ||
                              (details.data.data()![categoryIndex] != cIndex && details.data.data()![categoryIndex] != cIndex - 1)),
                      onAcceptWithDetails: (details) {
                        var draggedDoc = details.data;
                        Map<String, dynamic> draggedData = draggedDoc.data()!;
                        String? oldGroupId = (draggedData[categoryGroup] is String) ? draggedData[categoryGroup] : null;
                        int oldGroupIndex = categoriesDocs.indexWhere((e) => e.$1?.id == oldGroupId);

                        WriteBatch batch = db.batch();
                        if (oldGroupId != groupData?.id) {
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
                          batch.update(draggedDoc.reference, {categoryGroup: groupData?.id, categoryIndex: cIndex});
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
                            batch.update(draggedDoc.reference, {categoryIndex: cIndex - 1});
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
                          child: Padding(padding: const EdgeInsets.all(8.0), child: Text(categoryDoc.data()[name])),
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
                                        onChanged: (value) => categoryDoc.reference.update({active: value ?? true}),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(categoryDoc.data()[name], style: Theme.of(context).textTheme.bodyLarge),
                                            // "Visible to ... " generation
                                            Builder(
                                              builder: (context) {
                                                Iterable<String> fullAccess = List<String>.from(
                                                  [
                                                    AccessType.admin,
                                                    AccessType.full,
                                                  ].map((e) => gameDoc.data()?[e.name] ?? []).expand((element) => element),
                                                );
                                                String creator = categoryDoc.data()[createdBy] ?? "";
                                                Iterable<String> limitedAccess = List<String>.from(gameDoc.data()?[AccessType.limited.name] ?? []);
                                                Iterable<String> categoryAccess = List<String>.from(categoryDoc.data()[access] ?? []);
                                                Iterable<String> combinedAccess =
                                                    categoryAccess.toSet().intersection(limitedAccess.toSet()).union(fullAccess.toSet())
                                                      ..add(creator);

                                                return FutureBuilder(
                                                  future: Future.wait(
                                                    combinedAccess.where((e) => e.isNotEmpty).map((e) => db.collection(users).doc(e).get()),
                                                  ),
                                                  builder: (context, snapshot) {
                                                    if (!snapshot.hasData || snapshot.data == null) return const Text('Visible to: Loading...');
                                                    return Text(
                                                      'Visible to: ${snapshot.data!.map((e) => e.data()?[username] ?? 'Unknown').join(', ')}',
                                                      style: Theme.of(context).textTheme.bodySmall,
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.secondary),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                  Center(
                    child: OutlinedButton(
                      onPressed: () {
                        FirebaseFirestore.instance.collection(games).doc(gameDoc.id).collection(categories).add({
                          name: "New Category",
                          categoryGroup: groupData?.id,
                          createdBy: FirebaseAuth.instance.currentUser!.uid,
                          createdAt: FieldValue.serverTimestamp(),
                          active: true,
                        });
                      },
                      child: Text("Add Category"),
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ],
          ),
        );
      },
      itemCount: categoriesDocs.length,
      onReorder: (oldIndex, newIndex) {
        //all categoryGroups in this game need to be updated with new index
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        if (categoriesDocs.first.$1 != null) {
          oldIndex++;
          newIndex++;
        }
        if (oldIndex == 0 && categoriesDocs[0].$1 == null) return;
        for (var categoryGroupDoc in categoriesDocs) {
          int currentIndex = categoryGroupDoc.$1?.index ?? 0;
          if (currentIndex == oldIndex) {
            categoryGroupDoc.$1!.reference.update({categoryGroupIndex: newIndex});
          } else if (currentIndex >= newIndex && currentIndex < oldIndex) {
            categoryGroupDoc.$1!.reference.update({categoryGroupIndex: currentIndex + 1});
          } else if (currentIndex <= newIndex && currentIndex > oldIndex) {
            categoryGroupDoc.$1!.reference.update({categoryGroupIndex: currentIndex - 1});
          }
        }
      },
      footer: Center(
        child: Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 32, top: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            runSpacing: 8,
            spacing: 8,
            children: [
              for (var type in CategoryGroupType.values)
                OutlinedButton(
                  onPressed: () {
                    FirebaseFirestore.instance.collection(games).doc(gameDoc.id).collection(categoryGroups).add({
                      name: "New ${type.uiString}",
                      categoryGroupIndex: categoriesDocs.length + (categoriesDocs.first.$1 == null ? 0 : 1),
                      categoryGroupType: type.databaseString(),
                      createdBy: FirebaseAuth.instance.currentUser!.uid,
                      createdAt: FieldValue.serverTimestamp(),
                    });
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Text("Add ${type.uiString}"), SizedBox(width: 4), Icon(type.icon)]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

extension OptionWidgets on CategoryGroupData {
  Widget getOptionWidget() {
    print("Getting option widget for category group of data type ${this.name}");
    switch (this.type) {
      case CategoryGroupType.display:
        return Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: "Display Text", border: OutlineInputBorder()),
                controller: TextEditingController(text: this.text ?? ""),
                onChanged: (value) {
                  reference.update({text: value});
                  this.text = value;
                },
              ),
            ),
            // MediaUploadIconButton(
            //   uploadType: MediaUploadType.image,
            //
            // )
          ],
        );
      case CategoryGroupType.wheel:
        return StatefulBuilder(
          builder: (context, setState) {
            return SwitchListTile(
              value: data[splitPointFields] ?? false,
              onChanged: (value) {
                setState(() {
                  data[splitPointFields] = value;
                });
                reference.update({splitPointFields: value});
              },
              title: Text("Split Point Fields when value appears multiple times"),
            );
          },
        );
      case CategoryGroupType.map:
        return SizedBox();
    }
  }
}
