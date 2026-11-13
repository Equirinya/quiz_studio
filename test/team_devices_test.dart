import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

import 'game/fixture.dart';

void main() {
  /// Two phones of team Red, side by side, on one host.
  Future<SessionHost> twoPhones(WidgetTester tester, CompanionSpec spec) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = SessionHost(initial: fixtureState(), game: fixtureGame());
    addTearDown(host.dispose);
    host
      ..dispatch(const OpenQuestion(free))
      ..dispatch(OpenAnswers(spec));
    Widget phone(String key) => Expanded(
      child: StreamBuilder<SessionState>(
        stream: host.states,
        builder: (context, _) => PlayerView(
          key: ValueKey(key),
          view: PublicView(host.publicStateFor('red')),
          teamId: 'red',
          send: (command) => host.dispatch(command, sender: const Sender(Role.player, teamId: 'red')),
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Row(children: [phone('a'), phone('b')])),
    ));
    await tester.pump();
    return host;
  }

  testWidgets('what one phone of a team types shows on its other phone', (tester) async {
    await twoPhones(tester, const CompanionSpec(kind: CompanionKind.text));
    await tester.enterText(find.byType(TextField).first, 'Bohemian Rhapsody: 1200');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.map((field) => field.controller!.text), ['Bohemian Rhapsody: 1200', 'Bohemian Rhapsody: 1200']);
  });

  testWidgets('an order sorted on one phone of a team is the order on the other', (tester) async {
    final host = await twoPhones(tester, const CompanionSpec(kind: CompanionKind.order, options: ['Mercury', 'Venus', 'Earth', 'Mars']));
    host.dispatch(const SubmitAnswer('red', PlayerAnswer(order: [0, 1, 2, 3])), sender: const Sender(Role.player, teamId: 'red'));
    await tester.pump();
    double top(String planet, int phone) => tester.getTopLeft(find.text(planet).at(phone)).dy;
    for (final phone in [0, 1]) {
      expect(top('Mercury', phone) < top('Venus', phone) && top('Venus', phone) < top('Earth', phone) && top('Earth', phone) < top('Mars', phone), isTrue);
    }
  });
}
