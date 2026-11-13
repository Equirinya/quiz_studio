/// Test bots: teams that play by themselves, so a show with many devices can
/// be tried out alone. Plain Dart.
library;

import 'dart:math';

import 'commands.dart';
import 'companion.dart';
import 'content.dart';
import 'drawing.dart';
import 'reducer.dart';
import 'session_state.dart';

/// The next thing a bot playing [teamId] does, or null when it has nothing to
/// do: bet, answer the round, lock in, or now and then buzz. Answers are
/// random, so some come out right.
Command? botMove(SessionState state, GameContent? game, String teamId, Random random) {
  final question = state.current == null ? null : game?.question(state.current!);
  final team = state.team(teamId);
  if (team == null) return null;

  final betting = state.betting;
  if (betting != null && betting.open && question != null && !betting.bets.containsKey(teamId)) {
    final most = maxBet(team, question);
    return PlaceBet(teamId, question.amountBet != null ? 1 + random.nextInt(most) : (random.nextInt(most ~/ 10 + 1) * 10));
  }

  final round = state.answerRound;
  if (round != null && round.open) {
    if (!round.takesPart(teamId)) return null;
    final answer = round.answers[teamId];
    if (answer == null || answer.isEmpty) {
      final made = botAnswer(round.spec, random);
      return made == null ? null : SubmitAnswer(teamId, made);
    }
    return answer.locked || !canLockIn(state, game) ? null : LockAnswer(teamId);
  }

  if (buzzersOpen(state, game) && !state.buzzQueue.contains(teamId) && random.nextDouble() < 0.3) return Buzz(teamId);
  return null;
}

const List<String> _words = ['Paris', 'Einstein', '1969', 'Blue whale', 'Mozart', 'No idea', 'Pizza', 'Mount Everest'];

/// A random answer for the screen [spec]; null for word groups, which are
/// played guess by guess.
PlayerAnswer? botAnswer(CompanionSpec spec, Random random) {
  List<int> shuffled(int length) => List<int>.generate(length, (i) => i)..shuffle(random);
  switch (spec.kind) {
    case CompanionKind.choice:
      if (spec.options.isEmpty) return null;
      if (spec.multiple) {
        final picks = [for (var i = 0; i < spec.options.length; i++) if (random.nextBool()) i];
        return PlayerAnswer(choices: picks.isEmpty ? [random.nextInt(spec.options.length)] : picks);
      }
      return PlayerAnswer(choice: random.nextInt(spec.options.length));
    case CompanionKind.order:
      return PlayerAnswer(order: shuffled(spec.options.length));
    case CompanionKind.match:
      return PlayerAnswer(pairs: shuffled(spec.options.length));
    case CompanionKind.number:
    case CompanionKind.slider:
      final range = spec.range;
      final solution = spec.solution;
      // Near the solution when there is one, as a team that half knows.
      final raw = solution != null
          ? solution * (0.6 + random.nextDouble() * 0.8)
          : spec.kind == CompanionKind.slider
          ? range.min + random.nextDouble() * (range.max - range.min)
          : 1 + random.nextInt(100).toDouble();
      final stepped = (raw / range.step).round() * range.step;
      return PlayerAnswer(number: spec.kind == CompanionKind.slider ? stepped.clamp(range.min, range.max).toDouble() : stepped);
    case CompanionKind.text:
      return PlayerAnswer(text: _words[random.nextInt(_words.length)]);
    case CompanionKind.list:
      return PlayerAnswer(items: [for (var i = 0; i < spec.listRows; i++) random.nextInt(3) == 0 ? '' : _words[random.nextInt(_words.length)]]);
    case CompanionKind.whiteboard:
      // A scribble: a few wavy lines across the board.
      final strokes = <Stroke>[
        for (var line = 0; line < 1 + random.nextInt(3); line++)
          [
            for (var x = 0; x <= 20; x++)
              (0.1 + x * 0.04, 0.2 + line * 0.25 + sin(x * 0.8 + random.nextDouble()) * 0.06),
          ],
      ];
      return PlayerAnswer(drawing: encodeDrawing(strokes));
    case CompanionKind.connections:
      return null;
  }
}
