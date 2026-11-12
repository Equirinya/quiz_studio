import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

/// Called for each app while it is initialized, before
/// [LinuxFirebase.initializeApp] returns. Auth uses it to load the signed-in
/// user from disk, so that `currentUser` is set from the first frame on, as
/// it is with the native SDKs.
typedef AppInitializer = Future<void> Function(FirebaseAppPlatform app);

/// firebase_core for Linux: apps are plain Dart objects, nothing native.
class LinuxFirebase extends FirebasePlatform {
  static final List<AppInitializer> initializers = [];

  final Map<String, LinuxFirebaseApp> _apps = {};

  @override
  List<FirebaseAppPlatform> get apps => List.unmodifiable(_apps.values);

  @override
  Future<FirebaseAppPlatform> initializeApp({String? name, FirebaseOptions? options}) async {
    name ??= defaultFirebaseAppName;
    final existing = _apps[name];
    if (existing != null) {
      if (options == null || options == existing.options) return existing;
      throw duplicateApp(name);
    }
    if (options == null) {
      throw FirebaseException(
        plugin: 'core',
        code: 'not-initialized',
        message: 'On Linux, Firebase.initializeApp needs options (DefaultFirebaseOptions.currentPlatform).',
      );
    }
    final app = LinuxFirebaseApp(this, name, options);
    for (final initializer in initializers) {
      await initializer(app);
    }
    return _apps[name] = app;
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) => _apps[name] ?? (throw noAppExists(name));

  void _remove(String name) => _apps.remove(name);
}

class LinuxFirebaseApp extends FirebaseAppPlatform {
  LinuxFirebaseApp(this._core, String name, FirebaseOptions options) : super(name, options);

  final LinuxFirebase _core;
  bool _dataCollection = false;

  @override
  bool get isAutomaticDataCollectionEnabled => _dataCollection;

  @override
  Future<void> setAutomaticDataCollectionEnabled(bool enabled) async => _dataCollection = enabled;

  @override
  Future<void> setAutomaticResourceManagementEnabled(bool enabled) async {}

  @override
  Future<void> delete() async => _core._remove(name);
}
