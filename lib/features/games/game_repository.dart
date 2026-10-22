import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:quiz_show/core/web_links.dart';
import 'package:quiz_show/game/game.dart';

/// What the signed-in user may do in a game; mirrors the three access arrays
/// on the game document and the rules in firebase/firestore.rules.
enum GameRole {
  admin("Admin"),
  full("Full Access"),
  limited("Limited Access");

  const GameRole(this.uiString);

  final String uiString;

  /// May edit everything, not just categories they created or were given.
  bool get seesEverything => this != GameRole.limited;

  static GameRole? of(Map<String, dynamic> game, String uid) {
    for (final role in GameRole.values) {
      final members = game[role.name];
      if (members is List && members.contains(uid)) return role;
    }
    return null;
  }
}

class GameSummary {
  const GameSummary({required this.id, required this.name, required this.role, this.createdAtMillis});

  final String id;
  final String name;
  final GameRole role;
  final int? createdAtMillis;
}

/// One consistent view of a game: its content plus what the editor needs
/// beyond the game core.
class GameSnapshot {
  const GameSnapshot({required this.content, required this.role, required this.data});

  final GameContent content;
  final GameRole role;

  /// The game document.
  final Map<String, dynamic> data;
}

/// An invite link as its creator sees it.
class GameInvite {
  const GameInvite({required this.gameId, required this.id, required this.role, required this.gameName, this.expiresAtMillis});

  final String gameId;
  final String id;
  final GameRole role;
  final String gameName;
  final int? expiresAtMillis;

  bool isExpired(DateTime now) => expiresAtMillis != null && expiresAtMillis! <= now.millisecondsSinceEpoch;

  /// What gets shared: a web link that opens the app, as the session QR codes do.
  String get link => toWebLink(buildInviteLink(gameId, id));
}

String buildInviteLink(String gameId, String inviteId) => 'quiz-studio://join/$gameId/$inviteId';

/// Reads an invite from a pasted link, or from a bare `gameId/inviteId`.
({String gameId, String inviteId})? parseInviteLink(String input) {
  var text = toAppLink(input);
  const prefix = 'quiz-studio://join/';
  if (text.startsWith(prefix)) text = text.substring(prefix.length);
  final parts = text.split('/');
  final valid = RegExp(r'^[A-Za-z0-9_-]+$');
  if (parts.length != 2 || !parts.every(valid.hasMatch)) return null;
  return (gameId: parts[0], inviteId: parts[1]);
}

/// A position for [GameRepository.moveCategory].
typedef CategoryOrder = Map<String, ({String? groupId, int index})>;

/// Works out the writes that move [categoryId] to [toIndex] of [toGroupId]
/// (null or the ungrouped id for "no group"). Returns only categories whose
/// group or index actually changes.
CategoryOrder planCategoryMove(GameContent content, String categoryId, String? toGroupId, int toIndex) {
  final target = toGroupId == CategoryGroup.ungroupedId ? null : toGroupId;
  final from = content.groupOfCategory(categoryId);
  if (from == null) return {};
  final fromIds = [for (final c in from.categories) c.id];
  final sameGroup = (from.isUngrouped ? null : from.id) == target;
  final toIds = sameGroup
      ? fromIds
      : [for (final c in content.group(target ?? CategoryGroup.ungroupedId)?.categories ?? const <Category>[]) c.id];

  fromIds.remove(categoryId);
  toIds.insert(toIndex.clamp(0, toIds.length), categoryId);

  final plan = <String, ({String? groupId, int index})>{};
  void assign(List<String> ids, String? groupId) {
    for (final (index, id) in ids.indexed) {
      final category = content.category(id)!;
      if (category.index != index || category.groupId != groupId) plan[id] = (groupId: groupId, index: index);
    }
  }

  assign(toIds, target);
  if (!sameGroup) assign(fromIds, from.isUngrouped ? null : from.id);
  return plan;
}

class GameRepository {
  GameRepository._();

  static final GameRepository instance = GameRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _games => _db.collection('games');

  DocumentReference<Map<String, dynamic>> _game(String gameId) => _games.doc(gameId);

  CollectionReference<Map<String, dynamic>> _groups(String gameId) => _game(gameId).collection('categoryGroups');

  CollectionReference<Map<String, dynamic>> _categories(String gameId) => _game(gameId).collection('categories');

  CollectionReference<Map<String, dynamic>> _questions(String gameId, String categoryId) =>
      _categories(gameId).doc(categoryId).collection('questions');

  // ── games ──────────────────────────────────────────────────────────────────

