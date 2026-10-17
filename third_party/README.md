# Patched FlutterFire plugins

`cloud_firestore` 6.10.0, `firebase_auth` 6.7.0 and `firebase_storage` 13.6.0,
copied from pub.dev (without `example/` and `test/`) and used through
`dependency_overrides` in `pubspec.yaml`. Only their `windows/` code is changed.
Every change is marked `Quiz Studio patch`.

## Why

The Firebase C++ SDK finishes futures and fires listeners on its own worker
threads. On Windows these plugins answered Flutter straight from there, but the
engine requires platform channel messages on the platform thread. Breaking that
rule can end the app without any error, which is what the app did during shows.
Upstream: flutterfire#11933, #17073, #18630; they are waiting for a Flutter API
to post work to the platform thread (flutter#187365) before fixing it.

- **cloud_firestore:** 6.8.0 moved query and listener results to the platform
  thread, but document get/set/update/delete, batch commits, aggregate and named
  queries, and clearPersistence/enable/disableNetwork/terminate/
  waitForPendingWrites still replied from the worker thread. They now go through
  the plugin's own `PlatformThreadDispatcher` (`OnPlatformThread`).
- **firebase_auth:** every future reply, and the auth-state and id-token events
  (which also fire on token refresh, about hourly), now go through the
  dispatcher in `windows/platform_thread.h`. The listener's sink is locked, so
  cancelling while an event is in flight is safe.
- **firebase_storage:** same for replies and task events. The stream handlers
  also held their event sink as `std::unique_ptr<...>&& events_ = nullptr`, a
  reference to a temporary that dangles; replaced by a shared sink.

## Updating

When bumping one of these packages, copy the new version from the pub cache
(`%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\<package>-<version>`), delete
`example/` and `test/`, and redo the patch: wrap every `result` captured by an
`OnCompletion` lambda with `OnPlatformThread(result)`, and send every
`EventSink::Success` through the dispatcher. Drop the override entirely once
upstream answers on the platform thread everywhere.
