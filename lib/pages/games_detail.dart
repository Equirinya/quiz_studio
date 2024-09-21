import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'games_categories.dart';
import '../database/constants.dart';

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
  QuerySnapshot<Map<String, dynamic>>? categoriesDocs;
  late SharedPreferences prefs;
  bool initialized = false;

  TextEditingController newCategoryController = TextEditingController();
  late TextEditingController gameNameController;

  @override
  void initState() {
    tabController = TabController(length: 2, vsync: this);
    () async {
      prefs = await SharedPreferences.getInstance();
      gameDocListener = db.collection(games).doc(widget.gameId).snapshots().listen((event) {
        gameDoc = event;
        gameNameController = TextEditingController(text: gameDoc!.data()?[name]);
        checkIfReadyAndSetState();
      });
      //TODO only request categories that user has access to
      categoriesListener =
          db.collection(games).doc(widget.gameId).collection(categories).orderBy(createdAt).snapshots().listen((event) {
        int index = tabController?.index ?? 0;
        tabController = TabController(length: event.docs.length + 2, vsync: this, initialIndex: index);
        categoriesDocs = event;
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
          child: Text(gameDoc!.data()?[name] ?? unnamed, overflow: TextOverflow.ellipsis),
        ),
        actions: [
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
            for (String name in categoriesDocs!.docs.map((e) => e.data()[name]))
              Tab(
                text: name.length < 35 ? name : "${name.substring(0, 35)}...",
              ),
            const Tab(
              text: newCategory,
              icon: Icon(Icons.add),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: TextField(
                        controller: gameNameController,
                        decoration: const InputDecoration(
                          labelText: "Game Name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: () {
                        gameDoc!.reference.update({name: gameNameController.text});
                      },
                    ),
                    if(gameDoc!.data()?[AccessType.admin.name].contains(FirebaseAuth.instance.currentUser?.uid))
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
                                      gameDoc!.reference.delete();
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
              //TODO default points
              for (var (i, categoryDoc) in categoriesDocs!.docs.indexed)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => tabController?.animateTo(i + 1),
                      child: Card(
                          child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                          value: categoryDoc.data()[active] ?? false,
                                          onChanged: (value) => categoryDoc.reference.update({active: value ?? true})),
                                      const SizedBox(width: 8),
                                      Text(categoryDoc.data()[name]),
                                    ],
                                  ),
                                  Builder(builder: (context) {
                                    Iterable<String> fullAccess = List<String>.from([AccessType.admin, AccessType.full]
                                        .map((e) => gameDoc!.data()?[e.name] ?? [])
                                        .expand((element) => element));
                                    String creator = categoryDoc.data()[createdBy] ?? "";
                                    Iterable<String> limitedAccess =
                                        List<String>.from(gameDoc!.data()?[AccessType.limited.name] ?? []);
                                    Iterable<String> categoryAccess =
                                        List<String>.from(categoryDoc.data()[access] ?? []);
                                    Iterable<String> combinedAccess = categoryAccess
                                        .toSet()
                                        .intersection(limitedAccess.toSet())
                                        .union(fullAccess.toSet())
                                      ..add(creator);

                                    return FutureBuilder(
                                      future: Future.wait(combinedAccess
                                          .where((e) => e.isNotEmpty)
                                          .map((e) => db.collection(users).doc(e).get())),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData || snapshot.data == null)
                                          return const Text('Visible to: Loading...');
                                        return Text(
                                            'Visible to: ${snapshot.data!.map((e) => e.data()?[username] ?? 'Unknown').join(', ')}');
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
                )
            ],
          ),
          for (var category in categoriesDocs!.docs)
            GamesCategoriesEditPage(gameId: widget.gameId, categoryId: category.id),
          ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: newCategoryController,
                  decoration: const InputDecoration(hintText: 'Category Name', border: OutlineInputBorder()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                    onPressed: () async {
                      await db.collection(games).doc(widget.gameId).collection(categories).add({
                        name: newCategoryController.text,
                        active: true,
                        createdAt: FieldValue.serverTimestamp(),
                        createdBy: FirebaseAuth.instance.currentUser?.uid,
                      });
                      newCategoryController.clear();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Create Category'),
                    )),
              ),
            ],
          )
        ],
      ),
    );
  }
}

//TODO only edit the access of users with less access or only if user is admin
class GamesAccessPage extends StatefulWidget {
  const GamesAccessPage({super.key, required this.gameId});

  final String gameId;

  @override
  State<GamesAccessPage> createState() => _GamesAccessPageState();
}

