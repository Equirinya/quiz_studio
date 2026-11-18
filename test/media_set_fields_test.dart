import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/features/games/widgets/media_set_fields.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/app_localizations.dart';

/// Pictures being uploaded already have their row.
void main() {
  tearDown(() => MediaService.debugUpload = null);

  testWidgets('an uploading picture has its row, with "add another" below and the display choice from two', (tester) async {
    final done = <String, Completer<String>>{};
    MediaService.debugUpload = (path, _) => (done[path] = Completer<String>()).future;
    final changes = <MediaSet>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: MediaSetFields(gameId: 'g', media: MediaSet.empty, onChanged: changes.add),
        ),
      ),
    ));
    expect(find.text('Side by side'), findsNothing);

    final add = tester.widget<MediaButton>(find.byWidgetPredicate((w) => w is MediaButton && w.onPicked != null));
    add.onPicked!(['/tmp/a.png']);
    await tester.pump();
    expect(find.text('Picture'), findsOneWidget);
    expect(find.text('Add another picture'), findsOneWidget);
    expect(find.text('Side by side'), findsNothing);

    // A second one while the first is still on its way: the choice shows.
    add.onPicked!(['/tmp/b.png']);
    await tester.pump();
    expect(find.text('Picture 1'), findsOneWidget);
    expect(find.text('Picture 2'), findsOneWidget);
    expect(find.text('waiting'), findsOneWidget);
    expect(find.text('Side by side'), findsOneWidget);

    done['/tmp/a.png']!.complete('a.png');
    await tester.pump();
    await tester.pump();
    expect(changes.last.images, ['a.png']);
    done['/tmp/b.png']!.complete('b.png');
    await tester.pump();
    await tester.pump();
    expect(changes.last.images, ['a.png', 'b.png']);
  });

  testWidgets('files dropped on an item\'s media button go in: pictures added, the sound replaced', (tester) async {
    MediaService.debugUpload = (path, _) async => path.split('/').last;
    final changes = <MediaSet>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: MediaSetButton(gameId: 'g', media: const MediaSet(images: ['old.png']), onChanged: changes.add),
        ),
      ),
    ));
    final target = tester.widget<DropTarget>(find.byType(DropTarget));
    target.onDragDone!(DropDoneDetails(
      files: [DropItemFile('/tmp/a.png'), DropItemFile('/tmp/song.mp3'), DropItemFile('/tmp/notes.txt')],
      localPosition: Offset.zero,
      globalPosition: Offset.zero,
    ));
    await tester.pumpAndSettle();
    expect(changes.last.images, ['old.png', 'a.png']);
    expect(changes.last.music, 'song.mp3');
  });
}
