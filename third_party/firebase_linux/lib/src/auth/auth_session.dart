import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:path_provider/path_provider.dart';

import 'package:http/http.dart' as http;

import '../http.dart';

/// The signed-in user as Firebase Auth's REST API describes it, plus the
/// tokens. Immutable; every change makes a new one.
class StoredUser {
  const StoredUser({
    required this.uid,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
    this.providers = const [],
    this.createdAt,
    this.lastLoginAt,
  });

  final String uid;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;

  /// `providerUserInfo` from accounts:lookup, as UserInfo maps.
  final List<Map<String, Object?>> providers;
  final int? createdAt;
  final int? lastLoginAt;

  bool get isAnonymous => providers.isEmpty && email == null;

  bool hasProvider(String id) => providers.any((p) => p['providerId'] == id);

  StoredUser copyWith({
    String? idToken,
    String? refreshToken,
    DateTime? expiresAt,
    Map<String, Object?>? profile,
  }) =>
      StoredUser(
        uid: uid,
        idToken: idToken ?? this.idToken,
        refreshToken: refreshToken ?? this.refreshToken,
        expiresAt: expiresAt ?? this.expiresAt,
        email: profile == null ? email : profile['email'] as String?,
        displayName: profile == null ? displayName : profile['displayName'] as String?,
        photoUrl: profile == null ? photoUrl : profile['photoUrl'] as String?,
        emailVerified: profile == null ? emailVerified : profile['emailVerified'] == true,
        providers: profile == null ? providers : _providers(uid, profile),
        createdAt: profile == null ? createdAt : _millis(profile['createdAt']) ?? createdAt,
        lastLoginAt: profile == null ? lastLoginAt : _millis(profile['lastLoginAt']) ?? lastLoginAt,
      );

  static int? _millis(Object? value) => value is int ? value : int.tryParse('${value ?? ''}');

  static List<Map<String, Object?>> _providers(String uid, Map<String, Object?> profile) => [
        for (final p in (profile['providerUserInfo'] as List? ?? const []).cast<Map>())
          {
            'uid': p['rawId'] ?? p['federatedId'] ?? uid,
            'email': p['email'],
            'displayName': p['displayName'],
            'photoUrl': p['photoUrl'],
            'phoneNumber': p['phoneNumber'],
            'providerId': p['providerId'],
            'isAnonymous': false,
            'isEmailVerified': profile['emailVerified'] == true,
          },
      ];

  Map<String, Object?> toJson() => {
        'uid': uid,
        'idToken': idToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'emailVerified': emailVerified,
        'providers': providers,
        'createdAt': createdAt,
        'lastLoginAt': lastLoginAt,
      };

  static StoredUser fromJson(Map<String, Object?> json) => StoredUser(
        uid: json['uid']! as String,
        idToken: json['idToken']! as String,
        refreshToken: json['refreshToken']! as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expiresAt']! as int),
        email: json['email'] as String?,
        displayName: json['displayName'] as String?,
        photoUrl: json['photoUrl'] as String?,
        emailVerified: json['emailVerified'] == true,
        providers: [for (final p in (json['providers'] as List? ?? const [])) Map<String, Object?>.from(p as Map)],
        createdAt: json['createdAt'] as int?,
        lastLoginAt: json['lastLoginAt'] as int?,
      );

  InternalUserDetails toDetails() => InternalUserDetails(
        userInfo: InternalUserInfo(
          uid: uid,
          email: email,
          displayName: displayName,
          photoUrl: photoUrl,
          isAnonymous: isAnonymous,
          isEmailVerified: emailVerified,
          providerId: 'firebase',
          refreshToken: refreshToken,
          creationTimestamp: createdAt,
          lastSignInTimestamp: lastLoginAt,
        ),
        providerData: providers,
      );
}

/// Auth state of one Firebase app: who is signed in, their tokens, and the
/// calls to Firebase Auth's REST API (Identity Toolkit and Secure Token).
///
/// Firestore and Storage get their ID tokens from here.
class AuthSession {
  AuthSession._(this.appName, this.options);

  static final Map<String, AuthSession> _sessions = {};

  /// Where the signed-in user is kept between runs. Defaults to the app's
  /// support directory; tests point it elsewhere.
  static Directory? storageDirectory;

  static AuthSession of(String appName) =>
      _sessions[appName] ?? (throw StateError('Firebase app "$appName" is not initialized.'));

