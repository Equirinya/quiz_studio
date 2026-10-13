import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<void> addGroup(String gameId, BoardType type, int index) => _groups(gameId).add({
        'name': "New ${type.uiString}",
        'categoryGroupIndex': index,
        'categoryGroupType': type.databaseString,
        'createdBy': _uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

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

  Future<String> addCategory(String gameId, {String? groupId, required int index}) async {
    final ref = _categories(gameId).doc();
    await ref.set({
      'name': "New Category",
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

  Future<String> addQuestion(String gameId, String categoryId, {int pointsPlus = 0, int pointsMinus = 0}) async {
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
    });
    return ref.id;
  }

  Future<void> updateQuestion(String gameId, String categoryId, String questionId, Map<String, dynamic> data) =>
      _questions(gameId, categoryId).doc(questionId).update(data);

  Future<void> deleteQuestion(String gameId, String categoryId, String questionId) =>
      _questions(gameId, categoryId).doc(questionId).delete();
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
