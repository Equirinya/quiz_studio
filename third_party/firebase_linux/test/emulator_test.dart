// End-to-end tests against the Firebase emulators, through the same
// app-facing APIs the app uses. Start the emulators first:
//
//   firebase emulators:start --only auth,firestore,storage --project demo-linux
//
// then: FIREBASE_EMULATORS=1 flutter test test/emulator_test.dart
// (Rules: any signed-in user may read and write, except /private.)
@TestOn('linux')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_linux/firebase_linux.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _options = FirebaseOptions(
  apiKey: 'fake-api-key',
  appId: '1:1:web:1',
  messagingSenderId: '1',
  projectId: 'demo-linux',
  storageBucket: 'demo-linux.appspot.com',
);

/// Waits for the first event on [stream] that passes [test].
Future<T> firstWhere<T>(Stream<T> stream, bool Function(T) test) =>
    stream.firstWhere(test).timeout(const Duration(seconds: 10));

void main() {
  final enabled = Platform.environment['FIREBASE_EMULATORS'] != null;
  late Directory authDir;

  setUpAll(() async {
    if (!enabled) return;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    authDir = await Directory.systemTemp.createTemp('firebase_linux_test');
    AuthSession.storageDirectory = authDir;
    FirebaseLinux.registerWith();
    await Firebase.initializeApp(options: _options);
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
  });

  tearDownAll(() async {
    if (!enabled) return;
    debugDefaultTargetPlatformOverride = null;
  });

  final skip = enabled ? false : 'Set FIREBASE_EMULATORS=1 with the emulators running.';

  group('auth', skip: skip, () {
    test('anonymous, link email, sign out, sign in, reauthenticate', () async {
      final auth = FirebaseAuth.instance;
      await auth.signOut();
      final states = <String?>[];
      final sub = auth.authStateChanges().listen((u) => states.add(u?.uid));

      final anon = await auth.signInAnonymously();
      expect(anon.user!.isAnonymous, isTrue);
      expect(auth.currentUser!.uid, anon.user!.uid);
      final uid = anon.user!.uid;

      final email = 'u${DateTime.now().microsecondsSinceEpoch}@example.com';
      await auth.currentUser!.linkWithCredential(EmailAuthProvider.credential(email: email, password: 'secret123'));
      expect(auth.currentUser!.uid, uid);
      expect(auth.currentUser!.isAnonymous, isFalse);
      expect(auth.currentUser!.email, email);

      await expectLater(
        auth.currentUser!.linkWithCredential(EmailAuthProvider.credential(email: email, password: 'secret123')),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'provider-already-linked')),
      );

      await auth.signOut();
      expect(auth.currentUser, isNull);

      await expectLater(
        auth.signInWithEmailAndPassword(email: email, password: 'wrong-one'),
        throwsA(isA<FirebaseAuthException>().having(
          (e) => e.code,
          'code',
          anyOf('wrong-password', 'invalid-credential'),
        )),
      );

      final signedIn = await auth.signInWithEmailAndPassword(email: email, password: 'secret123');
      expect(signedIn.user!.uid, uid);
      await auth.currentUser!.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: 'secret123'));
      expect(await auth.currentUser!.getIdToken(), isNotEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      // Initial (null), anonymous user, signed out, signed in again.
      expect(states, [null, uid, null, uid]);
    });

    test('the sign-in is kept on disk', () async {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) await auth.signInAnonymously();
      final uid = auth.currentUser!.uid;
      // Give the save a moment, then load it as a new run of the app would.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final files = authDir.listSync(recursive: true).whereType<File>().toList();
      expect(files, hasLength(1));
      expect(files.single.readAsStringSync(), contains(uid));
      expect((await files.single.stat()).modeString(), 'rw-------');
    });

    test('errors use the FlutterFire codes', () async {
      final auth = FirebaseAuth.instance;
      await expectLater(
        auth.signInWithEmailAndPassword(email: 'nobody@example.com', password: 'whatever1'),
        throwsA(isA<FirebaseAuthException>().having(
          (e) => e.code,
          'code',
          anyOf('user-not-found', 'invalid-credential'),
        )),
      );
      await expectLater(
        auth.signInWithEmailAndPassword(email: 'not an email', password: 'whatever1'),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'invalid-email')),
      );
    });
  });

  group('firestore', skip: skip, () {
    setUp(() async {
      if (FirebaseAuth.instance.currentUser == null) await FirebaseAuth.instance.signInAnonymously();
    });

    test('set, get, update with transforms, delete', () async {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('games').doc();
      final other = db.collection('games').doc('other');
      await ref.set({
        'name': 'Quiz',
        'count': 1,
        'ratio': 0.5,
        'tags': ['a', 'b'],
        'nested': {'x': 1, 'y': {'z': true}},
        'createdAt': FieldValue.serverTimestamp(),
        'image': Blob(Uint8List.fromList([1, 2, 3])),
        'link': other,
        'nothing': null,
        'when': Timestamp(1700000000, 5000),
        'place': const GeoPoint(52.5, 13.4),
      });
      var doc = await ref.get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['name'], 'Quiz');
      expect(data['count'], 1);
      expect(data['ratio'], 0.5);
      expect(data['tags'], ['a', 'b']);
      expect(data['nested'], {'x': 1, 'y': {'z': true}});
      expect(data['createdAt'], isA<Timestamp>());
      expect((data['image'] as Blob).bytes, [1, 2, 3]);
      expect((data['link'] as DocumentReference).path, 'games/other');
      expect(data.containsKey('nothing'), isTrue);
      expect(data['when'], Timestamp(1700000000, 5000));
      expect(data['place'], const GeoPoint(52.5, 13.4));

      await ref.update({
        'tags': FieldValue.arrayUnion(['c', 'a']),
        'nested.y.z': false,
        'nested.w': 'new',
        'count': FieldValue.increment(2),
        'nothing': FieldValue.delete(),
      });
      doc = await ref.get();
      expect(doc['tags'], ['a', 'b', 'c']);
      expect(doc['nested'], {'x': 1, 'y': {'z': false}, 'w': 'new'});
      expect(doc['count'], 3);
      expect(doc.data()!.containsKey('nothing'), isFalse);

      await ref.update({'tags': FieldValue.arrayRemove(['a'])});
      expect((await ref.get())['tags'], ['b', 'c']);

      await ref.set({'extra': 1}, SetOptions(merge: true));
      doc = await ref.get();
      expect(doc['extra'], 1);
      expect(doc['name'], 'Quiz');

      await ref.set({'only': 1});
      expect((await ref.get()).data(), {'only': 1});

      await ref.delete();
      expect((await ref.get()).exists, isFalse);

      await expectLater(
        db.collection('games').doc('missing').update({'a': 1}),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'not-found')),
      );
    });

    test('queries: where, arrayContains, orderBy, limit, cursors', () async {
      final db = FirebaseFirestore.instance;
      final col = db.collection('q_${DateTime.now().microsecondsSinceEpoch}');
      final batch = db.batch();
      for (var i = 0; i < 5; i++) {
        batch.set(col.doc('d$i'), {
          'i': i,
          'even': i.isEven,
          'admin': i < 3 ? ['me'] : ['you'],
          'createdAt': Timestamp(1000 + (5 - i), 0),
        });
      }
      await batch.commit();

      final mine = await col.where('admin', arrayContains: 'me').orderBy('createdAt').get();
      expect(mine.docs.map((d) => d.id), ['d2', 'd1', 'd0']);

      final evens = await col.where('even', isEqualTo: true).get();
      expect(evens.docs.map((d) => d.id), ['d0', 'd2', 'd4']);

      final big = await col.where('i', isGreaterThanOrEqualTo: 3).get();
      expect(big.docs.map((d) => d['i']), [3, 4]);

      final top = await col.orderBy('i', descending: true).limit(2).get();
      expect(top.docs.map((d) => d['i']), [4, 3]);

      final last = await col.orderBy('i').limitToLast(2).get();
      expect(last.docs.map((d) => d['i']), [3, 4]);

      final after = await col.orderBy('i').startAfter([1]).endAt([3]).get();
      expect(after.docs.map((d) => d['i']), [2, 3]);

      final byId = await col.where(FieldPath.documentId, whereIn: ['d1', 'd3']).get();
      expect(byId.docs.map((d) => d.id), ['d1', 'd3']);

      final either = await col.where(Filter.or(Filter('i', isEqualTo: 0), Filter('i', isEqualTo: 4))).get();
      expect(either.docs.map((d) => d.id), ['d0', 'd4']);

      final all = await col.get();
      expect(all.size, 5);
    });

    test('document listener sees changes and deletion', () async {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('sessions').doc();
      final events = StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
      final sub = ref.snapshots().listen(events.add);

      final missing = await firstWhere(events.stream, (_) => true);
      expect(missing.exists, isFalse);

      final created = firstWhere(events.stream, (s) => s.exists);
      await ref.set({'state': 1, 'updatedAt': FieldValue.serverTimestamp()});
      expect((await created)['state'], 1);
      expect((await created)['updatedAt'], isA<Timestamp>());

      final updated = firstWhere(events.stream, (s) => s.exists && s['state'] == 2);
      await ref.update({'state': 2});
      expect((await updated).metadata.hasPendingWrites, isFalse);

      final deleted = firstWhere(events.stream, (s) => !s.exists);
      await ref.delete();
      await deleted;
      await sub.cancel();
    });

    test('query listener reports docChanges in order, as the command inbox uses them', () async {
      final db = FirebaseFirestore.instance;
      final commands = db.collection('sessions').doc().collection('commands');
      await commands.add({'command': 'early', 'createdAt': FieldValue.serverTimestamp()});

      final snapshots = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      final sub = commands.orderBy('createdAt').snapshots().listen(snapshots.add);

      final first = await firstWhere(snapshots.stream, (_) => true);
      expect(first.docs.map((d) => d['command']), ['early']);
      expect(first.docChanges.map((c) => c.type), [DocumentChangeType.added]);

      // The host deletes what it has applied, then a new command comes in.
      final emptied = firstWhere(snapshots.stream, (s) => s.docs.isEmpty);
      await first.docs.single.reference.delete();
      final empty = await emptied;
      expect(empty.docChanges.single.type, DocumentChangeType.removed);

      final next = firstWhere(snapshots.stream, (s) => s.docs.length == 2);
      await commands.add({'command': 'buzz 1', 'createdAt': Timestamp(2000, 0)});
      await commands.add({'command': 'buzz 0', 'createdAt': Timestamp(1000, 0)});
      final two = await next;
      expect(two.docs.map((d) => d['command']), ['buzz 0', 'buzz 1']);

      final modified = firstWhere(snapshots.stream, (s) => s.docChanges.any((c) => c.type == DocumentChangeType.modified));
      await two.docs.first.reference.update({'seen': true});
      final change = (await modified).docChanges.single;
      expect(change.doc['command'], 'buzz 0');
      await sub.cancel();
    });

    test('query listener with arrayContains and orderBy follows membership', () async {
      final db = FirebaseFirestore.instance;
      final col = db.collection('m_${DateTime.now().microsecondsSinceEpoch}');
      final stream = col.where('full', arrayContains: 'me').orderBy('createdAt').snapshots();
      final snapshots = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      final sub = stream.listen(snapshots.add);
      expect((await firstWhere(snapshots.stream, (_) => true)).docs, isEmpty);

      final joined = firstWhere(snapshots.stream, (s) => s.docs.length == 1);
      await col.doc('g').set({'full': ['me'], 'createdAt': FieldValue.serverTimestamp()});
      await joined;

      final left = firstWhere(snapshots.stream, (s) => s.docs.isEmpty);
      await col.doc('g').update({'full': FieldValue.arrayRemove(['me'])});
      expect((await left).docChanges.single.type, DocumentChangeType.removed);
      await sub.cancel();
    });

    test('many listeners at once share one connection', () async {
      final db = FirebaseFirestore.instance;
      final refs = [for (var i = 0; i < 20; i++) db.collection('many').doc('d$i')];
      final subs = <StreamSubscription<Object?>>[];
      final seen = <Future<void>>[];
      for (final (i, ref) in refs.indexed) {
        final done = Completer<void>();
        seen.add(done.future);
        subs.add(ref.snapshots().listen((s) {
          if (s.exists && s['v'] == i && !done.isCompleted) done.complete();
        }));
      }
      final batch = db.batch();
      for (final (i, ref) in refs.indexed) {
        batch.set(ref, {'v': i});
      }
      await batch.commit();
      await Future.wait(seen).timeout(const Duration(seconds: 10));
      for (final sub in subs) {
        await sub.cancel();
      }
    });

    test('permission errors reach reads, writes and listeners', () async {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('private').doc('x');
      await expectLater(ref.get(), throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')));
      await expectLater(
        ref.set({'a': 1}),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );
      final error = Completer<Object>();
      ref.snapshots().listen((_) {}, onError: error.complete);
      expect(
        await error.future.timeout(const Duration(seconds: 10)),
        isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied'),
      );
    });

    test('listeners carry on after someone else signs in', () async {
      final auth = FirebaseAuth.instance;
      final db = FirebaseFirestore.instance;
      final ref = db.collection('switch').doc();
      await ref.set({'v': 1});
      final snapshots = StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
      final sub = ref.snapshots().listen(snapshots.add);
      await firstWhere(snapshots.stream, (s) => s.exists);

      await auth.signOut();
      await auth.signInAnonymously();
      final changed = firstWhere(snapshots.stream, (s) => s.exists && s['v'] == 2);
      await ref.update({'v': 2});
      await changed;
      await sub.cancel();
    });

    test('transactions', () async {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('tx').doc();
      await ref.set({'n': 1});
      final result = await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        tx.update(ref, {'n': (snap['n'] as int) + 1});
        return 'done';
      });
      expect(result, 'done');
      expect((await ref.get())['n'], 2);
    });
  });

  group('storage', skip: skip, () {
    setUp(() async {
      if (FirebaseAuth.instance.currentUser == null) await FirebaseAuth.instance.signInAnonymously();
    });

    test('putFile, writeToFile, getDownloadURL, delete', () async {
      final dir = await Directory.systemTemp.createTemp('storage_test');
      final source = File('${dir.path}/sound.wav')..writeAsBytesSync(List.generate(300000, (i) => i % 251));
      final ref = FirebaseStorage.instance.ref('game_test/sound ${DateTime.now().millisecondsSinceEpoch}.wav');

      final snapshot = await ref.putFile(source, SettableMetadata(contentType: 'audio/wav'));
      expect(snapshot.state, TaskState.success);
      expect(snapshot.metadata?.contentType, 'audio/wav');
      expect(snapshot.metadata?.size, 300000);

      final target = File('${dir.path}/copy/sound.wav.part');
      await ref.writeToFile(target);
      expect(target.readAsBytesSync(), source.readAsBytesSync());

      final url = await ref.getDownloadURL();
      expect(url, contains('alt=media'));
      expect(url, contains('token='));

      expect((await ref.getMetadata()).contentType, 'audio/wav');
      expect((await ref.parent!.listAll()).items.map((r) => r.fullPath), contains(ref.fullPath));

      await ref.delete();
      await expectLater(
        ref.writeToFile(File('${dir.path}/gone')),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'object-not-found')),
      );
    });
  });

  group('account deletion', skip: skip, () {
    test('delete() signs out', () async {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) await auth.signInAnonymously();
      await auth.currentUser!.delete();
      expect(auth.currentUser, isNull);
    });
  });
}
