import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/companion/connections.dart';
import 'package:quiz_show/features/player/pages/player_page.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/connections_fixture.dart';

void main() {
  const teams = [Team(id: 'red', name: 'Red'), Team(id: 'blue', name: 'Blue')];
  late SessionHost host;
  final sent = <Command>[];

  setUp(() {
    sent.clear();
    host = SessionHost(initial: const SessionState(gameId: 'cg', teams: teams), game: connectionsGame());
  });
  tearDown(() => host.dispose());

  /// The red team's tablet, fed with red's own view.
  Future<void> pumpTablet(WidgetTester tester, {String? appVersion}) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StreamBuilder<SessionState>(
          stream: host.states,
          builder: (context, _) => PlayerView(
            view: PublicView(host.publicStateFor('red')),
            teamId: 'red',
            appVersion: appVersion,
            send: (command) {
              sent.add(command);
              host.dispatch(command, sender: const Sender(Role.player, teamId: 'red'));
            },
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
  }

  String wordAt(int place) => PublicView(host.publicStateFor('red')).connectionWords[place];

  Future<void> pick(WidgetTester tester, List<int> places) async {
    for (final place in places) {
      await tester.tap(find.text(wordAt(place).toUpperCase()));
      await tester.pump();
    }
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await settle(tester);
  }

  testWidgets('pick four, submit, and a found group turns into its bar', (tester) async {
    host.dispatch(const OpenQuestion(puzzle));
    await pumpTablet(tester);
    expect(find.text('Find four groups of four'), findsOneWidget);
    expect(find.byType(ConnectionsGrid), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit')).onPressed, isNull);

    await pick(tester, placesOf(1));
    // A fifth word cannot be added.
    await tester.tap(find.text(wordAt(placesOf(0).first).toUpperCase()));
    await tester.pump();
    await submit(tester);
    expect(sent.whereType<GuessConnection>().single.positions..sort(), [...placesOf(1)]..sort());
    expect(find.text('PLANETS'), findsOneWidget);
    expect(find.textContaining('MARS, VENUS'), findsOneWidget);
    expect(find.text('Perfect!'), findsNothing, reason: 'the message has gone again');
  });

  testWidgets('the device answers a guess at once, without waiting for the presenter', (tester) async {
    host.dispatch(const OpenQuestion(puzzle));
    final view = PublicView(host.publicStateFor('red'));
    final guesses = <Command>[];
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // A presenter that never answers.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PlayerView(view: view, teamId: 'red', send: guesses.add)),
    ));
    await pick(tester, placesOf(3));
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('___ PIE'), findsOneWidget);
    expect(guesses.whereType<GuessConnection>(), hasLength(1));

    await pick(tester, [placesOf(0)[0], placesOf(0)[1], placesOf(0)[2], placesOf(1)[0]]);
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('One away…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a wrong guess: one away, a try less, and the same guess is not sent twice', (tester) async {
    host.dispatch(const OpenQuestion(puzzle));
    await pumpTablet(tester);
    final guess = [...placesOf(0).take(3), placesOf(2).first];
    await pick(tester, guess);
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('One away…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(host.state.answerRound!.answers['red']!.connections!.mistakes, 1);

    // The selection stays; sending it again is caught on the device.
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Already guessed'), findsOneWidget);
    expect(sent.whereType<GuessConnection>(), hasLength(1));
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Deselect all'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit')).onPressed, isNull);
  });

  testWidgets('out of tries, the board stops; the reveal shows the rest', (tester) async {
    host.dispatch(const OpenQuestion(puzzle));
    await pumpTablet(tester);
    for (var i = 0; i < 3; i++) {
      await pick(tester, [placesOf(0)[i], placesOf(1)[i], placesOf(2)[i], placesOf(3)[i]]);
      await submit(tester);
      await tester.tap(find.text('Deselect all'));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('No tries left. Wait for the solution'), findsOneWidget);
    expect(find.text("We're done"), findsNothing);
    host.dispatch(const Reveal(4));
    await settle(tester);
    for (final name in ['FRUIT', 'PLANETS', 'CARD GAMES', '___ PIE']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets("a team can stop early, and the time it took is kept", (tester) async {
    host.dispatch(const OpenQuestion(puzzle));
    await pumpTablet(tester);
    await tester.tap(find.text("We're done"));
    await settle(tester);
    expect(host.state.answerRound!.answers['red']!.locked, isTrue);
    expect(host.state.answerRound!.answers['red']!.lockedAtMillis, isNotNull);
    expect(find.text('Locked in with 0 of 4'), findsOneWidget);
  });

  testWidgets('an app older than the session needs asks to be updated', (tester) async {
    host.dispatch(const OpenQuestion(puzzle));
    await pumpTablet(tester, appVersion: '1.9.0');
    expect(find.byType(ConnectionsGrid), findsNothing);
    expect(find.textContaining('update', findRichText: true), findsWidgets);
    await pumpTablet(tester, appVersion: kMinCompanionVersion);
    expect(find.byType(ConnectionsGrid), findsOneWidget);
  });

  testWidgets('a screen this app does not know asks for an update instead of showing a buzzer', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayerView(
          view: PublicView({
            ...host.publicState,
            'answerRound': {
              'spec': {'kind': 'hologram'},
              'open': true,
            },
          }),
          teamId: 'red',
          send: (_) {},
        ),
      ),
    ));
    expect(find.textContaining('newer version'), findsOneWidget);
  });

  group('gamemaster', () {
    late SessionConnection connection;

    Future<void> pumpBoth(WidgetTester tester) async {
      tester.view.physicalSize = const Size(2000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      connection = SessionConnection.local(host, game: host.game);
      addTearDown(connection.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(width: 460, child: ControllerView(connection: connection)),
              Expanded(child: PresenterView(connection: connection)),
            ],
          ),
        ),
      ));
      await tester.pump();
    }

    Finder pad(String label) => find.descendant(of: find.byType(ControllerView), matching: find.widgetWithText(FilledButton, label));

    testWidgets('revealing while teams play asks first; afterwards it does not', (tester) async {
      host.dispatch(const OpenQuestion(puzzle));
      await pumpBoth(tester);
      await tester.tap(pad('Reveal group'));
      await settle(tester);
      expect(find.text('Reveal a group now?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(host.state.revealed, 0);

      await tester.tap(pad('Reveal group'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Reveal').last);
      await settle(tester);
      expect(host.state.revealed, 1);
      expect(host.state.answerRound!.open, isTrue, reason: 'the teams play on');
      expect(find.descendant(of: find.byType(PresenterView), matching: find.text('FRUIT')), findsOneWidget);

      await tester.tap(pad('Reveal group'));
      await settle(tester);
      expect(find.text('Reveal a group now?'), findsOneWidget, reason: 'still playing, so it asks again');
      await tester.tap(find.widgetWithText(FilledButton, 'Reveal').last);
      await settle(tester);
      expect(host.state.revealed, 2);

      host.dispatch(const LockAnswers());
      await settle(tester);
      await tester.tap(pad('Reveal group'));
      await settle(tester);
      expect(find.text('Reveal a group now?'), findsNothing, reason: 'time is up, nothing to give away');
      expect(host.state.revealed, 3);
    });

    testWidgets('the gamemaster sees each team\'s colours and mistakes, and gives the points', (tester) async {
      host.dispatch(const OpenQuestion(puzzle));
      host.dispatch(GuessConnection('red', placesOf(2)), sender: const Sender(Role.player, teamId: 'red'));
      host.dispatch(GuessConnection('red', placesOf(0)), sender: const Sender(Role.player, teamId: 'red'));
      host.dispatch(
        GuessConnection('blue', [placesOf(0)[0], placesOf(1)[0], placesOf(2)[0], placesOf(3)[0]]),
        sender: const Sender(Role.player, teamId: 'blue'),
      );
      await pumpBoth(tester);
      final rows = tester.widgetList<ConnectionsProgressRow>(
        find.descendant(of: find.byType(ControllerView), matching: find.byType(ConnectionsProgressRow)),
      );
      expect([for (final row in rows) (row.solved.join(','), row.mistakes)], [('2,0', 0), ('', 1)]);
      expect(find.textContaining('2 of 4 found'), findsOneWidget);
      // The presenter shows the same, for the audience.
      expect(find.descendant(of: find.byType(PresenterView), matching: find.byType(ConnectionsProgressRow)), findsNWidgets(2));

      await tester.tap(find.textContaining('Give points: Red 200, Blue 0'));
      await settle(tester);
      expect(host.state.team('red')!.points, 200);
      expect(host.state.team('blue')!.points, 0);
    });
  });
}
