import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/game/game.dart';

class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.name,
    this.gameId,
    this.host,
    this.invited = const [],
    this.hostDevice,
    this.createdAtMillis,
    this.updatedAtMillis,
  });

  final String id;
  final String name;
  final String? gameId;

  /// The owner's uid.
  final String? host;

  /// The users who joined with the session's invite link: they control it
  /// from their own devices and see it in their list.
  final List<String> invited;

  /// The device presenting this session at the moment, if any.
  final String? hostDevice;
  final int? createdAtMillis;

  /// Written by the presenting device whenever the show changes, and
  /// regularly while it is quiet.
  final int? updatedAtMillis;

  /// Whether a device is presenting right now: one claimed the session and
  /// has been heard from lately. [now] is this device's clock, which may be
  /// off a little.
  bool presentingAt(int now) =>
      hostDevice != null && updatedAtMillis != null && now - updatedAtMillis! < FirestoreHostLink.heartbeat.inMilliseconds * 3;
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
      _sessions.where('host', isEqualTo: _uid).snapshots().map((snapshot) => sortSessions([
            for (final doc in snapshot.docs) _summary(doc.id, doc.data()),
          ]));

  /// Sessions someone else hosts and invited the user to. Asked only once
  /// `config/app` says `invites: true`, that is once the rules know invites:
  /// a query the rules turn down breaks every other listener of the Firestore
  /// client on desktop ("Target id not found").
  Stream<List<SessionSummary>> watchInvitedSessions() async* {
    bool enabled;
    try {
      enabled = (await _db.collection('config').doc('app').get()).data()?['invites'] == true;
    } catch (_) {
      enabled = false;
    }
    if (!enabled) {
      yield const [];
      return;
    }
    yield* _sessions.where('invited', arrayContains: _uid).snapshots().map((snapshot) => sortSessions([
          for (final doc in snapshot.docs) _summary(doc.id, doc.data()),
        ]));
  }

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
  Future<void> setGame(String sessionId, String? gameId, {String? name}) =>
      session(sessionId).update({'gameId': gameId, 'name': ?name});

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
      // The invite link has a token of its own, which the QR codes leave alone.
      if (isInviteToken(doc.data())) continue;
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

  /// Puts the pictures of a matching round where every device of the
  /// session can fetch them. Host only; together well under 1 MiB.
  Future<void> publishPictures(String sessionId, Map<String, Uint8List> pictures) =>
      session(sessionId).collection('public').doc('pictures').set({
        'images': [for (final MapEntry(key: name, value: bytes) in pictures.entries) {'name': name, 'image': Blob(bytes)}],
      });

  Stream<Map<String, Uint8List>> watchPictures(String sessionId) =>
      session(sessionId).collection('public').doc('pictures').snapshots().map((doc) => {
            for (final entry in doc.data()?['images'] as List? ?? const [])
              if (entry is Map && entry['name'] is String && entry['image'] is Blob) entry['name'] as String: (entry['image'] as Blob).bytes,
          });

  Stream<List<String>> watchLanEndpoints(String sessionId) => session(sessionId)
      .collection('public')
      .doc('lan')
      .snapshots()
      .map((doc) => (doc.data()?['endpoints'] as List? ?? const []).whereType<String>().toList());

  /// Joins someone else's session with a scanned link.
  Future<void> join(SessionJoinLink link, {String name = ''}) =>
      session(link.sessionId).collection('members').doc(_uid).set(_memberData(link, name));

  Map<String, Object?> _memberData(SessionJoinLink link, String name) => {
        'token': link.token,
        'role': link.role.name,
        'teamId': ?link.teamId,
        'name': name,
        'joinedAt': FieldValue.serverTimestamp(),
      };

  Future<SessionMembership?> loadMembership(String sessionId) async {
    final data = (await session(sessionId).collection('members').doc(_uid).get()).data();
    if (data == null) return null;
    return SessionMembership(
      role: data['role'] == 'controller' ? Role.controller : Role.player,
      teamId: data['teamId'] as String?,
    );
  }

  Future<void> leave(String sessionId) => session(sessionId).collection('members').doc(_uid).delete();

  // ── inviting ───────────────────────────────────────────────────────────────

  /// The session's invite link, made on first use. With [renew] the old link
  /// stops working; whoever joined with it stays in. Host only.
  Future<SessionInviteLink> inviteLink(String sessionId, {bool renew = false}) async {
    final tokens = session(sessionId).collection('tokens');
    final existing = await tokens.where('invite', isEqualTo: true).get();
    if (renew) {
      for (final doc in existing.docs) {
        await doc.reference.delete();
      }
    } else if (existing.docs.isNotEmpty) {
      return SessionInviteLink(sessionId: sessionId, token: existing.docs.first.id);
    }
    final token = _randomId(20);
    await tokens.doc(token).set({'role': Role.controller.name, 'invite': true, 'createdAt': FieldValue.serverTimestamp()});
    return SessionInviteLink(sessionId: sessionId, token: token);
  }

  /// Joins as a controller with an invite and puts the session in the user's
  /// list. Both go in one batch: the rules let a user add themselves to
  /// `invited` only alongside a controller membership from an invite token.
  ///
  /// Where the rules do not allow that yet, it joins as a controller only and
  /// returns false: the show can be controlled, but the session is not listed.
  Future<bool> acceptInvite(SessionInviteLink link) async {
    final batch = _db.batch()
      ..set(session(link.sessionId).collection('members').doc(_uid), _memberData(link.joinLink, ''))
      ..update(session(link.sessionId), {
        'invited': FieldValue.arrayUnion([_uid]),
      });
    try {
      await batch.commit();
      return true;
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      await join(link.joinLink);
      return false;
    }
  }

  /// Takes [uid] out of the session: off the list, and no longer a
  /// controller. Host only.
  Future<void> removeInvited(String sessionId, String uid) => _uninvite(sessionId, uid);

  /// Takes the session off the user's own list and leaves it.
  Future<void> leaveInvited(String sessionId) => _uninvite(sessionId, _uid);

  Future<void> _uninvite(String sessionId, String uid) => (_db.batch()
        ..delete(session(sessionId).collection('members').doc(uid))
        ..update(session(sessionId), {
          'invited': FieldValue.arrayRemove([uid]),
        }))
      .commit();

  /// How the user controls a session they were invited to; null once they
  /// are no longer a controller of it.
  Future<SessionJoinLink?> invitedControllerLink(String sessionId) async {
    final data = (await session(sessionId).collection('members').doc(_uid).get()).data();
    final token = data?['token'];
    if (data?['role'] != Role.controller.name || token is! String) return null;
    return SessionJoinLink(sessionId: sessionId, token: token, role: Role.controller);
  }

  // ── as a controller or player ──────────────────────────────────────────────

  /// The full state, for the host's other devices and for controllers.
  Stream<SessionState?> watchState(String sessionId) => session(sessionId).snapshots().map((doc) {
        final state = doc.data()?['state'];
        return state is Map ? SessionState.fromJson(Map<String, dynamic>.from(state)) : null;
      });

  /// What players may see; with [teamId], that team's own view.
  Stream<PublicView?> watchPublicState(String sessionId, {String? teamId}) =>
      session(sessionId).collection('public').doc(teamId == null ? 'state' : 'team_$teamId').snapshots().map((doc) {
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

/// Newest first.
List<SessionSummary> sortSessions(List<SessionSummary> sessions) =>
    sessions..sort((a, b) => (b.createdAtMillis ?? 0).compareTo(a.createdAtMillis ?? 0));

/// Whether a token document is the one behind the invite link rather than a
/// QR code.
bool isInviteToken(Map<String, dynamic> data) => data['invite'] == true;

/// A session document as the list shows it.
@visibleForTesting
SessionSummary sessionSummaryOf(String id, Map<String, dynamic> data) => _summary(id, data);

SessionSummary _summary(String id, Map<String, dynamic> data) => SessionSummary(
      id: id,
      name: data['name'] is String ? data['name'] as String : '',
      gameId: data['gameId'] as String?,
      host: data['host'] is String ? data['host'] as String : null,
      invited: [for (final uid in data['invited'] as List? ?? const []) if (uid is String) uid],
      hostDevice: data['hostDevice'] as String?,
      createdAtMillis: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).millisecondsSinceEpoch : null,
      updatedAtMillis: data['updatedAt'] is Timestamp ? (data['updatedAt'] as Timestamp).millisecondsSinceEpoch : null,
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

  /// The team views as last written, so an unchanged one is not written again.
  final Map<String, String> _teamViews = {};
  bool _writing = false;
  bool _dirty = false;
  bool _stopped = false;
  Timer? _alive;

  /// How often a quiet presenter says it is still there.
  static const Duration heartbeat = Duration(seconds: 45);

  DocumentReference<Map<String, dynamic>> get _ref => SessionRepository.instance.session(sessionId);

  /// The state the session was left in, to resume a show after a restart.
  static Future<SessionState> loadState(String sessionId) async {
    final state = (await SessionRepository.instance.session(sessionId).get()).data()?['state'];
    return state is Map ? SessionState.fromJson(Map<String, dynamic>.from(state)) : const SessionState();
  }

  /// Stores [state] while no device runs the session, as when it is set up
  /// before the show.
  static Future<void> saveState(String sessionId, SessionState state) =>
      SessionRepository.instance.session(sessionId).update({'state': state.toJson(), 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> start() async {
    await _ref.update({'hostDevice': deviceId, 'updatedAt': FieldValue.serverTimestamp()});
    // Controllers tell from this whether anyone is presenting.
    _alive = Timer.periodic(heartbeat, (_) {
      if (!_stopped && !displaced.value) _ref.update({'updatedAt': FieldValue.serverTimestamp()}).catchError((Object _) {});
    });
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
        // Each team reads its own copy, which carries what only it may see.
        final written = <String, String>{};
        for (final team in state.teams) {
          final view = host.publicStateFor(team.id);
          final encoded = jsonEncode(view);
          written[team.id] = encoded;
          if (_teamViews[team.id] != encoded) batch.set(_ref.collection('public').doc('team_${team.id}'), view);
        }
        await batch.commit();
        _teamViews
          ..clear()
          ..addAll(written);
      } catch (error) {
        if (kDebugMode) print('Session: could not publish state: $error');
      }
    } while (_dirty && !_stopped);
    _writing = false;
  }

  Future<void> stop() async {
    _stopped = true;
    _alive?.cancel();
    // Nobody presents any more, unless another device took over.
    if (!displaced.value) _ref.update({'hostDevice': null}).catchError((Object _) {});
    await _commands?.cancel();
    await _session?.cancel();
    await _states?.cancel();
  }
}
