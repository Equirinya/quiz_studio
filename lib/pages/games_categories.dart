import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/constants.dart';
import '../widgets/question.dart';

class GamesCategoriesEditPage extends StatefulWidget {
  const GamesCategoriesEditPage({super.key, required this.gameId, required this.categoryId});

  final String gameId;
  final String categoryId;

  @override
  State<GamesCategoriesEditPage> createState() => _GamesCategoriesEditPageState();
}

class _GamesCategoriesEditPageState extends State<GamesCategoriesEditPage> {
  FirebaseFirestore db = FirebaseFirestore.instance;
  final storageRef = FirebaseStorage.instance.ref();
  StreamSubscription? categoryDocListener;
  DocumentSnapshot<Map<String, dynamic>>? categoryDoc;
  StreamSubscription? questionDocsListener;
  QuerySnapshot<Map<String, dynamic>>? questionDocs;
  late SharedPreferences prefs;
  bool initialized = false;
  late TextEditingController categoryNameController;

  Stream<TaskSnapshot>? uploadImageStream;
  bool? uploadImageSuccess;
  bool uploadImageLoading = false;
  Stream<TaskSnapshot>? uploadMusicStream;
  bool? uploadMusicSuccess;
  bool uploadMusicLoading = false;

  @override
  void initState() {
    () async {
      prefs = await SharedPreferences.getInstance();
      categoryDocListener = db
          .collection(games)
          .doc(widget.gameId)
          .collection(categories)
          .doc(widget.categoryId)
          .snapshots()
          .listen((event) {
        categoryDoc = event;
        checkIfReadyAndSetState();
      });
      questionDocsListener = db
          .collection(games)
          .doc(widget.gameId)
          .collection(categories)
          .doc(widget.categoryId)
          .collection(questions)
          .orderBy(pointsPlus)
          .snapshots()
          .listen((event) {
        questionDocs = event;

        //if remote change
        if (!event.metadata.hasPendingWrites ||
            event.docChanges.any((e) => e.type == DocumentChangeType.added || e.type == DocumentChangeType.removed) ||
            !initialized) {
          checkIfReadyAndSetState();
        }
      });
    }();
    super.initState();
  }

  void checkIfReadyAndSetState() {
    if (categoryDoc == null || questionDocs == null) return;
    categoryNameController = TextEditingController(text: categoryDoc!.data()?[name]);
    setState(() {
      initialized = true;
    });
  }

