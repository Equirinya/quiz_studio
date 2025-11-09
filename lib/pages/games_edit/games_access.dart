import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../database/constants.dart';


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
    gameDocListener =
        db.collection(games).doc(widget.gameId).snapshots().listen((event) {
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
            MaintainerListTile(
                userId: userId,
                accessType: AccessType.admin,
                gameRef: gameDoc!.reference),
          for (String userId in gameDoc!.data()?[AccessType.full.name] ?? [])
            MaintainerListTile(
                userId: userId,
                accessType: AccessType.full,
                gameRef: gameDoc!.reference),
          for (String userId in gameDoc!.data()?[AccessType.limited.name] ?? [])
            MaintainerListTile(
                userId: userId,
                accessType: AccessType.limited,
                gameRef: gameDoc!.reference),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            "Add new user",
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          ListTile(
            title: TextField(
              controller: newUserController,
              onChanged: (value) async {
                userSearch++;
                int searchNumber = userSearch;
                bool exists = (await FirebaseFirestore.instance
                    .collection(users)
                    .where(username, isEqualTo: value)
                    .get())
                    .docs
                    .where((element) =>
                element.id != FirebaseAuth.instance.currentUser!.uid)
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
              onPressed: validUser != null && validUser!
                  ? () async {
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
                  AccessType.limited.name:
                  FieldValue.arrayUnion([newUser.docs.first.id])
                });
                newUserController.clear();
                setState(() {
                  validUser = null;
                });
              }
                  : null,
            ),
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
  const MaintainerListTile(
      {super.key,
        required this.userId,
        required this.accessType,
        required this.gameRef});

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
    FirebaseFirestore.instance
        .collection(users)
        .doc(widget.userId)
        .get()
        .then((value) {
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
        child: maintainerUsername == null
            ? const Center(child: CupertinoActivityIndicator())
            : Text(maintainerUsername!),
      ),
      trailing: DropdownButton<AccessType>(
        value: widget.accessType,
        onChanged: (value) {
          if (value == null) return;
          widget.gameRef.update({
            if (value != AccessType.none)
              value.name: FieldValue.arrayUnion([widget.userId]),
            widget.accessType.name: FieldValue.arrayRemove([widget.userId])
          });
        },
        items: AccessType.values
            .map((e) => DropdownMenuItem(value: e, child: Text(e.uiString)))
            .toList(),
      ),
    );
  }
}