  /// Loads the user saved by an earlier run; registered as an app initializer.
  static Future<void> restore(FirebaseAppPlatform app) async {
    final session = _sessions[app.name] = AuthSession._(app.name, app.options);
    await session._load();
  }

  final String appName;
  final FirebaseOptions options;

  /// `http://host:port` while the Auth emulator is used.
  String? emulatorOrigin;

  StoredUser? _user;
  StoredUser? get user => _user;

  final _authChanges = StreamController<StoredUser?>.broadcast(sync: true);
  final _tokenChanges = StreamController<StoredUser?>.broadcast(sync: true);
  final _userChanges = StreamController<StoredUser?>.broadcast(sync: true);

  /// Fires when someone else signs in or the user signs out.
  Stream<StoredUser?> get authChanges => _authChanges.stream;

  /// Fires on sign-in, sign-out and every new ID token.
  Stream<StoredUser?> get tokenChanges => _tokenChanges.stream;

  /// Fires on all of the above and on profile changes.
  Stream<StoredUser?> get userChanges => _userChanges.stream;

  Future<StoredUser?>? _refreshing;

  // ---- Tokens ----------------------------------------------------------------

  /// A valid ID token for the signed-in user, refreshed when it is about to
  /// expire. Null when nobody is signed in.
  Future<String?> idToken({bool forceRefresh = false}) async {
    final user = _user;
    if (user == null) return null;
    if (!forceRefresh && user.expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return user.idToken;
    }
    return (await _refresh(user))?.idToken;
  }

  Future<StoredUser?> _refresh(StoredUser user) => _refreshing ??= () async {
        try {
          final json = await _post(
            'securetoken.googleapis.com/v1/token',
            form: {'grant_type': 'refresh_token', 'refresh_token': user.refreshToken},
          );
          // Signed out or replaced while the request was under way.
          if (_user?.uid != user.uid) return _user;
          _set(_user!.copyWith(
            idToken: json['id_token'] as String,
            refreshToken: json['refresh_token'] as String,
            expiresAt: _expiry(json['expires_in']),
          ));
          return _user;
        } on FirebaseAuthException catch (e) {
          // The account is gone or disabled, or the token was revoked:
          // the sign-in is over, as the native SDKs decide too.
          if (const {'user-not-found', 'user-disabled', 'invalid-user-token', 'user-token-expired'}.contains(e.code) &&
              _user?.uid == user.uid) {
            _set(null);
          }
          rethrow;
        } finally {
          _refreshing = null;
        }
      }();

  // ---- Sign-in ---------------------------------------------------------------

  Future<StoredUser> signInAnonymously() async {
    if (_user?.isAnonymous ?? false) return _user!;
    return _signedIn(await _post('identitytoolkit.googleapis.com/v1/accounts:signUp', json: {'returnSecureToken': true}));
  }

  Future<StoredUser> signInWithPassword(String email, String password) async => _signedIn(await _post(
        'identitytoolkit.googleapis.com/v1/accounts:signInWithPassword',
        json: {'email': email, 'password': password, 'returnSecureToken': true},
      ));

  Future<StoredUser> createUser(String email, String password) async => _signedIn(await _post(
        'identitytoolkit.googleapis.com/v1/accounts:signUp',
        json: {'email': email, 'password': password, 'returnSecureToken': true},
      ));

  Future<StoredUser> signInWithCustomToken(String token) async => _signedIn(await _post(
        'identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken',
        json: {'token': token, 'returnSecureToken': true},
      ));

  Future<void> signOut() async => _set(null);

  /// Adds an email and password to the signed-in (usually anonymous) user.
  Future<StoredUser> linkPassword(String email, String password) async {
    final user = _requireUser();
    if (user.hasProvider('password')) {
      throw FirebaseAuthException(code: 'provider-already-linked', message: 'This user already has an email and password.');
    }
    final json = await _post('identitytoolkit.googleapis.com/v1/accounts:update', json: {
      'idToken': await idToken(),
      'email': email,
      'password': password,
      'returnSecureToken': true,
    });
    return _tokensFor(user, json);
  }

  /// Signs in again as the same user, for operations that need a recent login.
  Future<StoredUser> reauthenticate(String email, String password) async {
    final user = _requireUser();
    final json = await _post(
      'identitytoolkit.googleapis.com/v1/accounts:signInWithPassword',
      json: {'email': email, 'password': password, 'returnSecureToken': true},
    );
    if (json['localId'] != user.uid) {
      throw FirebaseAuthException(code: 'user-mismatch', message: 'The credential is for another user.');
    }
    return _tokensFor(user, json);
  }

