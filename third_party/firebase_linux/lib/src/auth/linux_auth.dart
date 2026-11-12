// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_session.dart';

/// firebase_auth for Linux over [AuthSession]: anonymous and email/password
/// sign-in, linking, re-authentication, profile updates and deletion.
/// Everything else (phone, providers, email links, multi-factor) throws
/// `operation-not-allowed`.
class LinuxFirebaseAuth extends FirebaseAuthPlatform {
  LinuxFirebaseAuth({super.appInstance});

  static final Map<String, LinuxFirebaseAuth> _instances = {};

  AuthSession get session => AuthSession.of(app.name);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) =>
      _instances.putIfAbsent(app.name, () => LinuxFirebaseAuth(appInstance: app));

  @override
  FirebaseAuthPlatform setInitialValues({InternalUserDetails? currentUser, String? languageCode}) => this;

  UserPlatform? _wrap(StoredUser? user) => user == null ? null : LinuxUser(this, user);

  @override
  UserPlatform? get currentUser => _wrap(session.user);

  @override
  set currentUser(UserPlatform? userPlatform) {}

  @override
  String? get languageCode => null;

  @override
  Future<void> setLanguageCode(String? languageCode) async {}

  @override
  Future<void> setPersistence(Persistence persistence) async {}

  @override
  Future<void> setSettings({
    bool appVerificationDisabledForTesting = false,
    String? userAccessGroup,
    bool migrateCurrentUser = false,
    String? phoneNumber,
    String? smsCode,
    bool? forceRecaptchaFlow,
  }) async {}

  @override
  Future<void> useAuthEmulator(String host, int port) async => session.emulatorOrigin = 'http://$host:$port';

  /// Emits the current user to each new listener first, as the native SDKs do.
  Stream<UserPlatform?> _withCurrent(Stream<StoredUser?> changes) => Stream<UserPlatform?>.multi((listener) {
        listener.add(currentUser);
        final sub = changes.listen((user) => listener.add(_wrap(user)), onError: listener.addError);
        listener.onCancel = sub.cancel;
      }, isBroadcast: true);

  @override
  Stream<UserPlatform?> authStateChanges() => _withCurrent(session.authChanges);

  @override
  Stream<UserPlatform?> idTokenChanges() => _withCurrent(session.tokenChanges);

  @override
  Stream<UserPlatform?> userChanges() => _withCurrent(session.userChanges);

  UserCredentialPlatform _credential(StoredUser user, {bool isNewUser = false, String? providerId}) =>
      LinuxUserCredential(
        auth: this,
        user: LinuxUser(this, user),
        additionalUserInfo: AdditionalUserInfo(isNewUser: isNewUser, providerId: providerId),
      );

  @override
  Future<UserCredentialPlatform> signInAnonymously() async =>
      _credential(await session.signInAnonymously(), isNewUser: true);

  @override
  Future<UserCredentialPlatform> signInWithEmailAndPassword(String email, String password) async =>
      _credential(await session.signInWithPassword(email, password), providerId: 'password');

  @override
  Future<UserCredentialPlatform> createUserWithEmailAndPassword(String email, String password) async =>
      _credential(await session.createUser(email, password), isNewUser: true, providerId: 'password');

  @override
  Future<UserCredentialPlatform> signInWithCustomToken(String token) async =>
      _credential(await session.signInWithCustomToken(token));

  @override
  Future<UserCredentialPlatform> signInWithCredential(AuthCredential credential) async {
    final (email, password) = passwordCredential(credential);
    return signInWithEmailAndPassword(email, password);
  }

  @override
  Future<void> sendPasswordResetEmail(String email, [ActionCodeSettings? actionCodeSettings]) =>
      session.sendOobCode({'requestType': 'PASSWORD_RESET', 'email': email});

  @override
  Future<void> signOut() => session.signOut();
}

/// Email and password from [credential]; other kinds are not supported here.
(String, String) passwordCredential(AuthCredential credential) {
  if (credential is EmailAuthCredential && credential.password != null) {
    return (credential.email, credential.password!);
  }
  throw FirebaseAuthException(
    code: 'operation-not-allowed',
    message: 'On Linux only email and password credentials are supported, not ${credential.providerId}.',
  );
}

