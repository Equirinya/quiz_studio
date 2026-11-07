import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Shortest and longest display name the app accepts. The Firestore rules
/// enforce their own (wider) bounds; see `validUsername` in firestore.rules.
const int kUsernameMinLength = 3;
const int kUsernameMaxLength = 40;

/// Reads and writes the signed-in user's two profile documents:
/// `users/{uid}` (private) and `users_public/{uid}` (the name others see).
class UserService {
  UserService._();

  static final UserService instance = UserService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _private(String uid) => _db.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _public(String uid) => _db.collection('users_public').doc(uid);

  /// The username stored for the current user, or `null` when they have no
  /// profile yet (a sign-in that never got as far as choosing a name).
  Future<String?> loadUsername() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _private(uid).get();
    final username = doc.data()?['username'];
    return username is String && username.trim().length >= kUsernameMinLength ? username : null;
  }

  final Map<String, Future<String?>> _names = {};

  /// The public display name of any user, cached for the session. Null when
  /// they have none yet, which is the case for a v1 account that has not
  /// opened v2 so far.
  Future<String?> usernameOf(String uid) => _names.putIfAbsent(uid, () async {
        try {
          final name = (await _public(uid).get()).data()?['username'];
          return name is String && name.isNotEmpty ? name : null;
        } catch (_) {
          _names.remove(uid);
          return null;
        }
      });

  /// Creates both profile documents for a user who has none.
  Future<void> createProfile(String username) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final batch = _db.batch()
      ..set(_private(uid), {
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      })
      ..set(_public(uid), {
        'username': username,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    await batch.commit();
  }

  /// Changes the display name, in the private profile and its public mirror.
  Future<void> rename(String username) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final batch = _db.batch()
      ..update(_private(uid), {'username': username})
      ..set(_public(uid), {'username': username, 'updatedAt': FieldValue.serverTimestamp()});
    await batch.commit();
    _names[uid] = Future.value(username);
  }

  /// Turns the signed-in guest account into one with an email address and
  /// password. The account stays the same one, with all its games; from then
  /// on it can be signed in to on other devices. Returns null on success, or
  /// a message to show.
  Future<String?> addEmailAndPassword(String email, String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'You are not signed in.';
    try {
      await user.linkWithCredential(EmailAuthProvider.credential(email: email, password: password));
      return null;
    } on FirebaseAuthException catch (e) {
      return upgradeErrorMessage(e.code);
    } catch (_) {
      return upgradeErrorMessage('');
    }
  }

  /// Run once per launch for a user who already has a profile: stamps
  /// `lastLogin` and writes the public mirror if it is missing, which is the
  /// case for every account created by v1 (it only wrote `users/{uid}`).
  Future<void> onLogin(String username) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _private(uid).update({'lastLogin': FieldValue.serverTimestamp()});
    final public = await _public(uid).get();
    if (!public.exists) {
      await _public(uid).set({
        'username': username,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

/// What to tell the user when adding an email address and password fails.
String upgradeErrorMessage(String code) => switch (code) {
      'email-already-in-use' || 'credential-already-in-use' =>
        'There is already an account with this email address. Sign in to that one instead.',
      'invalid-email' => 'That is not a valid email address.',
      'weak-password' => 'Please choose a stronger password.',
      'provider-already-linked' => 'This account already has an email address.',
      'requires-recent-login' => 'For safety, please restart the app and try again.',
      'network-request-failed' => "You're not connected to the internet.",
      'operation-not-allowed' => 'Email sign-in is switched off for this app.',
      _ => 'That did not work. Please try again.',
    };
