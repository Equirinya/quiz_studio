import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/game/game.dart';

class SessionSummary {
  const SessionSummary({required this.id, required this.name, this.gameId, this.hostDevice, this.createdAtMillis});

  final String id;
  final String name;
  final String? gameId;

  /// The device presenting this session at the moment, if any.
  final String? hostDevice;
  final int? createdAtMillis;
}

/// A device's own membership of someone else's session.
class SessionMembership {
  const SessionMembership({required this.role, this.teamId});

  final Role role;
  final String? teamId;
}

String _randomId(int length) {
  const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return String.fromCharCodes([for (var i = 0; i < length; i++) alphabet.codeUnitAt(random.nextInt(alphabet.length))]);
}

/// A new team id; short, because it travels in QR codes.
String newTeamId() => _randomId(8);

class SessionRepository {
  SessionRepository._();

  static final SessionRepository instance = SessionRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _sessions => _db.collection('sessions');

  DocumentReference<Map<String, dynamic>> session(String sessionId) => _sessions.doc(sessionId);

  String? _deviceId;

  /// Identifies this installation, to tell the host's devices apart.
  Future<String> deviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('deviceId');
    if (id == null) {
      id = _randomId(16);
      await prefs.setString('deviceId', id);
    }
    return _deviceId = id;
  }

  // ── sessions the user hosts ────────────────────────────────────────────────

  Stream<List<SessionSummary>> watchMySessions() =>
      _sessions.where('host', isEqualTo: _uid).snapshots().map((snapshot) => [
            for (final doc in snapshot.docs) _summary(doc.id, doc.data()),
          ]..sort((a, b) => (b.createdAtMillis ?? 0).compareTo(a.createdAtMillis ?? 0)));

  Stream<SessionSummary?> watchSession(String sessionId) =>
      session(sessionId).snapshots().map((doc) => doc.data() == null ? null : _summary(doc.id, doc.data()!));

  Future<String> createSession({required String name, String? gameId}) async {
    final ref = _sessions.doc();
    await ref.set({
      'host': _uid,
      'name': name,
      'gameId': gameId,
      'createdAt': FieldValue.serverTimestamp(),
      'state': SessionState(gameId: gameId).toJson(),
    });
    return ref.id;
  }

  Future<void> renameSession(String sessionId, String name) => session(sessionId).update({'name': name});

  /// Chooses the game a session plays. The presenting device picks the change
  /// up from the document and resets the board; if none is presenting, the
  /// next one to start does.
  Future<void> setGame(String sessionId, String? gameId) => session(sessionId).update({'gameId': gameId});

  /// Deletes the session and what belongs to it. Best effort for the
  /// subcollections: a document that slips through is unreachable anyway.
  Future<void> deleteSession(String sessionId) async {
    for (final name in ['commands', 'members', 'tokens', 'public']) {
      try {
        final docs = await session(sessionId).collection(name).get();
        for (final doc in docs.docs) {
          await doc.reference.delete();
        }
      } catch (error) {
        if (kDebugMode) print('Session: could not clear $name: $error');
      }
    }
    await session(sessionId).delete();
  }

  // ── joining ────────────────────────────────────────────────────────────────

  /// Creates a join token and returns the link to put in a QR code.
  Future<SessionJoinLink> createJoinLink(String sessionId, Role role, {String? teamId}) async {
    final token = _randomId(20);
    await session(sessionId).collection('tokens').doc(token).set({
      'role': role.name,
      'teamId': ?teamId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return SessionJoinLink(sessionId: sessionId, token: token, role: role, teamId: teamId);
  }

  /// The join links for a controller and for each team, reusing tokens that
  /// exist already so codes shown earlier keep working. Host only.
  Future<({SessionJoinLink controller, Map<String, SessionJoinLink> players})> joinLinks(
    String sessionId,
    Iterable<String> teamIds,
  ) async {
    final existing = await session(sessionId).collection('tokens').get();
    SessionJoinLink? controller;
    final players = <String, SessionJoinLink>{};
    for (final doc in existing.docs) {
      final teamId = doc.data()['teamId'];
      if (doc.data()['role'] == 'controller') {
        controller ??= SessionJoinLink(sessionId: sessionId, token: doc.id, role: Role.controller);
      } else if (teamId is String) {
        players.putIfAbsent(teamId, () => SessionJoinLink(sessionId: sessionId, token: doc.id, role: Role.player, teamId: teamId));
      }
    }
    controller ??= await createJoinLink(sessionId, Role.controller);
    for (final teamId in teamIds) {
      players[teamId] ??= await createJoinLink(sessionId, Role.player, teamId: teamId);
    }
    return (controller: controller, players: players);
  }

  /// The join tokens as the LAN server needs them, kept up to date. Host only.
  Stream<Map<String, ({Role role, String? teamId})>> watchTokens(String sessionId) =>
      session(sessionId).collection('tokens').snapshots().map((snapshot) => {
            for (final doc in snapshot.docs)
              doc.id: (
                role: doc.data()['role'] == 'controller' ? Role.controller : Role.player,
                teamId: doc.data()['teamId'] as String?,
              ),
          });

  /// Tells the session's devices where the presenter listens on the local
  /// network. Host only.
  Future<void> publishLanEndpoints(String sessionId, List<String> endpoints) =>
      session(sessionId).collection('public').doc('lan').set({
        'endpoints': endpoints,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Puts the picture of a whiteboard round where every device of the
  /// session can fetch it. Host only; [bytes] must stay well under 1 MiB.
  Future<void> publishBackground(String sessionId, String name, Uint8List bytes) =>
      session(sessionId).collection('public').doc('background').set({'name': name, 'image': Blob(bytes)});

  Stream<(String, Uint8List)?> watchBackground(String sessionId) =>
      session(sessionId).collection('public').doc('background').snapshots().map((doc) {
        final name = doc.data()?['name'];
        final image = doc.data()?['image'];
        return name is String && image is Blob ? (name, image.bytes) : null;
      });

  Stream<List<String>> watchLanEndpoints(String sessionId) => session(sessionId)
      .collection('public')
      .doc('lan')
      .snapshots()
      .map((doc) => (doc.data()?['endpoints'] as List? ?? const []).whereType<String>().toList());

  /// Joins someone else's session with a scanned link.
  Future<void> join(SessionJoinLink link, {String name = ''}) =>
      session(link.sessionId).collection('members').doc(_uid).set({
        'token': link.token,
        'role': link.role.name,
        'teamId': ?link.teamId,
        'name': name,
        'joinedAt': FieldValue.serverTimestamp(),
      });

  Future<SessionMembership?> loadMembership(String sessionId) async {
    final data = (await session(sessionId).collection('members').doc(_uid).get()).data();
    if (data == null) return null;
    return SessionMembership(
      role: data['role'] == 'controller' ? Role.controller : Role.player,
      teamId: data['teamId'] as String?,
    );
  }

  Future<void> leave(String sessionId) => session(sessionId).collection('members').doc(_uid).delete();

  // ── as a controller or player ──────────────────────────────────────────────

  /// The full state, for the host's other devices and for controllers.
  Stream<SessionState?> watchState(String sessionId) => session(sessionId).snapshots().map((doc) {
        final state = doc.data()?['state'];
        return state is Map ? SessionState.fromJson(Map<String, dynamic>.from(state)) : null;
      });

  /// What players may see.
  Stream<PublicView?> watchPublicState(String sessionId) =>
      session(sessionId).collection('public').doc('state').snapshots().map((doc) {
        final data = doc.data();
        return data == null ? null : PublicView(data);
      });

  /// Puts a command into the presenting device's inbox.
  Future<void> sendCommand(String sessionId, Command command, {required Role role, String? teamId}) =>
      session(sessionId).collection('commands').add({
        'uid': _uid,
        'role': role == Role.player ? 'player' : 'controller',
        'teamId': ?teamId,
        'command': command.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });
}

SessionSummary _summary(String id, Map<String, dynamic> data) => SessionSummary(
      id: id,
      name: data['name'] is String ? data['name'] as String : '',
      gameId: data['gameId'] as String?,
      hostDevice: data['hostDevice'] as String?,
      createdAtMillis: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).millisecondsSinceEpoch : null,
    );

/// Sends commands over Firestore; for every device that is not presenting.
class RemoteCommandSink implements CommandSink {
  RemoteCommandSink(this.sessionId, {required this.role, this.teamId, this.onError});

  final String sessionId;
  final Role role;
  final String? teamId;
  final void Function(Object error)? onError;

  @override
  void send(Command command) {
    SessionRepository.instance
        .sendCommand(sessionId, command, role: role, teamId: teamId)
        .catchError((Object error) => onError?.call(error));
  }
}

/// Connects a [SessionHost] on the presenting device to Firestore: commands
/// from other devices come in through the inbox, every new state goes out to
/// the session document and its public view.
class FirestoreHostLink {
  FirestoreHostLink(this.sessionId, this.host, this.deviceId);

  final String sessionId;
  final SessionHost host;
  final String deviceId;

  /// Turns true when another of the host's devices took over presenting; this
  /// device must stop then, or two hosts would overwrite each other.
  final ValueNotifier<bool> displaced = ValueNotifier(false);

  StreamSubscription<dynamic>? _commands;
  StreamSubscription<dynamic>? _session;
  StreamSubscription<SessionState>? _states;
  bool _backlogDropped = false;
  bool _writing = false;
  bool _dirty = false;
  bool _stopped = false;

  DocumentReference<Map<String, dynamic>> get _ref => SessionRepository.instance.session(sessionId);

  /// The state the session was left in, to resume a show after a restart.
  static Future<SessionState> loadState(String sessionId) async {
    final state = (await SessionRepository.instance.session(sessionId).get()).data()?['state'];
    return state is Map ? SessionState.fromJson(Map<String, dynamic>.from(state)) : const SessionState();
  }

  Future<void> start() async {
    await _ref.update({'hostDevice': deviceId});
    _publish();
    _states = host.states.listen((_) => _publish());

    _session = _ref.snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) return;
      final presenting = data['hostDevice'];
      if (!doc.metadata.hasPendingWrites && presenting is String && presenting != deviceId) displaced.value = true;
      // The game is chosen on the session document, outside the show.
      final gameId = data['gameId'] as String?;
      if (gameId != host.state.gameId) host.dispatch(SetGame(gameId));
    });

    _commands = _ref.collection('commands').orderBy('createdAt').snapshots().listen((snapshot) {
      // Whatever piled up while nobody was presenting is stale: a buzz from
      // before the restart must not count now.
      final drop = !_backlogDropped;
      _backlogDropped = true;
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        if (!drop) _apply(change.doc.data() ?? const {});
        change.doc.reference.delete();
      }
    });
  }

  void _apply(Map<String, dynamic> data) {
    final json = data['command'];
    final command = json is Map ? Command.fromJson(Map<String, dynamic>.from(json)) : null;
    if (command == null) return;
    // The rules have checked role and team against the sender's member doc.
    final sender = data['role'] == 'player'
        ? Sender(Role.player, teamId: data['teamId'] as String?)
        : const Sender(Role.controller);
    host.dispatch(command, sender: sender);
  }

  /// Writes the latest state. While a write is under way newer states are
  /// not queued one by one; only the newest goes out next.
  Future<void> _publish() async {
    if (_stopped || displaced.value) return;
    if (_writing) {
      _dirty = true;
      return;
    }
    _writing = true;
    do {
      _dirty = false;
      final state = host.state;
      try {
        final batch = SessionRepository.instance._db.batch()
          ..update(_ref, {
            'state': state.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(_ref.collection('public').doc('state'), host.publicState);
        await batch.commit();
      } catch (error) {
        if (kDebugMode) print('Session: could not publish state: $error');
      }
    } while (_dirty && !_stopped);
    _writing = false;
  }

  Future<void> stop() async {
    _stopped = true;
    await _commands?.cancel();
    await _session?.cancel();
    await _states?.cancel();
  }
}
