import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

void main() {
  for (final answering in [false, true]) {
    testWidgets('progressing reveal: the big screen shows the hints${answering ? ', also while teams answer on their devices' : ''}', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final host = SessionHost(initial: fixtureState());
      final connection = SessionConnection.local(host, game: fixtureGame());
      addTearDown(connection.dispose);
      host.dispatch(const OpenQuestion(reveal));
      if (answering) host.dispatch(const OpenAnswers(CompanionSpec(kind: CompanionKind.text)));
      host.dispatch(const Reveal(1));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: PresenterView(connection: connection))));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('hint 1'), findsOneWidget);
      expect(find.text('hint 2'), findsNothing);
      if (answering) expect(find.text('Red'), findsWidgets, reason: 'the teams below');
    });
  }
}
