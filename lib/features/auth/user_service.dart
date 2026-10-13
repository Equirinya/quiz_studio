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
