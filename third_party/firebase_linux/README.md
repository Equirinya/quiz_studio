# firebase_linux

FlutterFire has no Linux plugins. This package fills in `firebase_core`,
`firebase_auth`, `cloud_firestore` and `firebase_storage` on Linux, in Dart
only, so the app code stays the same on every platform. Flutter registers it
through `dartPluginClass` (`FirebaseLinux.registerWith`) before `main`; on
other platforms it does nothing.

It talks to the same backends the web SDK uses, with the options in
`DefaultFirebaseOptions.linux` (the web app's, as on Windows):

| Plugin | How |
| --- | --- |
| firebase_core | Plain Dart app objects. `initializeApp` also loads the saved sign-in, so `currentUser` is set from the first frame. |
| firebase_auth | Identity Toolkit and Secure Token REST APIs. The refresh token is kept in the app support directory (`firebase_auth/<project>_<app>.json`, mode 600); ID tokens are refreshed when they are within 5 minutes of expiring. |
| cloud_firestore | Firestore's gRPC API (`lib/src/proto`, generated from googleapis). All `snapshots()` listeners share one Listen stream, which reconnects with backoff and resumes each target. |
| firebase_storage | Firebase Storage REST API (`firebasestorage.googleapis.com/v0`). |

## What works

- Auth: anonymous, email and password (sign in, create, link, re-authenticate),
  sign out, delete, reload, ID tokens, password reset and verification emails,
  `updatePassword`, `updateProfile`, `verifyBeforeUpdateEmail`; auth state, ID
  token and user streams. Error codes match the other platforms
  (`wrong-password`, `invalid-credential`, `email-already-in-use`,
  `requires-recent-login`, `network-request-failed`, ...).
- Firestore: get/set (with merge and mergeFields)/update/delete, `add`,
  batches, transactions, queries with `where` (all operators, `Filter.or/and`,
  `FieldPath.documentId`), `orderBy`, `limit`, `limitToLast` and cursors,
  `snapshots()` on documents and queries with `docChanges`. Field values:
  `serverTimestamp`, `arrayUnion`, `arrayRemove`, `increment`, `delete`.
  Types: Timestamp, Blob, GeoPoint, DocumentReference, VectorValue.
- Storage: `putFile`/`putData`/`putString`, `writeToFile`, `getData`,
  `getDownloadURL`, `getMetadata`, `updateMetadata`, `list`/`listAll`, `delete`.
- Emulators: `useAuthEmulator`, `useFirestoreEmulator`, `useStorageEmulator`.
- `https_proxy` / `no_proxy` are honoured.

## What is different from the native SDKs

- **No local cache.** Reads always go to the server, and writes fail while
  offline instead of waiting in a queue (a few brief retries on `unavailable`).
  `persistenceEnabled`, `clearPersistence`, `enable/disableNetwork` and
  `waitForPendingWrites` do nothing.
- **No latency compensation.** A listener sees a local write once the server
  has it (usually well under a second), never as a pending write:
  `metadata.hasPendingWrites` and `isFromCache` are always false.
- Not supported (throw `UnimplementedError` or `operation-not-allowed`):
  phone, OAuth provider and email-link sign-in, multi-factor, aggregate
  queries (`count()`), named queries and bundles, pipelines, pausing uploads.

## Tests

`test/emulator_test.dart` runs the plugins through the app-facing packages
against the Firebase emulators:

```sh
firebase emulators:start --only auth,firestore,storage --project demo-linux
# with rules that let any signed-in user read and write, except /private
FIREBASE_EMULATORS=1 flutter test test/emulator_test.dart
```

## Regenerating the Firestore protos

```sh
git clone --depth 1 https://github.com/googleapis/googleapis
dart pub global activate protoc_plugin
cd googleapis && protoc -I . --dart_out=grpc:out \
  google/firestore/v1/*.proto google/rpc/status.proto google/type/latlng.proto
```

Copy `out/google/{firestore,rpc,type}` to `lib/src/proto/google/` and delete
the `*.pbjson.dart` files.