class LinuxUserCredential extends UserCredentialPlatform {
  LinuxUserCredential({required super.auth, super.user, super.additionalUserInfo, super.credential});
}

class _NoMultiFactor extends MultiFactorPlatform {
  _NoMultiFactor(super.auth);

  @override
  Future<List<MultiFactorInfo>> getEnrolledFactors() async => const [];
}

/// A snapshot of the signed-in user. Operations act on the session and so
/// on whoever is signed in at that moment.
class LinuxUser extends UserPlatform {
  LinuxUser(LinuxFirebaseAuth auth, this._stored) : super(auth, _NoMultiFactor(auth), _stored.toDetails());

  final StoredUser _stored;

  AuthSession get _session => (auth as LinuxFirebaseAuth).session;

  /// Operations on a user that has since signed out must fail, as natively.
  void _checkCurrent() {
    if (_session.user?.uid != _stored.uid) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'This user is no longer signed in.');
    }
  }

  UserCredentialPlatform _credential(StoredUser user, {String? providerId}) => LinuxUserCredential(
        auth: auth,
        user: LinuxUser(auth as LinuxFirebaseAuth, user),
        additionalUserInfo: AdditionalUserInfo(isNewUser: false, providerId: providerId),
      );

  @override
  Future<void> delete() async {
    _checkCurrent();
    await _session.deleteUser();
  }

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    _checkCurrent();
    return _session.idToken(forceRefresh: forceRefresh);
  }

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    final token = await getIdToken(forceRefresh);
    final claims = token == null ? const <String, Object?>{} : decodeJwtClaims(token);
    int? seconds(Object? value) => value is num ? value.toInt() * 1000 : null;
    final firebase = claims['firebase'];
    return IdTokenResult(InternalIdTokenResult(
      token: token,
      claims: claims,
      authTimestamp: seconds(claims['auth_time']),
      issuedAtTimestamp: seconds(claims['iat']),
      expirationTimestamp: seconds(claims['exp']),
      signInProvider: firebase is Map ? firebase['sign_in_provider'] as String? : null,
    ));
  }

  @override
  Future<UserCredentialPlatform> linkWithCredential(AuthCredential credential) async {
    _checkCurrent();
    final (email, password) = passwordCredential(credential);
    return _credential(await _session.linkPassword(email, password), providerId: 'password');
  }

  @override
  Future<UserCredentialPlatform> reauthenticateWithCredential(AuthCredential credential) async {
    _checkCurrent();
    final (email, password) = passwordCredential(credential);
    return _credential(await _session.reauthenticate(email, password), providerId: 'password');
  }

  @override
  Future<void> reload() async {
    _checkCurrent();
    await _session.reload();
  }

  @override
  Future<void> sendEmailVerification(ActionCodeSettings? actionCodeSettings) async {
    _checkCurrent();
    await _session.sendOobCode({'requestType': 'VERIFY_EMAIL'});
  }

  @override
  Future<void> verifyBeforeUpdateEmail(String newEmail, [ActionCodeSettings? actionCodeSettings]) async {
    _checkCurrent();
    await _session.sendOobCode({'requestType': 'VERIFY_AND_CHANGE_EMAIL', 'newEmail': newEmail});
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    _checkCurrent();
    await _session.updateAccount({'password': newPassword});
  }

  @override
  Future<void> updateProfile(Map<String, String?> profile) async {
    _checkCurrent();
    final delete = [
      for (final MapEntry(:key, :value) in profile.entries)
        if (value == null) key == 'displayName' ? 'DISPLAY_NAME' : 'PHOTO_URL',
    ];
    await _session.updateAccount({
      for (final MapEntry(:key, :value) in profile.entries)
        if (value != null) key: value,
      if (delete.isNotEmpty) 'deleteAttribute': delete,
    });
  }
}

/// The payload of a JWT, without checking its signature (the server does).
Map<String, Object?> decodeJwtClaims(String token) {
  try {
    final payload = token.split('.')[1];
    final json = utf8.decode(base64Url.decode(base64Url.normalize(payload)));
    return Map<String, Object?>.from(jsonDecode(json) as Map);
  } catch (_) {
    return const {};
  }
}
