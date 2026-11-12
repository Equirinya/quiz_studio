// How much the host draws while twelve teams write on their whiteboards:
// controller and presenter side by side, every team sending its growing
// drawing after each stroke, frames pumped at 60 per second for four
// minutes of (fake) time. Prints, per 30 s, how many ink points were
// painted per second and how long a frame took to build and paint.
//
//   flutter test tool/whiteboard_load_test.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/companion/whiteboard.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

const _board = QuestionRef('c1', 'board');

GameContent _game() => GameContent.assemble(
  id: 'game',
  game: {'name': 'Load'},
  groups: {
    'g1': {'name': 'Round 1', 'categoryGroupType': 'category_wheel', 'categoryGroupIndex': 0},
  },
  categories: {
    'c1': {'name': 'First', 'categoryGroup': 'g1', 'categoryIndex': 0, 'active': true},
  },
  questions: {
    'c1': {
      'board': {
        'type': 'free',
        'question': 'Draw it',
        'noBuzzer': true,
        'pointsPlus': 100,
        'companion': {'kind': 'whiteboard', 'timer': 900},
      },
    },
  },
);

/// A wobbly line of [points] points somewhere on the board.
Stroke _stroke(Random random, int points) {
  var x = random.nextDouble();
  var y = random.nextDouble();
  return [
    for (var i = 0; i < points; i++) (x = (x + random.nextDouble() * 0.04 - 0.02).clamp(0, 1), y = (y + random.nextDouble() * 0.04 - 0.02).clamp(0, 1)),
  ];
}

void main() {
  testWidgets('twelve teams writing for four minutes', (tester) async {
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = SessionHost(
      initial: SessionState(
        gameId: 'game',
        teams: [for (var i = 0; i < 12; i++) Team(id: 't$i', name: 'Team ${i + 1}')],
      ),
    );
    final connection = SessionConnection.local(host, game: _game());
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(width: 600, child: ControllerView(connection: connection)),
              Expanded(child: PresenterView(connection: connection)),
            ],
          ),
        ),
      ),
    );
    host.dispatch(const OpenQuestion(_board));
    await tester.pump();
    expect(host.state.answerRound, isNotNull);

    final random = Random(7);
    final strokes = {for (var i = 0; i < 12; i++) i: <Stroke>[]};
    const frame = Duration(microseconds: 16667);
    const window = 30 * 60; // frames
    const minutes = 4;
    final watch = Stopwatch();
    var painted = 0;
    var sent = 0;
    WhiteboardPainter.debugPaintedPoints = 0;
    for (var f = 0; f < minutes * 60 * 60; f++) {
      // Every team finishes a stroke about every 2.4 s, each at its own moment.
      for (var team = 0; team < 12; team++) {
        if ((f + team * 12) % 144 != 0) continue;
        strokes[team]!.add(_stroke(random, 40));
        host.dispatch(SubmitAnswer('t$team', PlayerAnswer(drawing: encodeDrawing(strokes[team]!))));
        sent++;
      }
      watch.start();
      await tester.pump(frame);
      watch.stop();
      if ((f + 1) % window == 0) {
        final points = WhiteboardPainter.debugPaintedPoints - painted;
        painted = WhiteboardPainter.debugPaintedPoints;
        final ink = strokes.values.fold(0, (sum, s) => sum + s.fold(0, (n, stroke) => n + stroke.length));
        // ignore: avoid_print
        print(
          't=${(f + 1) ~/ 60}s  ink on boards ${(ink / 12).round()} pts/team  '
          'painted ${(points / 30).round()} pts/s  '
          'frame ${(watch.elapsedMicroseconds / window / 1000).toStringAsFixed(2)} ms  '
          'drawings sent $sent',
        );
        watch.reset();
      }
    }
    // Let the round's own timer run out, so no timer is left pending.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 20));
  }, timeout: const Timeout(Duration(minutes: 30)));
}