  Future<void> deleteUser() async {
    final user = _requireUser();
    await _post('identitytoolkit.googleapis.com/v1/accounts:delete', json: {'idToken': await idToken()});
    if (_user?.uid == user.uid) _set(null);
  }

  Future<StoredUser> updateAccount(Map<String, Object?> changes) async {
    final user = _requireUser();
    final json = await _post('identitytoolkit.googleapis.com/v1/accounts:update', json: {
      'idToken': await idToken(),
      ...changes,
      'returnSecureToken': true,
    });
    // A password change hands out new tokens; a profile change does not.
    return json['idToken'] is String ? _tokensFor(user, json) : reload();
  }

  /// Fetches the profile again (accounts:lookup).
  Future<StoredUser> reload() async {
    final user = _requireUser();
    final json = await _post('identitytoolkit.googleapis.com/v1/accounts:lookup', json: {'idToken': await idToken()});
    final users = json['users'] as List?;
    if (users == null || users.isEmpty) {
      if (_user?.uid == user.uid) _set(null);
      throw FirebaseAuthException(code: 'user-not-found', message: 'The user no longer exists.');
    }
    final updated = (_user ?? user).copyWith(profile: Map<String, Object?>.from(users.first as Map));
    if (_user?.uid == user.uid) _set(updated);
    return updated;
  }

  Future<void> sendOobCode(Map<String, Object?> request) async {
    final token = request['requestType'] == 'PASSWORD_RESET' ? null : await idToken();
    await _post('identitytoolkit.googleapis.com/v1/accounts:sendOobCode', json: {
      ...request,
      'idToken': ?token,
    });
  }

  StoredUser _requireUser() =>
      _user ?? (throw FirebaseAuthException(code: 'no-current-user', message: 'Nobody is signed in.'));

  Future<StoredUser> _signedIn(Map<String, Object?> json) async {
    final user = StoredUser(
      uid: json['localId']! as String,
      idToken: json['idToken']! as String,
      refreshToken: json['refreshToken']! as String,
      expiresAt: _expiry(json['expiresIn']),
      email: json['email'] as String?,
    );
    return _withProfile(user);
  }

  Future<StoredUser> _tokensFor(StoredUser user, Map<String, Object?> json) => _withProfile(user.copyWith(
        idToken: json['idToken'] as String?,
        refreshToken: json['refreshToken'] as String?,
        expiresAt: json['expiresIn'] == null ? null : _expiry(json['expiresIn']),
      ));

  /// Completes [user] with accounts:lookup and makes it the current user.
  Future<StoredUser> _withProfile(StoredUser user) async {
    try {
      final json = await _post('identitytoolkit.googleapis.com/v1/accounts:lookup', json: {'idToken': user.idToken});
      final users = json['users'] as List?;
      if (users != null && users.isNotEmpty) user = user.copyWith(profile: Map<String, Object?>.from(users.first as Map));
    } on FirebaseAuthException {
      // The sign-in itself worked; the profile is completed by the next reload.
    }
    _set(user);
    return user;
  }

  static DateTime _expiry(Object? expiresIn) =>
      DateTime.now().add(Duration(seconds: int.tryParse('${expiresIn ?? ''}') ?? 3600));

  void _set(StoredUser? user) {
    final previous = _user;
    _user = user;
    unawaited(_save());
    if (previous?.uid != user?.uid) _authChanges.add(user);
    if (previous?.uid != user?.uid || previous?.idToken != user?.idToken) _tokenChanges.add(user);
    _userChanges.add(user);
  }

  // ---- REST ------------------------------------------------------------------