class _GamesAccessPageState extends State<GamesAccessPage> {
  FirebaseFirestore db = FirebaseFirestore.instance;
  StreamSubscription? gameDocListener;
  DocumentSnapshot<Map<String, dynamic>>? gameDoc;
  bool initialized = false;

  TextEditingController newUserController = TextEditingController();
  bool? validUser;
  int userSearch = 0;

  @override
  void initState() {
    gameDocListener = db.collection(games).doc(widget.gameId).snapshots().listen((event) {
      gameDoc = event;
      setState(() {
        initialized = true;
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    gameDocListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const Center(child: CupertinoActivityIndicator());
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (String userId in gameDoc!.data()?[AccessType.admin.name] ?? [])
            MaintainerListTile(userId: userId, accessType: AccessType.admin, gameRef: gameDoc!.reference),
          for (String userId in gameDoc!.data()?[AccessType.full.name] ?? [])
            MaintainerListTile(userId: userId, accessType: AccessType.full, gameRef: gameDoc!.reference),
          for (String userId in gameDoc!.data()?[AccessType.limited.name] ?? [])
            MaintainerListTile(userId: userId, accessType: AccessType.limited, gameRef: gameDoc!.reference),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            "Add new user",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          ListTile(
            title: TextField(
              controller: newUserController,
              onChanged: (value) async {
                userSearch++;
                int searchNumber = userSearch;
                bool exists =
                    (await FirebaseFirestore.instance.collection(users).where(username, isEqualTo: value).get())
                        .docs
                        .where((element) => element.id != FirebaseAuth.instance.currentUser!.uid)
                        .isNotEmpty;
                if (searchNumber == userSearch) {
                  setState(() {
                    validUser = exists;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'Username',
                errorText: validUser == null
                    ? null
                    : validUser!
                        ? null
                        : 'User does not exist',
              ),
            ),
            trailing: ElevatedButton(
                    child: const Icon(Icons.add),
                    onPressed: validUser != null && validUser! ? () async {
                      var newUser = await FirebaseFirestore.instance
                          .collection(users)
                          .where(username, isEqualTo: newUserController.text)
                          .limit(1)
                          .get();
                      if (newUser.docs.isEmpty) {
                        setState(() {
                          validUser = false;
                        });
                        return;
                      }
                      await gameDoc!.reference.update({
                        AccessType.limited.name: FieldValue.arrayUnion([newUser.docs.first.id])
                      });
                      newUserController.clear();
                      setState(() {
                        validUser = null;
                      });
                    } : null,
                  )
               ,
          )
        ],
      ),
    );
  }
}

//TODO include searching for usernames with showSearch
// class UserSearchDelegate<String> extends SearchDelegate{
//   @override
//   List<Widget>? buildActions(BuildContext context) {
//     return null;
//   }
//
//   @override
//   Widget? buildLeading(BuildContext context) {
//     return null;
//   }
//
//   @override
//   Widget buildResults(BuildContext context) {
//     var searchTerm = searchTerm.toLowerCase();
//     strlength = searchTerm.length;
//     strFrontCode = searchTerm.slice(0, strlength-1);
//     strEndCode = searchTerm.slice(strlength-1, searchTerm.length);
//     endCode = strFrontCode + String.fromCharCode(strEndCode.charCodeAt(0) + 1);
//     FirebaseFirestore.instance.collection(users).where(username, )
//   }
//
//   @override
//   Widget buildSuggestions(BuildContext context) {
//     // TODO: implement buildSuggestions
//     throw UnimplementedError();
//   }
//
// }

class MaintainerListTile extends StatefulWidget {
  const MaintainerListTile({super.key, required this.userId, required this.accessType, required this.gameRef});

  final String userId;
  final AccessType accessType;
  final DocumentReference<Map<String, dynamic>> gameRef;

  @override
  State<MaintainerListTile> createState() => _MaintainerListTileState();
}

class _MaintainerListTileState extends State<MaintainerListTile> {
  String? maintainerUsername;

  @override
  void initState() {
    FirebaseFirestore.instance.collection(users).doc(widget.userId).get().then((value) {
      setState(() {
        maintainerUsername = value.data()?[username];
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 200),
        child:
            maintainerUsername == null ? const Center(child: CupertinoActivityIndicator()) : Text(maintainerUsername!),
      ),
      trailing: DropdownButton<AccessType>(
        value: widget.accessType,
        onChanged: (value) {
          if (value == null) return;
          widget.gameRef.update({
            if (value != AccessType.none) value.name: FieldValue.arrayUnion([widget.userId]),
            widget.accessType.name: FieldValue.arrayRemove([widget.userId])
          });
        },
        items: AccessType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.uiString))).toList(),
      ),
    );
  }
}
