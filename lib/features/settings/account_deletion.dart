import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/session/session_repository.dart';

/// How someone who deletes their account leaves one game.
sealed class GameExit {
  const GameExit();
}

/// Nobody else is in it: the game goes, with its media.
class DeleteGame extends GameExit {
  const DeleteGame();
}

/// Others stay: the account takes itself off the game's lists, after
/// [promote] has been made admin when the account was the only one.
class LeaveGame extends GameExit {
  const LeaveGame({this.promote});
  final String? promote;
}

/// What [uid] does with a game whose document holds [data]: an only admin
/// hands the game to a full member, or failing that a limited one, so a game
/// is never left without an admin; a game with nobody else in it is deleted.
GameExit exitFor(String uid, Map<String, dynamic> data) {
  List<String> list(String field) => [for (final e in data[field] as List? ?? const []) '$e'];
  final admins = list('admin').where((id) => id != uid).toList();
  final full = list('full').where((id) => id != uid).toList();
  final limited = list('limited').where((id) => id != uid).toList();
  if (!list('admin').contains(uid) || admins.isNotEmpty) return const LeaveGame();
  final heir = full.firstOrNull ?? limited.firstOrNull;
  return heir == null ? const DeleteGame() : LeaveGame(promote: heir);
}

/// Deletes the signed-in account and what is only its own: games nobody
/// else is in (with their pictures and sounds), the sessions it hosts, and
/// its profile. Shared games are handed over or left. The sign-in goes last.
///
/// Firebase only deletes a sign-in that was made recently; an account with
/// an email address is therefore asked for its password first ([password]),
/// so that nothing is deleted while the last step would still fail.
Future<void> deleteAccount({String? password}) async {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  if (user == null) throw StateError("Not signed in.");
  if (user.email != null && password != null) {
    await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password));
  }
  final db = FirebaseFirestore.instance;
  final uid = user.uid;

  // Games, one query per access list (the rules only allow those).
  final docs = <String, Map<String, dynamic>>{};
  for (final role in GameRole.values) {
    final snapshot = await db.collection('games').where(role.name, arrayContains: uid).get();
    for (final doc in snapshot.docs) {
      docs[doc.id] = doc.data();
    }
  }
  for (final MapEntry(key: gameId, value: data) in docs.entries) {
    switch (exitFor(uid, data)) {
      case DeleteGame():
        final content = (await GameRepository.instance.watchGame(gameId).first).content;
        for (final name in content.mediaPaths) {
          await MediaService.instance.delete(gameId, name);
        }
        await GameRepository.instance.deleteGame(content);
      case LeaveGame(:final promote):
        await db.collection('games').doc(gameId).update({
          if (promote != null) 'admin': [promote] else 'admin': FieldValue.arrayRemove([uid]),
          'full': FieldValue.arrayRemove([uid, ?promote]),
          'limited': FieldValue.arrayRemove([uid, ?promote]),
        });
    }
  }

  // Sessions it hosts.
  final sessions = await db.collection('sessions').where('host', isEqualTo: uid).get();
  for (final session in sessions.docs) {
    try {
      await SessionRepository.instance.deleteSession(session.id);
    } catch (error) {
      if (kDebugMode) print('Account: could not delete session ${session.id}: $error');
    }
  }

  // The profile, then the sign-in itself.
  await db.batch().commitDeletes([db.collection('users_public').doc(uid), db.collection('users').doc(uid)]);
  await user.delete();
}

extension on WriteBatch {
  Future<void> commitDeletes(List<DocumentReference<Map<String, dynamic>>> refs) {
    for (final ref in refs) {
      delete(ref);
    }
    return commit();
  }
}