  Future<Map<String, Object?>> _post(String path, {Map<String, Object?>? json, Map<String, String>? form}) async {
    final base = emulatorOrigin == null ? 'https://$path' : '$emulatorOrigin/$path';
    final uri = Uri.parse(base).replace(queryParameters: {'key': options.apiKey});
    final headers = {
      if (json != null) 'content-type': 'application/json',
      // Restricted API keys check where the request comes from.
      'x-client-version': 'Linux/Dart/firebase_linux',
    };
    final http.Response response;
    try {
      response = await httpClient
          .post(uri, headers: headers, body: json != null ? jsonEncode(json) : form)
          .timeout(const Duration(seconds: 30));
    } catch (error) {
      if (isNetworkError(error) || error is TimeoutException) {
        throw FirebaseAuthException(code: 'network-request-failed', message: '$error');
      }
      rethrow;
    }
    Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      body = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300 && body is Map) {
      return Map<String, Object?>.from(body);
    }
    final error = body is Map ? body['error'] : null;
    final message = error is Map ? '${error['message']}' : 'HTTP ${response.statusCode}';
    throw authException(message);
  }

  // ---- Persistence -----------------------------------------------------------

  Future<File?> _file() async {
    try {
      final dir = storageDirectory ?? await getApplicationSupportDirectory();
      final safe = '${options.projectId}_$appName'.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
      return File('${dir.path}/firebase_auth/$safe.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    try {
      final file = await _file();
      if (file == null || !await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      if (json is Map && json['apiKey'] == options.apiKey && json['user'] is Map) {
        _user = StoredUser.fromJson(Map<String, Object?>.from(json['user'] as Map));
      }
    } catch (_) {
      // A damaged file means signed out, not a crash.
    }
  }

  Future<void>? _saving;
  bool _saveAgain = false;

  Future<void> _save() async {
    if (_saving != null) {
      _saveAgain = true;
      return _saving;
    }
    _saving = () async {
      do {
        _saveAgain = false;
        try {
          final file = await _file();
          if (file == null) return;
          final user = _user;
          if (user == null) {
            if (await file.exists()) await file.delete();
            continue;
          }
          await file.parent.create(recursive: true);
          final temp = File('${file.path}.tmp');
          await temp.writeAsString(jsonEncode({'apiKey': options.apiKey, 'user': user.toJson()}), flush: true);
          // The refresh token is a long-lived credential: owner only.
          await Process.run('chmod', ['600', temp.path]);
          await temp.rename(file.path);
        } catch (_) {
          // Not being remembered is no reason to fail the sign-in.
        }
      } while (_saveAgain);
    }();
    try {
      await _saving;
    } finally {
      _saving = null;
    }
  }
}

/// Maps an Identity Toolkit / Secure Token error message to the error codes
/// the FlutterFire plugins use on the other platforms.
FirebaseAuthException authException(String serverMessage) {
  final parts = serverMessage.split(' : ');
  final key = parts.first.trim();
  final detail = parts.length > 1 ? parts.sublist(1).join(' : ') : null;
  final code = switch (key) {
    'EMAIL_EXISTS' => 'email-already-in-use',
    'EMAIL_NOT_FOUND' => 'user-not-found',
    'USER_NOT_FOUND' => 'user-not-found',
    'INVALID_PASSWORD' => 'wrong-password',
    'INVALID_LOGIN_CREDENTIALS' => 'invalid-credential',
    'INVALID_IDP_RESPONSE' => 'invalid-credential',
    'USER_DISABLED' => 'user-disabled',
    'TOO_MANY_ATTEMPTS_TRY_LATER' => 'too-many-requests',
    'OPERATION_NOT_ALLOWED' => 'operation-not-allowed',
    'ADMIN_ONLY_OPERATION' => 'operation-not-allowed',
    'PASSWORD_LOGIN_DISABLED' => 'operation-not-allowed',
    'INVALID_EMAIL' => 'invalid-email',
    'MISSING_EMAIL' => 'invalid-email',
    'MISSING_PASSWORD' => 'missing-password',
    'CREDENTIAL_TOO_OLD_LOGIN_AGAIN' => 'requires-recent-login',
    'TOKEN_EXPIRED' => 'user-token-expired',
    'INVALID_ID_TOKEN' => 'invalid-user-token',
    'INVALID_REFRESH_TOKEN' => 'invalid-user-token',
    'USER_MISMATCH' => 'user-mismatch',
    'CREDENTIAL_MISMATCH' => 'user-mismatch',
    'FEDERATED_USER_ID_ALREADY_LINKED' => 'credential-already-in-use',
    'INVALID_CUSTOM_TOKEN' => 'invalid-custom-token',
    'QUOTA_EXCEEDED' => 'quota-exceeded',
    _ when key.startsWith('WEAK_PASSWORD') => 'weak-password',
    _ when key.startsWith('API_KEY') || key.contains('API key') => 'invalid-api-key',
    _ => key.toLowerCase().replaceAll('_', '-'),
  };
  return FirebaseAuthException(code: code, message: detail ?? serverMessage);
}