  /// Every game the user is a member of, oldest first.
  ///
  /// One query per access array: the rules can only prove a list query that
  /// is constrained on the caller's own uid in a single array.
  Stream<List<GameSummary>> watchMyGames() {
    final uid = _uid;
    late final StreamController<List<GameSummary>> controller;
    final results = <GameRole, List<GameSummary>>{};
    final subs = <StreamSubscription<dynamic>>[];

    void emit() {
      if (results.length < GameRole.values.length) return;
      final all = results.values.expand((list) => list).toList()
        ..sort((a, b) => (a.createdAtMillis ?? 0).compareTo(b.createdAtMillis ?? 0));
      controller.add(all);
    }

    controller = StreamController<List<GameSummary>>(
      onListen: () {
        for (final role in GameRole.values) {
          subs.add(_games.where(role.name, arrayContains: uid).orderBy('createdAt').snapshots().listen((snapshot) {
            results[role] = [
              for (final doc in snapshot.docs)
                GameSummary(
                  id: doc.id,
                  name: doc.data()['name'] is String ? doc.data()['name'] as String : '',
                  role: role,
                  createdAtMillis: _millis(doc.data()['createdAt']),
                ),
            ];
            emit();
          }, onError: controller.addError));
        }
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<String> createGame({String name = "New Game"}) async {
    final ref = _games.doc();
    await ref.set({
      'name': name,
      'locked': false,
      GameRole.admin.name: [_uid],
      GameRole.full.name: <String>[],
      GameRole.limited.name: <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _uid,
    });
    return ref.id;
  }

  Future<void> updateGame(String gameId, Map<String, dynamic> data) => _game(gameId).update(data);

  /// Deletes the game with everything in it. Media files stay in storage.
  Future<void> deleteGame(GameContent content) async {
    final writes = <DocumentReference<Map<String, dynamic>>>[
      for (final group in content.groups) ...[
        if (!group.isUngrouped) _groups(content.id).doc(group.id),
        for (final category in group.categories) ...[
          for (final question in category.questions) _questions(content.id, category.id).doc(question.id),
          _categories(content.id).doc(category.id),
        ],
      ],
      _game(content.id),
    ];
    // A batch holds at most 500 writes; the game document goes last.
    for (var i = 0; i < writes.length; i += 400) {
      final batch = _db.batch();
      for (final ref in writes.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Removes the signed-in user from the game.
  Future<void> leaveGame(String gameId) => _game(gameId).update({
        GameRole.full.name: FieldValue.arrayRemove([_uid]),
        GameRole.limited.name: FieldValue.arrayRemove([_uid]),
      });

  // ── access and invites ─────────────────────────────────────────────────────

  /// Moves [uid] to [role], or out of the game when [role] is null. Admins only.
  Future<void> setRole(String gameId, String uid, GameRole? role) => _game(gameId).update({
        for (final other in GameRole.values)
          other.name: other == role ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      });

  Stream<List<GameInvite>> watchInvites(String gameId) =>
      _game(gameId).collection('invites').orderBy('createdAt').snapshots().map((snapshot) => [
            for (final doc in snapshot.docs) ?_invite(gameId, doc.id, doc.data()),
          ]);

  Future<GameInvite> createInvite(String gameId, String gameName, GameRole role, {int validDays = 14}) async {
    final ref = _game(gameId).collection('invites').doc();
    final expires = DateTime.now().add(Duration(days: validDays));
    await ref.set({
      'role': role.name,
      'gameName': gameName,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _uid,
      'expiresAt': Timestamp.fromDate(expires),
    });
    return GameInvite(
        gameId: gameId, id: ref.id, role: role, gameName: gameName, expiresAtMillis: expires.millisecondsSinceEpoch);
  }

  Future<void> revokeInvite(String gameId, String inviteId) => _game(gameId).collection('invites').doc(inviteId).delete();

  /// Looks an invite up before joining; null when it does not exist.
  Future<GameInvite?> loadInvite(String gameId, String inviteId) async {
    final doc = await _game(gameId).collection('invites').doc(inviteId).get();
    final data = doc.data();
    return data == null ? null : _invite(gameId, inviteId, data);
  }

  /// Joins with an invite. The claim and the membership go in one batch; the
  /// rules accept the membership only alongside a claim for a valid invite.
  Future<void> joinGame(GameInvite invite) {
    final batch = _db.batch()
      ..set(_game(invite.gameId).collection('joins').doc(_uid), {
        'invite': invite.id,
        'role': invite.role.name,
        'joinedAt': FieldValue.serverTimestamp(),
      })
      ..update(_game(invite.gameId), {
        invite.role.name: FieldValue.arrayUnion([_uid]),
      });
    return batch.commit();
  }

  /// Lets a limited member see and edit a category, or takes that away.
  Future<void> shareCategory(String gameId, String categoryId, String uid, bool share) =>
      _categories(gameId).doc(categoryId).update({
        'access': share ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      });

  /// Live content of one game. With [activeOnly] false (the editor) inactive
  /// categories are included.
  Stream<GameSnapshot> watchGame(String gameId, {bool activeOnly = false}) {
    late final _GameWatcher watcher;
    final controller = StreamController<GameSnapshot>(onCancel: () => watcher.dispose());
    controller.onListen = () {
      watcher = _GameWatcher(this, gameId, _uid, activeOnly, controller)..start();
    };
    return controller.stream;
  }

  // ── category groups ────────────────────────────────────────────────────────

  Future<String> addGroup(String gameId, BoardType type, int index, {String? name}) async {
    final ref = _groups(gameId).doc();
    await ref.set({
      'name': name ?? "New ${type.uiString}",
      'categoryGroupIndex': index,
      'categoryGroupType': type.databaseString,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateGroup(String gameId, String groupId, Map<String, dynamic> data) =>
      _groups(gameId).doc(groupId).update(data);

  Future<void> deleteGroup(String gameId, String groupId) => _groups(gameId).doc(groupId).delete();

  /// Writes `categoryGroupIndex` to match [orderedGroupIds].
  Future<void> reorderGroups(String gameId, List<String> orderedGroupIds) {
    final batch = _db.batch();
    for (final (index, id) in orderedGroupIds.indexed) {
      batch.update(_groups(gameId).doc(id), {'categoryGroupIndex': index});
    }
    return batch.commit();
  }

  // ── categories ─────────────────────────────────────────────────────────────

  Future<String> addCategory(String gameId, {String? groupId, required int index, String? name}) async {
    final ref = _categories(gameId).doc();
    await ref.set({
      'name': name ?? "New Category",
      'categoryGroup': groupId == CategoryGroup.ungroupedId ? null : groupId,
      'categoryIndex': index,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });
    return ref.id;
  }

  Future<void> updateCategory(String gameId, String categoryId, Map<String, dynamic> data) =>
      _categories(gameId).doc(categoryId).update(data);

  Future<void> deleteCategory(String gameId, Category category) {
    final batch = _db.batch();
    for (final question in category.questions) {
      batch.delete(_questions(gameId, category.id).doc(question.id));
    }
    batch.delete(_categories(gameId).doc(category.id));
    return batch.commit();
  }

  Future<void> moveCategory(GameContent content, String categoryId, String? toGroupId, int toIndex) {
    final plan = planCategoryMove(content, categoryId, toGroupId, toIndex);
    if (plan.isEmpty) return Future.value();
    final batch = _db.batch();
    plan.forEach((id, position) {
      batch.update(_categories(content.id).doc(id), {'categoryGroup': position.groupId, 'categoryIndex': position.index});
    });
    return batch.commit();
  }

  // ── questions ──────────────────────────────────────────────────────────────

  /// [data] overrides the fields of the empty question.
  Future<String> addQuestion(
    String gameId,
    String categoryId, {
    int pointsPlus = 0,
    int pointsMinus = 0,
    Map<String, dynamic> data = const {},
  }) async {
    final ref = _questions(gameId, categoryId).doc();
    await ref.set({
      'type': QuestionType.free.name,
      'question': "",
      'description': "",
      'image': null,
      'music': null,
      'pointsPlus': pointsPlus,
      'pointsMinus': pointsMinus,
      'answerHint': "",
      ...data,
    });
    return ref.id;
  }

  Future<void> updateQuestion(String gameId, String categoryId, String questionId, Map<String, dynamic> data) =>
      _questions(gameId, categoryId).doc(questionId).update(data);

  /// Puts the questions of a category in the order of [questionIds]: from
  /// then on the category goes by these positions instead of by points.
  Future<void> reorderQuestions(String gameId, String categoryId, List<String> questionIds) {
    final batch = _db.batch();
    for (final (i, id) in questionIds.indexed) {
      batch.update(_questions(gameId, categoryId).doc(id), {'questionIndex': i});
    }
    return batch.commit();
  }

  Future<void> deleteQuestion(String gameId, String categoryId, String questionId) =>
      _questions(gameId, categoryId).doc(questionId).delete();
}

GameInvite? _invite(String gameId, String id, Map<String, dynamic> data) {
  final role = GameRole.values.where((role) => role.name == data['role']).firstOrNull;
  if (role == null || role == GameRole.admin) return null;
  return GameInvite(
    gameId: gameId,
    id: id,
    role: role,
    gameName: data['gameName'] is String ? data['gameName'] as String : '',
    expiresAtMillis: _millis(data['expiresAt']),
  );
}

int? _millis(Object? value) => value is Timestamp ? value.millisecondsSinceEpoch : null;

/// The game core takes `createdAt` as milliseconds, not a Firestore type.
Map<String, dynamic> _plain(Map<String, dynamic> data) =>
    data['createdAt'] is Timestamp ? {...data, 'createdAt': _millis(data['createdAt'])} : data;

/// Keeps the listeners behind [GameRepository.watchGame] and emits a snapshot
/// whenever any of them changes, once all of them have reported.
class _GameWatcher {
  _GameWatcher(this._repo, this._gameId, this._uid, this._activeOnly, this._out);

  final GameRepository _repo;
  final String _gameId;
  final String _uid;
  final bool _activeOnly;
  final StreamController<GameSnapshot> _out;

  StreamSubscription<dynamic>? _gameSub;
  StreamSubscription<dynamic>? _groupsSub;
  final List<StreamSubscription<dynamic>> _categorySubs = [];
  final Map<String, StreamSubscription<dynamic>> _questionSubs = {};

  Map<String, dynamic>? _game;
  GameRole? _role;
  Map<String, Map<String, dynamic>>? _groups;

  /// Category documents per query; a limited member needs two queries.
  final Map<int, Map<String, Map<String, dynamic>>> _categoryResults = {};
  int _categoryQueries = 0;
  final Map<String, Map<String, Map<String, dynamic>>> _questions = {};

  void start() {
    _gameSub = _repo._game(_gameId).snapshots().listen((doc) {
      final data = doc.data();
      final role = data == null ? null : GameRole.of(data, _uid);
      if (data == null || role == null) {
        _out.addError(StateError('This game no longer exists or you have no access to it.'));
        return;
      }
      _game = data;
      if (role != _role) {
        _role = role;
        _listenToContent(role);
      }
      _emit();
    }, onError: _out.addError);
  }

  void _listenToContent(GameRole role) {
    _groupsSub?.cancel();
    _groupsSub = _repo._groups(_gameId).snapshots().listen((snapshot) {
      _groups = {for (final doc in snapshot.docs) doc.id: doc.data()};
      _emit();
    }, onError: _out.addError);

    for (final sub in _categorySubs) {
      sub.cancel();
    }
    _categorySubs.clear();
    _categoryResults.clear();
    final categories = _repo._categories(_gameId);
    final queries = role.seesEverything
        ? [categories]
        : [categories.where('createdBy', isEqualTo: _uid), categories.where('access', arrayContains: _uid)];
    _categoryQueries = queries.length;
    for (final (index, query) in queries.indexed) {
      _categorySubs.add(query.snapshots().listen((snapshot) {
        _categoryResults[index] = {for (final doc in snapshot.docs) doc.id: _plain(doc.data())};
        _syncQuestionListeners();
        _emit();
      }, onError: _out.addError));
    }
  }

  Map<String, Map<String, dynamic>> get _categories => {for (final result in _categoryResults.values) ...result};

  void _syncQuestionListeners() {
    final wanted = _categories.keys.toSet();
    for (final id in _questionSubs.keys.toSet().difference(wanted)) {
      _questionSubs.remove(id)?.cancel();
      _questions.remove(id);
    }
    for (final id in wanted.difference(_questionSubs.keys.toSet())) {
      _questionSubs[id] = _repo._questions(_gameId, id).snapshots().listen((snapshot) {
        _questions[id] = {for (final doc in snapshot.docs) doc.id: doc.data()};
        _emit();
      }, onError: _out.addError);
    }
  }

  void _emit() {
    final game = _game, role = _role, groups = _groups;
    if (game == null || role == null || groups == null || _out.isClosed) return;
    if (_categoryResults.length < _categoryQueries) return;
    final categories = _categories;
    if (categories.keys.any((id) => !_questions.containsKey(id))) return;
    _out.add(GameSnapshot(
      content: GameContent.assemble(
        id: _gameId,
        game: game,
        groups: groups,
        categories: categories,
        questions: _questions,
        activeOnly: _activeOnly,
      ),
      role: role,
      data: game,
    ));
  }

  Future<void> dispose() async {
    await _gameSub?.cancel();
    await _groupsSub?.cancel();
    for (final sub in [..._categorySubs, ..._questionSubs.values]) {
      await sub.cancel();
    }
  }
}
