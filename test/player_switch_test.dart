import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';
import 'game/rapid_fixture.dart';
import 'game/connections_fixture.dart';
import 'game/top_answers_fixture.dart';

void main() {
  for (final (name, game) in [
    ('fixture', fixtureGame()),
    ('rapid', rapidGame()),
    ('matching', matchingGame()),
    ('connections', connectionsGame()),
    ('top', topAnswersGame(mode: TopAnswersMode.typed)),
  ]) {
    testWidgets('switching questions: $name', (tester) async {
      final host = SessionHost(initial: fixtureState(), game: game);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamBuilder<SessionState>(
              stream: host.states,
              builder: (context, _) => PlayerView(
                view: PublicView(host.publicState),
                teamId: 'red',
                send: (c) => host.dispatch(c, sender: const Sender(Role.player, teamId: 'red')),
              ),
            ),
          ),
        ),
      );
      final refs = [
        for (final g in game.groups)
          for (final c in g.categories)
            for (final q in c.questions) QuestionRef(c.id, q.id),
      ];
      for (final a in refs) {
        for (final b in refs) {
          host.dispatch(OpenQuestion(a));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          host.dispatch(const RevealAnswers());
          await tester.pump();
          host.dispatch(const CloseQuestion());
          host.dispatch(OpenQuestion(b));
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 30));
            final e = tester.takeException();
            if (e != null) fail('$a -> $b: $e');
          }
          host.dispatch(const CloseQuestion());
          await tester.pump();
        }
      }
      host.dispose();
    });
  }
}
