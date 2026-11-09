/// Linux implementations of firebase_core, firebase_auth, cloud_firestore and
/// firebase_storage, in Dart only. Flutter registers them on Linux through
/// `dartPluginClass`; on every other platform this package does nothing.
library;

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_storage_platform_interface/firebase_storage_platform_interface.dart';

import 'src/auth/auth_session.dart';
import 'src/auth/linux_auth.dart';
import 'src/core.dart';
import 'src/firestore/linux_firestore.dart';
import 'src/firestore/writes.dart';
import 'src/storage/linux_storage.dart';

export 'src/auth/auth_session.dart' show AuthSession;

class FirebaseLinux {
  static bool _registered = false;

  /// Called by Flutter's plugin registrant before `main` on Linux.
  static void registerWith() {
    if (_registered) return;
    _registered = true;
    LinuxFirebase.initializers.add(AuthSession.restore);
    FirebasePlatform.instance = LinuxFirebase();
    FirebaseAuthPlatform.instance = LinuxFirebaseAuth();
    FirebaseFirestorePlatform.instance = LinuxFirebaseFirestore();
    FieldValueFactoryPlatform.instance = LinuxFieldValueFactory();
    FirebaseStoragePlatform.instance = LinuxFirebaseStorage(bucket: '');
  }
}
