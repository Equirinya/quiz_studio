import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/buzzers/buzzer_link.dart';
import 'package:quiz_show/features/buzzers/buzzers_page.dart';
import 'package:quiz_show/game/game.dart';

import 'fake_buzzer_port.dart';

void main() {
  const teams = [Team(id: 'red', name: 'Red'), Team(id: 'blue', name: 'Blue'), Team(id: 'green', name: 'Green')];
  late FakePort port;
  late BuzzerLink link;
  late Map<int, String> assigned;
  late Map<int, int> thresholds;
  var now = 0;

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    now = 1000;
    port = FakePort();
    link = BuzzerLink(port, clock: () => now);
    assigned = {};
    thresholds = {};
    link.use('COM3');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setState) => BuzzersView(
              link: link,
              teams: teams,
              assignments: assigned,
              onPort: link.use,
              onAssign: (id, teamId) => setState(() {
                assigned = {...assigned}..remove(id);
                if (teamId != null) assigned[id] = teamId;
              }),
              onThreshold: (id, value) {
                thresholds[id] = value;
                link.detector.thresholds[id] = value;
              },
            ),
          ),
        ),
      ),
    ));
  }

  /// A widget test that takes the page down and stops the link's polling
  /// before it ends, as closing the page and the app would.
  void testBuzzers(String description, Future<void> Function(WidgetTester tester) body) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      link.dispose();
    });
  }

  /// The box sends [line]; time moves on far enough for the screen to follow.
  Future<void> send(WidgetTester tester, String line) async {
    port.send('$line\n');
    for (var i = 0; i < 8; i++) {
      now += 10;
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testBuzzers('says what the connection is doing', (tester) async {
    await pumpView(tester);
    await tester.pump();
    expect(find.text('Open, but the box is not sending'), findsOneWidget);
    await send(tester, '0:5,1:5,2:5');
    expect(find.text('Connected'), findsOneWidget);

    port.failReads = true;
    port.plugged = false;
    await send(tester, '');
    expect(find.text('Not connected'), findsOneWidget);
  });

  testBuzzers('every buzzer the box reports gets a dial with its team by position', (tester) async {
    await pumpView(tester);
    await send(tester, '0:5,1:5,2:5,3:5');
    for (final id in [0, 1, 2, 3]) {
      expect(find.byKey(ValueKey('dial-$id')), findsOneWidget);
    }
    expect(find.descendant(of: find.byKey(const ValueKey('dial-0')), matching: find.text('Red')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('dial-2')), matching: find.text('Green')), findsOneWidget);
    // A fourth buzzer with only three teams.
    expect(find.descendant(of: find.byKey(const ValueKey('dial-3')), matching: find.text('No team')), findsOneWidget);
  });

  testBuzzers('pressing shows who was first', (tester) async {
    await pumpView(tester);
    await send(tester, '0:5,1:5,2:5');
    await send(tester, '0:5,1:900,2:5');
    await send(tester, '0:900,1:900,2:5');
    Finder badge(int dial, String text) =>
        find.descendant(of: find.byKey(ValueKey('dial-$dial')), matching: find.widgetWithText(CircleAvatar, text));
    expect(badge(1, '1'), findsOneWidget);
    expect(badge(0, '2'), findsOneWidget);

    await tester.tap(find.text('Clear order'));
    await tester.pump();
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testBuzzers('"assign by pressing": the next buzzer pressed becomes that team\'s', (tester) async {
    await pumpView(tester);
    await send(tester, '0:5,1:5,2:5');
    await tester.tap(find.widgetWithText(TextButton, 'Assign by pressing').last);
    await tester.pump();
    expect(find.text('Press the buzzer of Green now'), findsOneWidget);

    await send(tester, '0:900,1:5,2:5');
    expect(assigned, {0: 'green'});
    expect(find.text('Press the buzzer of Green now'), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('dial-0')), matching: find.text('Green')), findsOneWidget);
    // That press was an assignment, not a test press.
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testBuzzers('"assign all" walks through the teams one press at a time', (tester) async {
    await pumpView(tester);
    await send(tester, '0:5,1:5,2:5');
    await tester.tap(find.text('Assign all by pressing'));
    await tester.pump();
    expect(find.text('Press the buzzer of Red now · 2 more to go'), findsOneWidget);
    await send(tester, '0:5,1:5,2:900');
    expect(find.text('Press the buzzer of Blue now · 1 more to go'), findsOneWidget);
    await send(tester, '0:5,1:5,2:5');
    await send(tester, '0:900,1:5,2:5');
    await send(tester, '0:5,1:5,2:5');
    await send(tester, '0:5,1:900,2:5');
    expect(assigned, {2: 'red', 0: 'blue', 1: 'green'});
    expect(find.textContaining('Press the buzzer of'), findsNothing);
  });

  testBuzzers('a team without any buzzer is flagged', (tester) async {
    await pumpView(tester);
    await send(tester, '0:5,1:5');
    expect(find.text('No buzzer'), findsOneWidget);
    expect(find.text('Buzzer 1'), findsOneWidget);
  });

  testBuzzers('calibration: hands off, then press, then thresholds are set', (tester) async {
    await pumpView(tester);
    await send(tester, '0:20,1:30');
    await tester.tap(find.text('Calibrate'));
    await tester.pump();
    expect(find.text('Hands off all buzzers for a moment…'), findsOneWidget);
    for (var i = 0; i < 26; i++) {
      await send(tester, '0:20,1:30');
    }
    expect(find.text('Now press every buzzer once, as hard as a player would.'), findsOneWidget);
    await send(tester, '0:820,1:30');
    await send(tester, '0:20,1:30');
    expect(find.text('Got buzzer 1.'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(thresholds, {0: 420});
  });

  testBuzzers('raw data is hidden until switched on, then shows what the box sends', (tester) async {
    await pumpView(tester);
    await send(tester, '0:5,1:5,2:5');
    await send(tester, 'garbage!');
    expect(find.byKey(const ValueKey('serial-console')), findsNothing);
    expect(find.textContaining('garbage!'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.byKey(const ValueKey('serial-console')), findsOneWidget);
    expect(find.textContaining('0:5,1:5,2:5\ngarbage!'), findsOneWidget);

    // It follows along.
    await send(tester, '0:900,1:5,2:5');
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('0:900,1:5,2:5'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.byKey(const ValueKey('serial-console')), findsNothing);
  });

  test('only the last lines are kept', () {
    final port = FakePort();
    var now = 1000;
    final link = BuzzerLink(port, clock: () => now);
    link.use('COM3');
    for (var i = 0; i < 500; i++) {
      port.send('0:$i\n');
      now += 10;
      link.poll();
    }
    expect(link.recentLines.length, lessThanOrEqualTo(40));
    expect(link.recentLines.last, '0:499');
    link.dispose();
  });

  testWidgets('team sounds: who has one, who is uploading, and the buttons', (tester) async {
    final chosen = <String>[];
    final cleared = <String>[];
    final builtin = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TeamSoundsList(
          teams: const [
            Team(id: 'red', name: 'Red', sound: 'horn.mp3'),
            Team(id: 'blue', name: 'Blue'),
            Team(id: 'green', name: 'Green'),
          ],
          uploading: const {'green'},
          onChoose: (team) => chosen.add(team.id),
          onClear: (team) => cleared.add(team.id),
          onBuiltin: (team, key) => builtin.add('${team.id} $key'),
        ),
      ),
    ));
    expect(find.text('Own sound'), findsOneWidget);
    expect(find.text('Buzzer'), findsOneWidget);
    expect(find.text('Uploading…'), findsOneWidget);
    // The spinner of an upload never settles; the menus are tried without it.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TeamSoundsList(
          teams: const [Team(id: 'red', name: 'Red', sound: 'horn.mp3'), Team(id: 'blue', name: 'Blue')],
          uploading: const {},
          onChoose: (team) => chosen.add(team.id),
          onClear: (team) => cleared.add(team.id),
          onBuiltin: (team, key) => builtin.add('${team.id} $key'),
        ),
      ),
    ));
    // Red uploads another sound of its own, Blue takes the power buzzer.
    await tester.tap(find.text('Choose').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload own sound…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Power'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to the built-in buzzer'));
    expect(chosen, ['red']);
    expect(builtin, ['blue builtin:buzzer/power']);
    expect(cleared, ['red']);
  });
}
