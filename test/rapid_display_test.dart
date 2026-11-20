import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/pages/rapid_fire_display.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/app_localizations.dart';

import 'game/fixture.dart';
import 'game/rapid_fixture.dart';

void main() {
  testWidgets('a small picture is blown up to fill the item box', (tester) async {
    // A picture of 1 by 1 pixel.
    final dir = Directory.systemTemp.createTempSync('rapid');
    addTearDown(() => dir.deleteSync(recursive: true));
    final picture = File('${dir.path}/cat.png')
      ..writeAsBytesSync(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=='));
    final game = rapidGame();
    final state = run(fixtureState(), const [OpenQuestion(boardRound), Reveal(1)], game, 1000);
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: RapidFireDisplay(
            state: state,
            question: game.question(boardRound)!,
            unit: 10,
            file: (name) => name == 'cat.png' ? picture : null,
          ),
        ),
      ));
      await precacheImage(FileImage(picture), tester.element(find.byType(RapidFireDisplay)));
    });
    await tester.pump();
    // As drawn, after scaling.
    final size = tester.getRect(find.byType(ClipRRect).first).size;
    expect(size.height, greaterThan(300));
    expect(find.text('A cat'), findsOneWidget);
  });

  testWidgets('an item without text shows the question itself, once', (tester) async {
    final game = rapidGame();
    final state = run(fixtureState(), const [OpenQuestion(boardRound), Reveal(1), Reveal(1), Reveal(1)], game, 1000);
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: RapidFireDisplay(state: state, question: game.question(boardRound)!, unit: 10, file: (_) => null),
      ),
    ));
    expect(find.text('Draw it'), findsOneWidget);
  });

  testWidgets('an item with only a picture shows no text beside it: the picture gets the whole card', (tester) async {
    final dir = Directory.systemTemp.createTempSync('rapid');
    addTearDown(() => dir.deleteSync(recursive: true));
    final picture = File('${dir.path}/dog.png')
      ..writeAsBytesSync(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=='));
    final game = rapidGame();
    final state = run(fixtureState(), const [OpenQuestion(boardRound), Reveal(1), Reveal(1), Reveal(1)], game, 1000);
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: RapidFireDisplay(
            state: state,
            question: game.question(boardRound)!,
            unit: 10,
            file: (name) => name == 'dog.png' ? picture : null,
          ),
        ),
      ));
      await precacheImage(FileImage(picture), tester.element(find.byType(RapidFireDisplay)));
    });
    await tester.pump();
    // The question small above, once; nothing beside the picture.
    final heading = find.text('Draw it');
    expect(heading, findsOneWidget);
    final drawn = tester.getRect(find.byType(ClipRRect).first);
    expect(drawn.top, greaterThan(tester.getRect(heading).bottom));
    expect(drawn.height, greaterThan(500), reason: 'as big as the card lets it be');
  });

  testWidgets('on the devices, once next has locked the teams, right or wrong is up big', (tester) async {
    final game = rapidGame();
    final question = game.question(devicesRound)!;
    Future<void> show(SessionState state) => tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: RapidFireDisplay(state: state, question: question, unit: 10, file: (_) => null)),
        ));
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final asking = run(fixtureState(), const [OpenQuestion(devicesRound), Reveal(1)], game, 1000);
    await show(asking);
    expect(find.byKey(const ValueKey('verdict-0')), findsNothing);
    await show(run(asking, const [Reveal(1)], game, 2000));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('verdict-0')), findsOneWidget);
    expect(find.byIcon(question.rapidFire!.items.first.isTrue ? Icons.check : Icons.close), findsOneWidget);
    // Text stored as its answer (the editor has no field for it here) stays off screen.
    expect(find.textContaining('yellow dwarf'), findsNothing);
  });
}