  @override
  void dispose() {
    categoryDocListener?.cancel();
    questionDocsListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const Center(child: CupertinoActivityIndicator());
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: TextField(
                  controller: categoryNameController,
                  decoration: const InputDecoration(
                    labelText: "Category Name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () {
                  categoryDoc!.reference.update({name: categoryNameController.text});
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      icon: const Icon(Icons.delete),
                      title: const Text("Delete Category"),
                      content: const Text("Are you sure you want to delete this category?"),
                      actions: [
                        TextButton(
                          onPressed: () {
                            categoryDoc!.reference.delete();
                            Navigator.of(context).pop();
                          },
                          child: const Text("Yes"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text("No"),
                        )
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: ElevatedButton(
            onPressed: () {
              db
                  .collection(games)
                  .doc(widget.gameId)
                  .collection(categories)
                  .doc(widget.categoryId)
                  .collection(questions)
                  .add({
                type: QuestionType.free.name,
                question: "",
                description: "",
                image: null,
                music: null,
                pointsPlus: 0,
                pointsMinus: 0,
                answersCorrect: [false, false, false, false],
                answers: ["", "", "", ""],
                answerHint: "",
              });
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Add Question"),
            ),
          ),
        ),
        for (var doc in questionDocs!.docs)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility),
                          onPressed: () {
                            showDialog(context: context, builder: (context) => Center(child: QuestionDisplay(questionData: doc.data(), reveal: 100)));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            doc.reference.delete();
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          height: 4,
                        ),
                        Row(
                          children: [
                            DropdownMenu<QuestionType>(
                                dropdownMenuEntries: QuestionType.values.map((e) {
                                  return DropdownMenuEntry(
                                    value: e,
                                    label: e.name,
                                  );
                                }).toList(),
                                initialSelection: QuestionType.values.firstWhere(
                                    (element) => element.name == doc.data()[type],
                                    orElse: () => QuestionType.free),
                                hintText: "Type",
                                onSelected: (value) {
                                  doc.reference.update({type: value?.name ?? QuestionType.free.name});
                                  Future.delayed(const Duration(milliseconds: 100), () {
                                    setState(() {});
                                  });
                                }),
                            const SizedBox(
                              width: 16,
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: TextField(
                                controller: TextEditingController(text: doc.data()[description]),
                                decoration: const InputDecoration(
                                  labelText: "Description",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) => doc.reference.update({description: value}),
                              ),
                            ),
                            const SizedBox(width: 96)
                          ],
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: TextField(
                                controller: TextEditingController(text: doc.data()[question]),
                                decoration: const InputDecoration(
                                  labelText: "Question",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) => doc.reference.update({question: value}),
                              ),
                            ),
                            StatefulBuilder(
                              builder: (context, setIconState) { //TODO add dialog with preview of file
                                return IconButton(icon: uploadImageLoading ? const CupertinoActivityIndicator() : Icon(uploadImageSuccess == null ? Icons.add_photo_alternate : uploadImageSuccess! ? Icons.image : Icons.image_not_supported), onPressed: uploadImageLoading ? null : () async {
                                  final XFile? imageXFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                                  if (imageXFile == null) return;
                                  setIconState(() {
                                    uploadImageSuccess = null;
                                    uploadImageLoading = true;
                                  });
                                  int index = await getGameMediaIndex(widget.gameId);
                                  String filename = "$index.${imageXFile.path.split("/").last.split(".").last}";
                                  uploadImageStream = storageRef.child("${widget.gameId}/$filename").putFile(File(imageXFile.path)).snapshotEvents;
                                  uploadImageStream?.listen((event) {
                                    switch (event.state) {
                                      case TaskState.success:
                                        doc.reference.update({image: filename});
                                        setIconState(() {
                                          uploadImageLoading = false;
                                          uploadImageSuccess = true;
                                        });
                                        if(doc.data()[image] != null)storageRef.child("${widget.gameId}/${doc.data()[image]}").delete();
                                        break;
                                      case TaskState.error:
                                        setIconState(() {
                                          uploadImageLoading = false;
                                          uploadImageSuccess = false;
                                        });
                                        break;
                                      default: break;
                                    }
                                  });
                                },);
                              }
                            ),
                            StatefulBuilder(
                                builder: (context, setIconState) {
                                return IconButton(icon: const Icon(Icons.music_note), onPressed: () async {
                                  const XTypeGroup music_extension = XTypeGroup(
                                    label: 'Audio File',
                                    extensions: <String>['mp3', 'wav'],
                                  );
                                  const XTypeGroup music_uniform_file_type = XTypeGroup(
                                    label: 'Audio File',
                                      uniformTypeIdentifiers: <String>['public.audio'],
                                  );
                                  final XFile? musicXFile = await openFile(acceptedTypeGroups: <XTypeGroup>[Platform.isIOS ? music_uniform_file_type : music_extension]);
                                  if (musicXFile == null) return;
                                  setIconState(() {
                                    uploadMusicSuccess = null;
                                    uploadMusicLoading = true;
                                  });
                                  int index = await getGameMediaIndex(widget.gameId);
                                  String filename = "$index.${musicXFile.path.split("/").last.split(".").last}";
                                  uploadMusicStream = storageRef.child("${widget.gameId}/$filename").putFile(File(musicXFile.path)).snapshotEvents;
                                  uploadMusicStream?.listen((event) {
                                    switch (event.state) {
                                      case TaskState.success:
                                        doc.reference.update({music: filename});
                                        setIconState(() {
                                          uploadMusicLoading = false;
                                          uploadMusicSuccess = true;
                                        });
                                        if(doc.data()[music] != null)storageRef.child("${widget.gameId}/${doc.data()[music]}").delete();
                                        break;
                                      case TaskState.error:
                                        setIconState(() {
                                          uploadMusicLoading = false;
                                          uploadImageSuccess = false;
                                        });
                                        break;
                                      default: break;
                                    }
                                  });
                                },);
                              }
                            ),
                          ],
                        ),
                        Wrap(spacing: 8, children: [
                          SizedBox(
                            width: 150,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: TextField(
                                controller: TextEditingController(text: doc.data()[pointsPlus].toString()),
                                decoration: const InputDecoration(
                                  labelText: "Points",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) => doc.reference.update({pointsPlus: int.tryParse(value) ?? 0}),
                                onSubmitted: (value) => Future.delayed(const Duration(milliseconds: 100), () {
                                  setState(() {});
                                }),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: TextField(
                                controller: TextEditingController(text: doc.data()[pointsMinus].toString()),
                                decoration: const InputDecoration(
                                  labelText: "Minus Points",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) => doc.reference.update({pointsMinus: int.tryParse(value) ?? 0}),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(
                          height: 16,
                        ),
                        TextField(
                          controller: TextEditingController(text: doc.data()[answerHint]),
                          decoration: const InputDecoration(
                            labelText: "Hidden Answer",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => doc.reference.update({answerHint: value}),
                        ),
                        if (doc.data()[type] == QuestionType.abcd.name) ...[
                          const SizedBox(
                            height: 16,
                          ),
                          for (var i = 0; i < 4; i++)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Text("Answer ${i + 1}"),
                                  Checkbox(
                                    value: doc.data()[answersCorrect]?[i] ?? false,
                                    onChanged: (value) async {
                                      List<bool> oldList =
                                          List<bool>.from(doc.data()[answersCorrect] ?? [false, false, false, false]);
                                      oldList[i] = value ?? false;
                                      doc.reference.update({
                                        answersCorrect: oldList,
                                      });
                                      await Future.delayed(const Duration(milliseconds: 10));
                                      setState(() {});
                                    },
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(text: doc.data()[answers]?[i]),
                                      decoration: const InputDecoration(
                                        labelText: "Answer",
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        List<String> oldList = doc.data()[answers] ?? ["", "", "", ""];
                                        oldList[i] = value;
                                        doc.reference.update({
                                          answers: oldList,
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class GamesCategoryAccessPage extends StatefulWidget {
  const GamesCategoryAccessPage({super.key, required this.gameId, required this.categoryId});

  final String gameId;
  final String categoryId;

  @override
  State<GamesCategoryAccessPage> createState() => _GamesCategoryAccessPageState();
}

//TODO only edit if you have access
class _GamesCategoryAccessPageState extends State<GamesCategoryAccessPage> {
  FirebaseFirestore db = FirebaseFirestore.instance;
  StreamSubscription? gameDocListener;
  DocumentSnapshot<Map<String, dynamic>>? gameDoc;
  StreamSubscription? categoryDocListener;
  DocumentSnapshot<Map<String, dynamic>>? categoryDoc;
  bool initialized = false;

  @override
  void initState() {
    categoryDocListener = db
        .collection(games)
        .doc(widget.gameId)
        .collection(categories)
        .doc(widget.categoryId)
        .snapshots()
        .listen((event) {
      categoryDoc = event;
      checkIfReadyAndSetState();
    });
    gameDocListener = db.collection(games).doc(widget.gameId).snapshots().listen((event) {
      gameDoc = event;
      checkIfReadyAndSetState();
    });
    super.initState();
  }

  void checkIfReadyAndSetState() {
    if (gameDoc == null || categoryDoc == null) return;
    setState(() {
      initialized = true;
    });
  }

  @override
  void dispose() {
    categoryDocListener?.cancel();
    gameDocListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const Center(child: CupertinoActivityIndicator());
    return ListView(
      children: [
        Text("Creator",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
        ListTile(
          title: FutureBuilder(
            future: db.collection(users).doc(categoryDoc!.data()?[createdBy] ?? unnamed).get(),
            builder: (context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
              if (!snapshot.hasData || snapshot.data == null) return const CupertinoActivityIndicator();
              return Text(snapshot.data!.data()?[username] ?? unnamed);
            },
          ),
        ),
        Text("Full Access",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
        for (var userId in [AccessType.admin, AccessType.full]
            .map((e) => gameDoc!.data()?[e.name] ?? [])
            .expand((element) => element))
          ListTile(
            title: FutureBuilder(
              future: db.collection(users).doc(userId).get(),
              builder: (context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
                if (!snapshot.hasData || snapshot.data == null) return const CupertinoActivityIndicator();
                return Text(snapshot.data!.data()?[username] ?? unnamed);
              },
            ),
          ),
        Text("Limited Access",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
        for (var userId in gameDoc!.data()?[AccessType.limited.name] ?? [])
          SwitchListTile(
            title: FutureBuilder(
              future: db.collection(users).doc(userId).get(),
              builder: (context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
                if (!snapshot.hasData || snapshot.data == null) return const CupertinoActivityIndicator();
                return Text(snapshot.data!.data()?[username] ?? unnamed);
              },
            ),
            value: categoryDoc!.data()?[access].contains(userId) ?? false,
            onChanged: (value) {
              if (value) {
                categoryDoc!.reference.update({
                  access: FieldValue.arrayUnion([userId])
                });
              } else {
                categoryDoc!.reference.update({
                  access: FieldValue.arrayRemove([userId])
                });
              }
            },
          ),
      ],
    );
  }
}

Future<int> getGameMediaIndex(String gameId) async {
  DocumentReference<Map<String, dynamic>> gameRef = FirebaseFirestore.instance.collection(games).doc(gameId);
  DocumentSnapshot<Map<String, dynamic>> gameDoc = await gameRef.get();
  gameRef.update({gamesMediaIndex: FieldValue.increment(1)});
  return gameDoc.data()?[gamesMediaIndex] ?? 0;
}