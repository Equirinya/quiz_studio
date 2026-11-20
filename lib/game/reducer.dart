/// The rules of the show: `(state, command) -> state`. Pure and synchronous;
/// the host is the only place it runs for real.
library;

import 'commands.dart';
import 'companion.dart';
import 'content.dart';
import 'last_standing.dart';
import 'played_round.dart';
import 'rapid_fire.dart';
import 'rating.dart';
import 'scoring.dart';
import 'session_state.dart';

/// Something the presenter should do once, as opposed to state it should show.
sealed class Effect {
  const Effect();
}

/// A team's buzzer sound.
class BuzzerSound extends Effect {
  const BuzzerSound(this.teamId);
  final String teamId;
}

/// A sound effect by key, resolved against the game's `MusicConfig.effects`.
class SoundEffect extends Effect {
  const SoundEffect(this.key, {this.held = false, this.from});
  final String key;

  /// The question whose sounds it is chosen from, when it has just closed
  /// and so is no longer the open one.
  final QuestionRef? from;

  /// Started by hand: listed in `SessionState.effectsPlaying` until it ends,
  /// and can be stopped.
  final bool held;
}

/// Stops an effect started by hand ([SoundEffect.held]); null stops them all.
class StopSound extends Effect {
  const StopSound(this.key);
  final String? key;
}

/// A one-shot animation over the whole screen; see `screenEffects`.
class VisualEffect extends Effect {
  const VisualEffect(this.name);
  final String name;
}

class Reduction {
  const Reduction(this.state, {this.effects = const [], this.accepted = true, this.rounds = const {}, this.clearRounds = false});

  final SessionState state;
  final List<Effect> effects;

  /// Rounds of played questions to keep, by [QuestionRef.key]; null drops
  /// the one kept for that question. See [PlayedRound].
  final Map<String, PlayedRound?> rounds;

  /// Every kept round goes, before [rounds] are kept.
  final bool clearRounds;

  /// False when the command made no sense in the current state and was dropped.
  final bool accepted;
}

/// Whether a buzz by any team would count right now.
/// Whether teams may lock their answer in now: only when the scoring goes by
/// time ("by order", fastest first); otherwise an answer simply counts as it
/// stands when the time is up or the gamemaster ends the round. Word groups
/// are the exception: there stopping early means a team is done.
bool canLockIn(SessionState state, GameContent? game) {
  final round = state.answerRound;
  if (round == null || !round.open || !round.spec.lockable) return false;
  final question = state.current == null ? null : game?.question(state.current!);
  // ABCD still uncovering its options: the time to answer has not begun.
  if (question != null && _waitsForOptions(question, state.revealed)) return false;
  return question?.ranked == true || round.kind == CompanionKind.connections;
}

/// A Fragenhagel on the devices whose item on screen is still being
/// answered: "next" settles it first.
bool rapidToSettle(SessionState state, Question question) =>
    question.rapidFire?.mode == RapidMode.devices &&
    state.revealed >= 0 &&
    state.revealed < question.maxReveal &&
    state.phase != Phase.answerRevealed;

/// A Fragenhagel on the devices whose item on screen is settled: locked,
/// scored, its answer up.
bool rapidSettled(SessionState state, Question question) =>
    question.rapidFire?.mode == RapidMode.devices &&
    state.revealed >= 0 &&
    state.revealed < question.maxReveal &&
    state.phase == Phase.answerRevealed;

/// A buzzer Fragenhagel's item on screen has been answered right: it stays
/// up until the gamemaster moves on, and nobody buzzes for it any more.
bool rapidAnswered(SessionState state) => state.rapidSteps[state.revealed]?.picks.containsValue(0) ?? false;

bool buzzersOpen(SessionState state, GameContent? game) {
  if (state.phase == Phase.buzzerTest) return true;
  // Bets come first.
  if (state.waitingForBets) return false;
  final ref = state.current;
  final question = ref == null ? null : game?.question(ref);
  if (question == null || !question.buzzerable) return false;
  // A Fragenhagel buzzes for its items: not while only the question itself
  // is up, and not once the last item is done.
  if (question.type == QuestionType.rapidFire && (state.revealed < 0 || state.revealed >= question.maxReveal)) return false;
  // Nor for an item a team has already got right.
  if (question.type == QuestionType.rapidFire && rapidAnswered(state)) return false;
  return state.phase == Phase.question || (state.phase == Phase.buzzered && state.queueBuzzers);
}

/// Whether a buzz by this particular team would count right now.
bool canBuzz(SessionState state, GameContent? game, String teamId) {
  if (state.team(teamId) == null || !buzzersOpen(state, game)) return false;
  return state.phase != Phase.buzzered || !state.buzzQueue.contains(teamId);
}

/// Feud: points for the answers uncovered so far, as their share of the
/// question's value.
int feudPoints(Question question, Iterable<int> revealed) {
  var share = 0.0;
  for (final index in revealed) {
    if (index >= 0 && index < question.percentages.length) share += question.percentages[index];
  }
  return (share * question.pointsPlus / 100).round();
}

/// Feud: the team that may steal, which is the next in the buzz queue or, with
/// exactly two teams, simply the other one.
String? feudOpponent(SessionState state) {
  if (state.buzzQueue.length > 1) return state.buzzQueue[1];
  if (state.buzzQueue.isEmpty || state.teams.length != 2) return null;
  return state.teams.firstWhere((team) => team.id != state.buzzQueue.first).id;
}

/// Applies [command]. [game] is the content the session is playing; without
/// it, commands that depend on a question are dropped.
///
/// [now] is the host's clock in milliseconds; it is only needed to start the
/// timer of an answer round, and is passed in so this stays a pure function.
///
/// Every change to a team's score, whatever the command, is added to
/// [SessionState.scoreLog].
///
/// [stored] are the rounds kept from played questions, which an
/// [OpenQuestion] with `restore` brings back.
Reduction reduce(SessionState s, Command command, GameContent? game, {int? now, Map<String, PlayedRound> stored = const {}}) {
  var result = _reduce(s, command, game, now: now, stored: stored);
  if (!result.accepted) return result;
  result = _rateByItself(s, result, game, now);
  final clocked = _mediaClockFor(s, result.state, game, now);
  if (!identical(clocked, result.state)) {
    result = Reduction(clocked, effects: result.effects, rounds: result.rounds, clearRounds: result.clearRounds);
  }
  // Stamped only on a change: an effect alone (a sound) leaves the state be.
  if (now != null && !identical(result.state, s)) {
    result = Reduction(
      result.state.copyWith(clockMillis: now),
      effects: result.effects,
      rounds: result.rounds,
      clearRounds: result.clearRounds,
    );
  }
  result = _keepRound(s, command, result, game, now);
  // Starting over: nothing to show for the scores going back to 0.
  if (command is ClearSessionData) return result;
  final before = {for (final team in s.teams) team.id: team.points};
  var id = s.scoreLog.isEmpty ? 0 : s.scoreLog.last.id;
  final changes = [
    for (final team in result.state.teams)
      if (before[team.id] case final points? when points != team.points)
        ScoreChange(id: ++id, teamId: team.id, delta: team.points - points),
  ];
  if (changes.isEmpty) return result;
  final log = [...s.scoreLog, ...changes];
  return Reduction(
    result.state.copyWith(scoreLog: log.length > kScoreLogLength ? log.sublist(log.length - kScoreLogLength) : log),
    effects: result.effects,
    rounds: result.rounds,
    clearRounds: result.clearRounds,
  );
}

/// Answers that became final with this command (locked in, or answering
/// closed) rated right away where the question [ratesItself], through the
/// same commands as tapping right or wrong. Ratings the gamemaster made stay.
Reduction _rateByItself(SessionState s, Reduction result, GameContent? game, int? now) {
  final next = result.state;
  final round = next.answerRound;
  final question = next.current == null ? null : game?.question(next.current!);
  // A question opened again comes back as it was left.
  if (round == null || question == null || next.current != s.current || !ratesItself(question, round)) return result;
  bool done(AnswerRound? round, String teamId) => round != null && (!round.open || round.answers[teamId]?.locked == true);
  final newly = [
    for (final team in next.roundTeams)
      if (done(round, team.id) && !done(s.answerRound, team.id)) team.id,
  ];
  if (newly.isEmpty) return result;
  var state = next;
  final effects = [...result.effects];
  for (final command in ratingByItself(next, round, question, newly)) {
    final rated = _reduce(state, command, game, now: now);
    if (!rated.accepted) continue;
    state = rated.state;
    effects.addAll(rated.effects);
  }
  return identical(state, next) ? result : Reduction(state, effects: effects, rounds: result.rounds, clearRounds: result.clearRounds);
}

/// Which sound or clip of the open question is playing in [s], if any.
String? _mediaOf(SessionState s, GameContent? game) {
  if (s.media == MediaPlayback.stopped || s.current == null) return null;
  final question = game?.question(s.current!);
  return '${s.current!.key}|${question?.musicAt(s.revealed, s.standing)}|${question?.videoAt(s.revealed, s.standing)}';
}

/// [next] with its [SessionState.mediaClock] following what happened to the
/// question's sound since [s]: started over for another one, held while it
/// is paused, gone when it stops.
SessionState _mediaClockFor(SessionState s, SessionState next, GameContent? game, int? now) {
  final media = _mediaOf(next, game);
  var clock = media != null && media == _mediaOf(s, game) ? next.mediaClock : null;
  if (media != null && now != null) {
    clock ??= const MediaClock();
    if (next.media == MediaPlayback.playing && !clock.running) clock = clock.startedAt(now);
    if (next.media == MediaPlayback.paused && clock.running) clock = clock.pausedAt(now);
  }
  return clock == next.mediaClock ? next : next.copyWith(mediaClock: clock);
}

/// A question closed as played keeps what it left behind, replacing what
/// an earlier time it was played left.
Reduction _keepRound(SessionState s, Command command, Reduction result, GameContent? game, int? now) {
  final current = s.current;
  final next = result.state;
  if (current == null || next.current == current || !next.played.contains(current.key)) return result;
  // As it was closed: what was rated counts as given.
  final closing = command is CloseQuestion || command is OpenQuestion ? _givenBeforeClosing(s, game) : s;
  final round = PlayedRound.of(closing, now: now);
  if (round == null && !next.storedRounds.contains(current.key)) return result;
  return Reduction(
    next.copyWith(storedRounds: round == null ? ({...next.storedRounds}..remove(current.key)) : {...next.storedRounds, current.key}),
    effects: result.effects,
    rounds: {...result.rounds, current.key: round},
    clearRounds: result.clearRounds,
  );
}

Reduction _reduce(SessionState s, Command command, GameContent? game, {int? now, Map<String, PlayedRound> stored = const {}}) {
  final question = s.current == null ? null : game?.question(s.current!);
  final questionOpen = s.current != null && (s.phase == Phase.question || s.phase == Phase.buzzered || s.phase == Phase.answerRevealed);

  switch (command) {
    // ── game and board ───────────────────────────────────────────────────────
    case SetGame(:final gameId):
      return Reduction(
        _ok(_backToBoard(s).copyWith(gameId: gameId, groupId: null, played: const {}, storedRounds: const {}, music: null)).state,
        clearRounds: s.storedRounds.isNotEmpty,
      );

    case SelectGroup(:final groupId):
      if (s.current != null) return _no(s);
      if (game != null && game.group(groupId) == null) return _no(s);
      // An information screen starts its clock as it is shown (again); a
      // board has none.
      final seconds = game?.group(groupId)?.timerSeconds;
      return _ok(
        s.copyWith(
          groupId: groupId,
          timer: seconds == null || now == null ? null : QuestionTimer(openedAtMillis: now, endsAtMillis: now + seconds * 1000),
        ),
      );

    case OpenQuestion(:final ref, :final restore):
      if (s.phase == Phase.buzzerTest || game?.question(ref) == null) return _no(s);
      final kept = restore ? stored[ref.key] : null;
      if (restore && kept == null) return _no(s);
      final opened = game!.question(ref)!;
      final companion = opened.companion;
      final next = _backToBoard(_givenBeforeClosing(s, game)).copyWith(
        phase: Phase.question,
        current: ref,
        groupId: game.groupOfCategory(ref.categoryId)?.id ?? s.groupId,
        boardFocus: ref.categoryId,
        // Brought back as it was played: it is being played again.
        played: {...s.played, ?s.current?.key}..remove(kept == null ? null : ref.key),
        // A question with a companion screen puts it on the teams' devices
        // the moment it opens; with bets, once they are placed.
        answerRound: companion == null || opened.hasBets ? null : _newRound(companion, now, timed: !_waitsForOptions(opened, 0)),
        // Last team standing: the turn order is fixed as it opens.
        standing: opened.type == QuestionType.lastStanding
            ? StandingPlay(order: turnOrder(s.teams, opened.lastStanding?.order ?? TurnOrder.teams), started: false)
            : null,
        betting: opened.hasBets ? const Betting() : null,
        timer: opened.hasBets || _waitsForOptions(opened, 0) ? null : _timerFor(opened, now),
      );
      if (kept != null) {
        final finished = opened.type == QuestionType.rapidFire && kept.revealed >= opened.maxReveal;
        return _ok(kept.restoreInto(next).copyWith(phase: finished ? Phase.answerRevealed : null), const [
          SoundEffect(effectQuestionOpen),
        ]);
      }
      // A Fragenhagel starts with only the question itself on screen; the
      // first "next" brings up its first item.
      return _ok(opened.type == QuestionType.rapidFire ? _rapidAt(next, opened, -1, now) : next, const [SoundEffect(effectQuestionOpen)]);

    case CloseQuestion(:final markPlayed):
      if (s.current == null) return _no(s);
      return _ok(
        _backToBoard(markPlayed ? _givenBeforeClosing(s, game) : s).copyWith(played: markPlayed ? {...s.played, s.current!.key} : null),
        [if (markPlayed) SoundEffect(effectAnswerClosed, from: s.current)],
      );

    // ── bets ─────────────────────────────────────────────────────────────────
    case PlaceBet(:final teamId, :final amount):
      final team = s.team(teamId);
      final betting = s.betting;
      if (!s.placingBets || betting == null || team == null || question == null) return _no(s);
      final limit = maxBet(team, question);
      final bet = amount < 0 ? 0 : (amount > limit ? limit : amount);
      if (betting.bets[teamId] == bet) return _no(s);
      return _ok(s.copyWith(betting: betting.copyWith(bets: {...betting.bets, teamId: bet})));

    case CloseBets():
      if (!s.placingBets || question == null) return _no(s);
      return _ok(s.copyWith(betting: s.betting!.copyWith(open: false, shown: true)), const [SoundEffect(effectReveal)]);

    case StartQuestion():
      if (!s.betsShown || question == null) return _no(s);
      var companion = question.companion;
      // A list to fill in gets a line for every one the boldest team bet.
      if (companion != null && question.amountBet != null) {
        final most = s.betting!.bets.values.fold(0, (a, b) => a > b ? a : b);
        if (most > companion.listRows) companion = companion.withListRows(most);
      }
      return _ok(
        s.copyWith(
          betting: s.betting!.copyWith(shown: false),
          answerRound: companion == null ? null : _newRound(companion, now, timed: !_waitsForOptions(question, s.revealed)),
          timer: _waitsForOptions(question, s.revealed) ? null : _timerFor(question, now),
        ),
        const [SoundEffect(effectQuestionOpen)],
      );

    case JudgeBet(:final teamId, :final reached):
      if (question?.amountBet == null || s.betting == null) return _no(s);
      return _reduce(s, RateAnswer(teamId, correct: reached), game, now: now);

    case SetTimer(:final seconds):
      final timer = s.timer;
      // A question's clock, or an information screen's.
      final info = question == null && s.current == null && game?.group(s.groupId)?.isInfo == true;
      if ((question == null && !info) || now == null || seconds == 0) return _no(s);
      if (seconds == null) return timer == null ? _no(s) : _ok(s.copyWith(timer: null));
      // Running: the time goes on top. Up or none yet: a fresh clock.
      final running = timer != null && timer.running && timer.endsAtMillis > now;
      // Less time: only off a running clock, and never into the past; at
      // nothing left the time is up as usual.
      if (seconds < 0) {
        if (!running) return _no(s);
        final ends = timer.endsAtMillis + seconds * 1000;
        return _ok(s.copyWith(timer: QuestionTimer(openedAtMillis: timer.openedAtMillis, endsAtMillis: ends < now ? now : ends)));
      }
      return _ok(
        s.copyWith(
          timer: running
              ? QuestionTimer(openedAtMillis: timer.openedAtMillis, endsAtMillis: timer.endsAtMillis + seconds * 1000)
              : QuestionTimer(openedAtMillis: now, endsAtMillis: now + seconds * 1000),
        ),
      );

    case TimeUp():
      final timer = s.timer;
      if (timer == null || !timer.running) return _no(s);
      return _ok(
        s.copyWith(
          timer: QuestionTimer(openedAtMillis: timer.openedAtMillis, endsAtMillis: timer.endsAtMillis, running: false),
        ),
        const [SoundEffect(effectTimesUp)],
      );

    case UnmarkPlayed(:final ref):
      if (!s.played.contains(ref.key)) return _no(s);
      return _ok(s.copyWith(played: {...s.played}..remove(ref.key)));

    case ClearSessionData():
      return Reduction(
        _ok(
          _backToBoard(s).copyWith(
            teams: [for (final team in s.teams) team.copyWith(points: 0)],
            played: const {},
            storedRounds: const {},
            scoreLog: const [],
            overlay: null,
          ),
        ).state,
        clearRounds: true,
      );

    // ── buzzing and judging ──────────────────────────────────────────────────
    case SetBuzzerTest(:final on):
      if (on ? s.phase != Phase.overview : s.phase != Phase.buzzerTest) return _no(s);
      return _ok(s.copyWith(phase: on ? Phase.buzzerTest : Phase.overview, buzzQueue: const []));

    case Buzz(:final teamId):
      if (!canBuzz(s, game, teamId)) return _no(s);
      final sound = [BuzzerSound(teamId)];
      if (s.phase == Phase.buzzerTest) return _ok(s.copyWith(buzzQueue: [teamId]), sound);
      if (s.phase == Phase.buzzered) return _ok(s.copyWith(buzzQueue: [...s.buzzQueue, teamId]), sound);
      return _ok(
        s.copyWith(
          phase: Phase.buzzered,
          buzzQueue: [teamId],
          media: s.media == MediaPlayback.playing ? MediaPlayback.paused : null,
        ),
        sound,
      );

    case Judge(:final correct):
      if (s.phase != Phase.buzzered || s.buzzQueue.isEmpty || question == null || !question.defaultJudging) return _no(s);
      // Top answers: right means tapping the answer the team named.
      if (correct && question.type == QuestionType.topAnswers) return _no(s);
      final team = s.buzzQueue.first;
      if (correct && question.type == QuestionType.rapidFire) {
        // Right: the points, and the item stays up, answered, until the
        // gamemaster moves on.
        final scored = _rapidScore(s, team, question.pointsPlus);
        final step = scored.rapidSteps[s.revealed]!.withPick(team, 0);
        return _ok(
          scored.copyWith(
            phase: Phase.question,
            buzzQueue: const [],
            wrongAttempts: 0,
            rapidSteps: {...scored.rapidSteps, s.revealed: step},
          ),
          const [SoundEffect(effectAnswerCorrect)],
        );
      }
      if (correct) {
        return _ok(
          _backToBoard(
            s,
          ).copyWith(teams: _addPoints(s.teams, team, pointsIfRight(s, question, team)), played: {...s.played, s.current!.key}),
          const [SoundEffect(effectAnswerCorrect)],
        );
      }
      if (question.type == QuestionType.rapidFire) {
        return _ok(_nextBuzzer(_rapidScore(s, team, -question.pointsMinus), question), const [SoundEffect(effectAnswerWrong)]);
      }
      return _ok(_nextBuzzer(s, question).copyWith(teams: _addPoints(s.teams, team, -pointsIfWrong(s, question, team))), const [
        SoundEffect(effectAnswerWrong),
      ]);

    case SkipBuzzer():
      if (s.phase != Phase.buzzered || s.buzzQueue.length < 2) return _no(s);
      return _ok(s.copyWith(buzzQueue: s.buzzQueue.sublist(1)));

    case ReopenQuestion():
      if (s.phase != Phase.buzzered || question == null) return _no(s);
      return _ok(
        s.copyWith(
          phase: Phase.question,
          buzzQueue: const [],
          wrongAttempts: 0,
          media: question.hasMediaAt(s.revealed, s.standing) ? MediaPlayback.playing : null,
        ),
      );

    // ── reveals ──────────────────────────────────────────────────────────────
    case Reveal(:final delta):
      if (!questionOpen || question == null || delta == 0 || s.waitingForBets) return _no(s);
      var revealed = s.revealed + delta;
      // Put in order and matching: once all but one are placed, the last
      // has only one place left, so it goes with the one before it, there
      // and back.
      final placing = question.type == QuestionType.ordering || question.type == QuestionType.matching;
      if (placing && question.maxReveal >= 2 && revealed == question.maxReveal - 1) {
        revealed += delta > 0 ? 1 : -1;
      }
      final rapid = question.type == QuestionType.rapidFire;
      // A Fragenhagel goes back as far as the question itself (-1).
      if (revealed < (rapid ? -1 : 0) || revealed > question.maxReveal) return _no(s);
      if (rapid) {
        // On the devices "next" first ends the item: every team is locked,
        // the picks are scored and the answer goes up; only then on.
        final settled = rapidSettled(s, question);
        if (delta < 0) return _ok(_rapidBack(s, question, settled ? s.revealed : revealed, now));
        if (rapidToSettle(s, question)) {
          final round = s.answerRound;
          return _ok(
            _scoreRapidItem(s, question).copyWith(
              phase: Phase.answerRevealed,
              answerRound: round?.copyWith(open: false, endsAtMillis: null),
            ),
            const [SoundEffect(effectReveal)],
          );
        }
        // Scored as it was settled; on the whiteboard as the gamemaster moves on.
        final scored = settled ? s : _scoreRapidItem(s, question);
        final finished = revealed >= question.maxReveal;
        return _ok(_rapidAt(scored, question, revealed, now), [SoundEffect(finished ? effectFanfare : effectNextItem)]);
      }
      // The enlarged image follows a new reveal and never points past the
      // last revealed one.
      final focus = delta > 0 ? revealed : (s.imageFocus > revealed ? revealed : s.imageFocus);
      var shown = s.copyWith(revealed: revealed, imageFocus: question.type == QuestionType.progressingReveal ? focus : null);
      // ABCD: the clock starts once the last option is up.
      if (_waitsForOptions(question, s.revealed) && !_waitsForOptions(question, revealed) && !s.waitingForBets) {
        shown = _startClocks(shown, question, now);
      }
      // Teams keep playing while groups come up; their time runs on.
      return _ok(shown, [
        if ((question.type == QuestionType.connections || placing) && delta > 0)
          const SoundEffect(effectReveal),
      ]);

    case ImageFocus(:final delta):
      if (!questionOpen || question == null || delta == 0) return _no(s);
      final focus = s.imageFocus + delta;
      if (question.type == QuestionType.progressingReveal) {
        if (focus < 0 || focus > s.revealed) return _no(s);
        return _ok(s.copyWith(imageFocus: focus));
      }
      // Pictures one after another: which of them is on screen.
      final pictures = question.picturesNow(s);
      if (!pictures.stepsThroughPictures || focus < 0 || focus >= pictures.images.length) return _no(s);
      return _ok(s.copyWith(imageFocus: focus));

    case MediaFullscreen(:final on):
      if (!questionOpen || question == null || on == s.mediaFullscreen) return _no(s);
      if (on && !question.hasScreenMediaNow(s)) return _no(s);
      return _ok(s.copyWith(mediaFullscreen: on));

    case FeudToggle(:final index):
      if (!_feudAnswering(s, question) || index < 0 || index >= question!.information.length) return _no(s);
      if (s.feudRevealed.contains(index)) {
        return _ok(s.copyWith(feudRevealed: [...s.feudRevealed]..remove(index)));
      }
      final revealed = [...s.feudRevealed, index];
      if (revealed.length < question.information.length) {
        return _ok(s.copyWith(feudRevealed: revealed), const [SoundEffect(effectReveal)]);
      }
      // The last answer is uncovered: the answering team takes everything.
      return _ok(
        s.copyWith(
          feudRevealed: revealed,
          phase: Phase.answerRevealed,
          teams: _addPoints(s.teams, s.buzzQueue.first, feudPoints(question, revealed)),
        ),
        const [SoundEffect(effectFanfare)],
      );

    case FeudWrong():
      if (!_feudAnswering(s, question) || s.wrongAttempts >= 3) return _no(s);
      // The third strike hands the other team its chance to steal.
      return _ok(s.copyWith(wrongAttempts: s.wrongAttempts + 1), [
        const SoundEffect(effectAnswerWrong),
        if (s.wrongAttempts + 1 == 3) const SoundEffect(effectSteal),
      ]);

    case FeudSteal(:final success):
      if (!_feudAnswering(s, question) || s.wrongAttempts < 3) return _no(s);
      final winner = success ? feudOpponent(s) : s.buzzQueue.first;
      return _ok(
        s.copyWith(
          phase: Phase.answerRevealed,
          wrongAttempts: 0,
          feudRevealed: [for (var i = 0; i < question!.information.length; i++) i],
          teams: winner == null ? null : _addPoints(s.teams, winner, feudPoints(question, s.feudRevealed)),
        ),
        [SoundEffect(success ? effectAnswerCorrect : effectAnswerWrong)],
      );

    case FeudResetWrong():
      if (!_feudAnswering(s, question) || s.wrongAttempts == 0) return _no(s);
      return _ok(s.copyWith(wrongAttempts: 0));

    case TopAnswerToggle(:final index):
      final top = question?.topAnswers;
      if (!questionOpen || question?.type != QuestionType.topAnswers || top == null) return _no(s);
      if (index < 0 || index >= top.items.length) return _no(s);
      final finder = s.foundBy[index];
      if (s.feudRevealed.contains(index)) {
        // Covered again: whoever found it gives the points back.
        return _ok(
          s.copyWith(
            feudRevealed: [...s.feudRevealed]..remove(index),
            foundBy: {...s.foundBy}..remove(index),
            teams: finder == null ? null : _addPoints(s.teams, finder, -top.pointsOf(index, question!.pointsPlus)),
            phase: s.phase == Phase.answerRevealed ? Phase.question : null,
          ),
        );
      }
      final revealed = [...s.feudRevealed, index];
      final all = revealed.length >= top.items.length;
      final answering = !top.onDevices && s.phase == Phase.buzzered && s.buzzQueue.isNotEmpty ? s.buzzQueue.first : null;
      if (answering == null) {
        return _ok(s.copyWith(feudRevealed: revealed, phase: all && !top.onDevices ? Phase.answerRevealed : null), [
          SoundEffect(all ? effectFanfare : effectReveal),
        ]);
      }
      // The answering team named it: its points, and the others may buzz again.
      final next = s.copyWith(
        feudRevealed: revealed,
        foundBy: {...s.foundBy, index: answering},
        teams: _addPoints(s.teams, answering, top.pointsOf(index, question!.pointsPlus)),
        buzzQueue: const [],
        phase: all ? Phase.answerRevealed : Phase.question,
        media: !all && question.hasMediaAt(s.revealed, s.standing) ? MediaPlayback.playing : null,
      );
      return _ok(next, [const SoundEffect(effectAnswerCorrect), if (all) const SoundEffect(effectFanfare)]);

    case MarkTopAnswers(:final teamId, :final found):
      final top = question?.topAnswers;
      final round = s.answerRound;
      if (round == null || top == null || s.team(teamId) == null) return _no(s);
      final indices = {
        for (final i in found)
          if (i >= 0 && i < top.items.length) i,
      }.toList()..sort();
      final before = [...?round.found[teamId]]..sort();
      if (_sameList(indices, before) && s.results.points.containsKey(teamId)) return _no(s);
      final points = top.pointsFor(indices, question!.pointsPlus);
      return _ok(
        s.copyWith(
          answerRound: round.copyWith(found: {...round.found, teamId: indices}),
          results: s.results.rated(teamId, indices.isNotEmpty, points: points),
        ),
      );

    // ── audio ────────────────────────────────────────────────────────────────
    case SetMedia(:final playback):
      if (playback == s.media) return _no(s);
      if (playback != MediaPlayback.stopped) {
        final listening = (s.phase == Phase.question || s.phase == Phase.buzzered) && !s.waitingForBets;
        if (!listening || !(question?.hasMediaAt(s.revealed, s.standing) ?? false)) return _no(s);
      }
      // The music waits while the question's own sound plays (see
      // `AudioDirector`), and comes back after.
      return _ok(s.copyWith(media: playback));

    case SetMusic(:final slot):
      if (slot == s.music || (slot != null && !musicSlots.contains(slot))) return _no(s);
      return _ok(s.copyWith(music: slot, media: slot != null && s.media == MediaPlayback.playing ? MediaPlayback.paused : null));

    case SetAmbience(:final slot):
      if (slot == s.ambience || (slot != null && !ambienceAssets.containsKey(slot))) return _no(s);
      return _ok(s.copyWith(ambience: slot));

    case SetMusicVolume(:final volume):
      final clamped = volume.clamp(0, 100);
      if (clamped == s.musicVolume) return _no(s);
      return _ok(s.copyWith(musicVolume: clamped));

    case SetAmbienceVolume(:final volume):
      final clamped = volume.clamp(0, 100);
      if (clamped == s.ambienceVolume) return _no(s);
      return _ok(s.copyWith(ambienceVolume: clamped));

    case SetEffectsVolume(:final volume):
      final clamped = volume.clamp(0, 100);
      if (clamped == s.effectsVolume) return _no(s);
      return _ok(s.copyWith(effectsVolume: clamped));

    case SetMediaVolume(:final volume):
      final clamped = volume.clamp(0, 100);
      if (clamped == s.mediaVolume) return _no(s);
      return _ok(s.copyWith(mediaVolume: clamped));

    case SeekMedia(:final positionMs):
      final clock = s.mediaClock;
      if (s.media == MediaPlayback.stopped || clock == null) return _no(s);
      final duration = clock.durationMs;
      final to = positionMs.clamp(0, duration ?? 1 << 40);
      final running = s.media == MediaPlayback.playing && now != null;
      return _ok(
        s.copyWith(
          mediaClock: MediaClock(positionMs: to, sinceMillis: running ? now : null, durationMs: duration),
          mediaSeek: s.mediaSeek + 1,
        ),
      );

    case MediaLoaded(:final durationMs):
      final clock = s.mediaClock;
      if (clock == null || durationMs <= 0 || clock.durationMs == durationMs) return _no(s);
      return _ok(s.copyWith(mediaClock: clock.withDuration(durationMs)));

    case StopEffect(:final key):
      if (key == null ? s.effectsPlaying.isEmpty : !s.effectsPlaying.contains(key)) return _no(s);
      return _ok(
        s.copyWith(effectsPlaying: key == null ? const [] : [for (final k in s.effectsPlaying) if (k != key) k]),
        [StopSound(key)],
      );

    case EffectEnded(:final key):
      if (key == null ? s.effectsPlaying.isEmpty : !s.effectsPlaying.contains(key)) return _no(s);
      return _ok(s.copyWith(effectsPlaying: key == null ? const [] : [for (final k in s.effectsPlaying) if (k != key) k]));

    case FocusCategory(:final categoryId):
      final group = game?.groupOfCategory(categoryId);
      // A question in play keeps its own category in view.
      if (group == null || s.current != null || categoryId == s.boardFocus) return _no(s);
      return _ok(s.copyWith(boardFocus: categoryId, groupId: group.id));

    case PlayEffect(:final key):
      // Played again while it still sounds: it starts over.
      final effects = [SoundEffect(key, held: true)];
      return s.effectsPlaying.contains(key) ? Reduction(s, effects: effects) : _ok(s.copyWith(effectsPlaying: [...s.effectsPlaying, key]), effects);

    // ── teams and points ─────────────────────────────────────────────────────
    case AdjustPoints(:final teamId, :final delta):
      if (s.team(teamId) == null || delta == 0) return _no(s);
      return _ok(s.copyWith(teams: _addPoints(s.teams, teamId, delta)));

    case SetPoints(:final teamId, :final points):
      final team = s.team(teamId);
      if (team == null || team.points == points) return _no(s);
      return _ok(s.copyWith(teams: _addPoints(s.teams, teamId, points - team.points)));

    case AddTeam(:final teamId, :final name):
      final trimmed = name.trim();
      if (teamId.isEmpty || trimmed.isEmpty) return _no(s);
      if (s.teams.any((team) => team.id == teamId || team.name == trimmed)) return _no(s);
      return _ok(
        s.copyWith(
          teams: [
            ...s.teams,
            Team(id: teamId, name: trimmed),
          ],
        ),
      );

    case RenameTeam(:final teamId, :final name):
      final trimmed = name.trim();
      if (s.team(teamId) == null || trimmed.isEmpty || s.teams.any((team) => team.name == trimmed)) return _no(s);
      return _ok(s.copyWith(teams: [for (final team in s.teams) team.id == teamId ? team.copyWith(name: trimmed) : team]));

    case RemoveTeam(:final teamId):
      if (s.team(teamId) == null) return _no(s);
      final queue = s.buzzQueue.where((id) => id != teamId).toList();
      final round = s.answerRound;
      return _ok(
        s.copyWith(
          teams: s.teams.where((team) => team.id != teamId).toList(),
          buzzQueue: queue,
          // Nobody is left to answer: let the others buzz again.
          phase: s.phase == Phase.buzzered && queue.isEmpty ? Phase.question : null,
          answerRound: round?.copyWith(
            answers: {...round.answers}..remove(teamId),
            revealed: [...round.revealed]..remove(teamId),
            found: {...round.found}..remove(teamId),
          ),
          betting: s.betting?.copyWith(bets: {...s.betting!.bets}..remove(teamId)),
          results: s.results.without(teamId),
          standing: s.standing?.without(teamId),
          foundBy: {
            for (final entry in s.foundBy.entries)
              if (entry.value != teamId) entry.key: entry.value,
          },
        ),
      );

    case SetTeamColor(:final teamId, :final color):
      if (s.team(teamId) == null || s.team(teamId)!.color == color) return _no(s);
      return _ok(s.copyWith(teams: [for (final team in s.teams) team.id == teamId ? team.withColor(color) : team]));

    case SetTeamSound(:final teamId, :final sound):
      final name = sound == null || sound.isEmpty ? null : sound;
      if (s.team(teamId) == null || s.team(teamId)!.sound == name) return _no(s);
      return _ok(s.copyWith(teams: [for (final team in s.teams) team.id == teamId ? team.withSound(name) : team]));

    case SetQueueBuzzers(:final on):
      if (on == s.queueBuzzers) return _no(s);
      return _ok(s.copyWith(queueBuzzers: on));

    // ── answers from the teams' own devices ─────────────────────────────────
    case OpenAnswers(:final spec, :final teams):
      if (!questionOpen || s.waitingForBets) return _no(s);
      return _ok(s.copyWith(answerRound: _newRound(spec, now, teams: [for (final team in s.teams) if (teams.contains(team.id)) team.id])));

    case SetRoundTeams(:final teams):
      final round = s.answerRound;
      if (round == null) return _no(s);
      final chosen = [for (final team in s.teams) if (teams.contains(team.id)) team.id];
      if (chosen.isEmpty) return _no(s);
      final next = chosen.length == s.teams.length ? const <String>[] : chosen;
      return _ok(s.copyWith(answerRound: round.withTeams(next)));

    case AllowNotes(:final teams):
      if (!questionOpen) return _no(s);
      return _ok(s.copyWith(notesTeams: [for (final team in s.teams) if (teams.contains(team.id)) team.id]));

    case WriteNotes(:final teamId, :final text):
      if (!questionOpen || !s.notesTeams.contains(teamId) || s.notes[teamId] == text) return _no(s);
      return _ok(s.copyWith(notes: {...s.notes, teamId: text}));

    case SubmitAnswer(:final teamId, :final answer):
      final round = s.answerRound;
      if (round == null || !round.open || s.team(teamId) == null || !round.takesPart(teamId) || !answer.matches(round.kind)) return _no(s);
      if (round.answers[teamId]?.locked == true) return _no(s);
      return _ok(s.copyWith(answerRound: round.copyWith(answers: {...round.answers, teamId: answer.asLocked(false)})));

    case LockAnswer(:final teamId):
      final round = s.answerRound;
      if (round == null || !canLockIn(s, game) || s.team(teamId) == null || !round.takesPart(teamId)) return _no(s);
      if (round.answers[teamId]?.locked == true) return _no(s);
      return _ok(
        s.copyWith(
          answerRound: _withAnswer(s, round, teamId, (round.answers[teamId] ?? const PlayerAnswer()).asLocked(true, atMillis: now)),
        ),
        const [SoundEffect(effectLockIn)],
      );

    case GuessConnection(:final teamId, :final positions):
      final round = s.answerRound;
      if (round == null || !round.open || round.kind != CompanionKind.connections || s.team(teamId) == null || !round.takesPart(teamId)) {
        return _no(s);
      }
      final spec = round.spec;
      final before = round.answers[teamId];
      final progress = before?.connections ?? const ConnectionsProgress();
      if (before?.locked == true || progress.finished(spec)) return _no(s);
      if (positions.length != kConnectionsGroupSize || positions.toSet().length != kConnectionsGroupSize) return _no(s);
      if (positions.any((p) => p < 0 || p >= kConnectionsWords)) return _no(s);
      final order = connectionsOrder(s.current?.key ?? '');
      final words = [for (final p in positions) order[p]]..sort();
      final levels = [for (final w in words) w ~/ kConnectionsGroupSize];
      // Words of a group already found are off the board.
      if (levels.any(progress.solved.contains)) return _no(s);
      // The same wrong guess again costs nothing and changes nothing.
      if (progress.wrong.any((guess) => _sameList(guess, words))) return _no(s);
      final counts = <int, int>{};
      for (final level in levels) {
        counts[level] = (counts[level] ?? 0) + 1;
      }
      final next = counts.length == 1
          ? ConnectionsProgress(solved: [...progress.solved, levels.first], wrong: progress.wrong, oneAway: progress.oneAway)
          : ConnectionsProgress(
              solved: progress.solved,
              wrong: [...progress.wrong, words],
              oneAway: [...progress.oneAway, counts.values.any((n) => n == kConnectionsGroupSize - 1)],
            );
      // All found or out of tries: the team is done, and when it was done counts.
      final done = next.finished(spec);
      final answer = PlayerAnswer(connections: next, locked: done, lockedAtMillis: done ? now : null);
      return _ok(s.copyWith(answerRound: _withAnswer(s, round, teamId, answer)));

    case AwardConnections():
      final round = s.answerRound;
      if (round == null || round.kind != CompanionKind.connections || question == null) return _no(s);
      // Rated and given in one go: every group found is worth its share.
      var results = s.results;
      for (final team in s.teams) {
        final points = connectionsPoints(question.pointsPlus, round.answers[team.id]?.connections);
        results = results.rated(team.id, points > 0, points: points);
      }
      final given = _give(s.copyWith(results: results), question);
      return identical(given.teams, s.teams) && given.results.given.length == s.results.given.length
          ? _no(s)
          : _ok(given, const [SoundEffect(effectAnswerCorrect)]);

    case LockAnswers():
      if (s.answerRound?.open != true) return _no(s);
      return _ok(s.copyWith(answerRound: s.answerRound!.copyWith(open: false, endsAtMillis: null)));

    case ExtendAnswers(:final seconds):
      final round = s.answerRound;
      if (round == null || now == null || (seconds != null && seconds <= 0)) return _no(s);
      if (seconds == null && round.open && round.endsAtMillis == null) return _no(s);
      final from = round.open && round.endsAtMillis != null && round.endsAtMillis! > now ? round.endsAtMillis! : now;
      return _ok(s.copyWith(answerRound: round.copyWith(open: true, endsAtMillis: seconds == null ? null : from + seconds * 1000)));

    case UnlockAnswer(:final teamId):
      if (!canUnlockAnswer(s, teamId)) return _no(s);
      final round = s.answerRound!;
      return _ok(
        s.copyWith(
          answerRound: round.copyWith(
            // Closed because everyone had locked in: open again, which
            // changes nothing for the others, still locked.
            open: true,
            answers: {...round.answers, teamId: round.answers[teamId]!.asLocked(false)},
          ),
        ),
      );

    case UnlockAnswers():
      final round = s.answerRound;
      if (round == null) return _no(s);
      return _ok(
        s.copyWith(
          answerRound: round.copyWith(
            open: true,
            endsAtMillis: null,
            answers: {for (final entry in round.answers.entries) entry.key: entry.value.asLocked(false)},
          ),
        ),
      );

    case RevealAnswer(:final teamId, :final show):
      final round = s.answerRound;
      if (round == null || s.team(teamId) == null || round.revealed.contains(teamId) == show) return _no(s);
      final revealed = s.copyWith(answerRound: _reveal(round, show ? [...round.revealed, teamId] : ([...round.revealed]..remove(teamId))));
      return _ok(
        // Rated already: its points go up as it comes up.
        show && question != null ? _giveTeam(revealed, question, teamId) : revealed,
        [if (show) ?_verdictSound(s, teamId)],
      );

    case RevealNextAnswer():
      final round = s.answerRound;
      final next = s.roundTeams.where((team) => round != null && !round.revealed.contains(team.id)).firstOrNull;
      if (round == null || next == null) return _no(s);
      final revealed = s.copyWith(answerRound: _reveal(round, [...round.revealed, next.id]));
      return _ok(question == null ? revealed : _giveTeam(revealed, question, next.id), [?_verdictSound(s, next.id)]);

    case RevealAnswers():
      final round = s.answerRound;
      if (round == null || s.roundTeams.every((team) => round.revealed.contains(team.id))) return _no(s);
      final newly = [
        for (final team in s.roundTeams)
          if (!round.revealed.contains(team.id)) team.id,
      ];
      var revealed = s.copyWith(answerRound: _reveal(round, [...round.revealed, ...newly]));
      if (question != null) {
        for (final teamId in newly) {
          revealed = _giveTeam(revealed, question, teamId);
        }
      }
      return _ok(revealed);

    case RateAnswer(:final teamId, :final correct):
      if (question == null || s.team(teamId) == null || s.waitingForBets) return _no(s);
      final results = s.results.rated(teamId, correct);
      if (s.results.verdicts[teamId] == correct && !s.results.points.containsKey(teamId)) return _no(s);
      // Heard only with the answer on the big screen; rated before it is
      // shown, it sounds as it comes up (see [_verdictSound]).
      final onScreen = s.answerRound?.revealed.contains(teamId) ?? false;
      final rated = s.copyWith(results: results);
      // On the big screen: its points go up at once.
      return _ok(
        onScreen ? _giveTeam(rated, question, teamId) : rated,
        [if (correct != null && onScreen) SoundEffect(correct ? effectAnswerCorrect : effectAnswerWrong)],
      );

    case AwardAnswer(:final teamId, :final points):
      if (question == null || s.team(teamId) == null || s.waitingForBets) return _no(s);
      if (s.results.points[teamId] == points && s.results.verdicts[teamId] == points > 0) return _no(s);
      final awarded = s.copyWith(results: s.results.rated(teamId, points > 0, points: points));
      final shown = s.answerRound?.revealed.contains(teamId) ?? false;
      return _ok(shown ? _giveTeam(awarded, question, teamId) : awarded);

    case PlaceTeam(:final teamId):
      if (question == null || !question.ranked || s.team(teamId) == null) return _no(s);
      final order = s.results.order;
      return _ok(
        s.copyWith(results: s.results.copyWith(order: order.contains(teamId) ? ([...order]..remove(teamId)) : [...order, teamId])),
      );

    case GivePoints():
      if (question == null || pointsToGive(s, question).isEmpty) return _no(s);
      return _ok(_give(s, question));

    case TakeTurn(:final result):
      final play = s.standing;
      if (question == null || play == null || play.current == null) return _no(s);
      final next = play.withTurn(result);
      final winner = next.winner;
      // The last team left wins, and its points go up at once; by places,
      // everyone's do once it is decided.
      var after = _standingMedia(s.copyWith(standing: next), question);
      if (winner != null) after = after.copyWith(results: after.results.rated(winner, true));
      if (winner != null || (question.standingByPlaces && next.finished)) after = _give(after, question);
      return _ok(after, [
        SoundEffect(result == StandingResult.right ? effectAnswerCorrect : effectAnswerWrong),
        if (winner != null) const SoundEffect(effectFanfare),
      ]);

    case StartTurns():
      final play = s.standing;
      if (question == null || play == null || play.started) return _no(s);
      return _ok(_standingMedia(s.copyWith(standing: play.withStarted(true)), question));

    case UndoTurn():
      final play = s.standing;
      // Before the first turn: back to the question alone.
      if (question != null && play != null && play.started && play.turns.isEmpty) {
        return _ok(_standingMedia(s.copyWith(standing: play.withStarted(false)), question));
      }
      if (question == null || play == null || play.turns.isEmpty) return _no(s);
      final back = _standingMedia(s.copyWith(standing: play.withoutLastTurn()), question);
      // A winner that is no longer one gives its points back, and by places
      // so does everyone.
      if (!play.finished) return _ok(back);
      return _ok(_give(play.winner == null ? back : back.copyWith(results: back.results.rated(play.winner!, null)), question));

    case ClearAnswers():
      if (s.answerRound == null) return _no(s);
      return _ok(s.copyWith(answerRound: null));

    // ── on top of the screen ─────────────────────────────────────────────────
    case ShowCard(:final card):
      if (card.isEmpty) return _no(s);
      // A video brings its own sound; nothing else plays over it.
      final video = (card.video ?? '').isNotEmpty;
      return _ok(
        s.copyWith(
          overlay: card,
          media: video && s.media == MediaPlayback.playing ? MediaPlayback.paused : null,
        ),
      );

    case SetCardAnimation(:final animation):
      if (animation == s.cardAnimation) return _no(s);
      return _ok(s.copyWith(cardAnimation: animation));

    case HideCard():
      if (s.overlay == null) return _no(s);
      return _ok(s.copyWith(overlay: null));

    case ScreenEffect(:final name):
      if (!screenEffects.contains(name)) return _no(s);
      return Reduction(s, effects: [VisualEffect(name)]);
  }
}

/// Whether the gamemaster can let [teamId] change its locked-in answer: not
/// once it is on the big screen, and with answering closed only when it
/// closed because every team had locked in (opening it again then lets no
/// one else change theirs).
bool canUnlockAnswer(SessionState s, String teamId) {
  final round = s.answerRound;
  if (round == null || s.team(teamId) == null || !round.takesPart(teamId)) return false;
  if (round.answers[teamId]?.locked != true || round.revealed.contains(teamId)) return false;
  return round.open || s.roundTeams.every((team) => team.id == teamId || round.answers[team.id]?.locked == true);
}

/// The right or wrong sound of [teamId]'s rating, for when its answer comes
/// up on the big screen; null when it is not rated yet.
SoundEffect? _verdictSound(SessionState s, String teamId) => switch (s.results.verdicts[teamId]) {
  true => const SoundEffect(effectAnswerCorrect),
  false => const SoundEffect(effectAnswerWrong),
  null => null,
};

/// Marker for "leave the timer as it is" in a copyWith that may clear it.
const Object _keepTimer = Object();

AnswerRound _newRound(CompanionSpec spec, int? now, {List<String> teams = const [], bool timed = true}) => AnswerRound(
  spec: spec,
  teams: teams,
  openedAtMillis: now,
  endsAtMillis: timed && now != null && spec.timerSeconds != null ? now + spec.timerSeconds! * 1000 : null,
);

/// ABCD with options still to uncover: its time does not run yet, the
/// teams could not know what to pick.
bool _waitsForOptions(Question question, int revealed) =>
    question.type == QuestionType.abcd && question.answers.isNotEmpty && revealed < question.answers.length;

/// The question's clock and its devices' timer, started now unless running.
/// The round counts as opened now: its bar starts full, and "by speed"
/// measures from here.
SessionState _startClocks(SessionState s, Question question, int? now) {
  final round = s.answerRound;
  final seconds = round?.spec.timerSeconds;
  return s.copyWith(
    answerRound: round != null && round.open && now != null
        ? round.copyWith(
            openedAtMillis: now,
            endsAtMillis: round.endsAtMillis == null && seconds != null ? now + seconds * 1000 : _keepTimer,
          )
        : round,
    timer: s.timer ?? _timerFor(question, now),
  );
}

/// [round] with [answer] for [teamId]. Once every team has locked in there is
/// nothing left to wait for, so the round closes.
AnswerRound _withAnswer(SessionState s, AnswerRound round, String teamId, PlayerAnswer answer) {
  final answers = {...round.answers, teamId: answer};
  final everyone = s.roundTeams.every((team) => answers[team.id]?.locked == true);
  return round.copyWith(answers: answers, open: everyone ? false : null, endsAtMillis: everyone ? null : _keepTimer);
}

bool _sameList(List<int> a, List<int> b) => a.length == b.length && Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

/// Showing an answer on the big screen ends the time to change it.
AnswerRound _reveal(AnswerRound round, List<String> revealed) =>
    round.copyWith(revealed: revealed, open: revealed.isEmpty ? null : false, endsAtMillis: revealed.isEmpty ? _keepTimer : null);

/// The clock of [question] started now, if it runs for a set time and the
/// teams' devices have no timer of their own for it.
QuestionTimer? _timerFor(Question question, int? now) {
  final seconds = question.questionTimer;
  return seconds == null || now == null ? null : QuestionTimer(openedAtMillis: now, endsAtMillis: now + seconds * 1000);
}

/// Puts what every team is due for the open question on the scoreboard;
/// see [pointsToGive].
SessionState _give(SessionState s, Question question) {
  final deltas = pointsToGive(s, question);
  if (deltas.isEmpty) return s;
  return s.copyWith(
    teams: [for (final team in s.teams) team.copyWith(points: team.points + (deltas[team.id] ?? 0))],
    results: s.results.copyWith(
      given: {
        for (final team in s.teams)
          if (pointsDue(s, question, team.id) case final due? when due != 0) team.id: due,
      },
    ),
  );
}

/// [s] with [teamId]'s points for the open question on the scoreboard, as
/// rated so far: what it is due less what it was given (a rating taken back
/// takes them back). For an answer rated on the big screen, or shown once
/// rated. A Fragenhagel scores item by item as it moves on instead.
SessionState _giveTeam(SessionState s, Question question, String teamId) {
  if (question.type == QuestionType.rapidFire) return s;
  final due = pointsDue(s, question, teamId);
  final given = s.results.given[teamId] ?? 0;
  final delta = (due ?? 0) - given;
  if (delta == 0) return s;
  return s.copyWith(
    teams: [for (final team in s.teams) team.id == teamId ? team.copyWith(points: team.points + delta) : team],
    results: s.results.copyWith(
      given: {
        for (final entry in s.results.given.entries)
          if (entry.key != teamId) entry.key: entry.value,
        if (due != null && due != 0) teamId: due,
      },
    ),
  );
}

/// [s] with the open question's points given, before it closes: ratings
/// that were made count even when "Give points" was not pressed.
SessionState _givenBeforeClosing(SessionState s, GameContent? game) {
  final question = s.current == null ? null : game?.question(s.current!);
  if (question == null) return s;
  // A Fragenhagel scores item by item. Whiteboards already rated still
  // count when it is closed on its last item.
  if (question.type == QuestionType.rapidFire) {
    return question.rapidFire?.mode == RapidMode.whiteboard ? _scoreRapidItem(s, question) : s;
  }
  return _give(s, question);
}

Reduction _ok(SessionState state, [List<Effect> effects = const []]) => Reduction(state.copyWith(seq: state.seq + 1), effects: effects);

Reduction _no(SessionState state) => Reduction(state, accepted: false);

/// No question open and everything that belonged to one cleared.
SessionState _backToBoard(SessionState s) => s.copyWith(
  phase: Phase.overview,
  current: null,
  buzzQueue: const [],
  revealed: 0,
  imageFocus: 0,
  mediaFullscreen: false,
  feudRevealed: const [],
  foundBy: const {},
  wrongAttempts: 0,
  media: MediaPlayback.stopped,
  answerRound: null,
  betting: null,
  timer: null,
  results: const Results(),
  standing: null,
  rapidSteps: const {},
  notesTeams: const [],
  notes: const {},
);

/// After a wrong answer: the next queued team is up, or the question reopens.
SessionState _nextBuzzer(SessionState s, Question question) {
  if (s.buzzQueue.length > 1) return s.copyWith(buzzQueue: s.buzzQueue.sublist(1));
  return s.copyWith(phase: Phase.question, buzzQueue: const [], media: question.hasMediaAt(s.revealed, s.standing) ? MediaPlayback.playing : null);
}

/// Last team standing after a turn changed: a prompt with its own sound or
/// clip starts it, as a Fragenhagel item does. Without prompts that have
/// one, the question's own sound goes on as it was.
SessionState _standingMedia(SessionState s, Question question) {
  // Each prompt starts at its first picture.
  s = s.copyWith(imageFocus: 0);
  final items = question.lastStanding?.items ?? const <RapidItem>[];
  if (!items.any((item) => item.media.hasSound)) return s;
  final sound = question.hasMediaAt(s.revealed, s.standing);
  return s.copyWith(media: sound ? MediaPlayback.playing : MediaPlayback.stopped);
}

/// A Fragenhagel at item [index]: everyone may answer again, the item's sound
/// plays, and on the devices a fresh round asks it. Before the first item
/// (-1) and after the last nothing is asked.
SessionState _rapidAt(SessionState s, Question question, int index, int? now) {
  final done = index >= question.maxReveal;
  final asking = !done && index >= 0;
  final sound = !done && question.hasMediaAt(index);
  final companion = question.companion;
  return s.copyWith(
    revealed: index,
    // Each item starts at its first picture.
    imageFocus: 0,
    phase: done ? Phase.answerRevealed : Phase.question,
    buzzQueue: const [],
    wrongAttempts: 0,
    media: sound ? MediaPlayback.playing : MediaPlayback.stopped,
    answerRound: companion == null || !asking ? null : _newRound(companion, now),
    // Whiteboard ratings are for one item only.
    results: const Results(),
  );
}

/// Fragenhagel: [delta] points for [teamId] on the item being asked, noted
/// so that going back can take them back.
SessionState _rapidScore(SessionState s, String teamId, int delta) => s.copyWith(
  teams: _addPoints(s.teams, teamId, delta),
  rapidSteps: {...s.rapidSteps, s.revealed: (s.rapidSteps[s.revealed] ?? const RapidStep()).withPoints(teamId, delta)},
);

/// Fragenhagel, one step back to item [index], e.g. after a "next" by
/// mistake: everything scored on that item and after it is taken back, so it
/// can be played again, and on the devices the teams' picks come back.
SessionState _rapidBack(SessionState s, Question question, int index, int? now) {
  var teams = s.teams;
  final kept = <int, RapidStep>{};
  for (final MapEntry(key: item, value: step) in s.rapidSteps.entries) {
    if (item < index) {
      kept[item] = step;
      continue;
    }
    for (final MapEntry(key: teamId, value: delta) in step.points.entries) {
      teams = _addPoints(teams, teamId, -delta);
    }
  }
  final back = _rapidAt(s.copyWith(teams: teams, rapidSteps: kept), question, index, now);
  final step = s.rapidSteps[index] ?? const RapidStep();
  final picks = step.picks;
  final round = back.answerRound;
  if (round == null || (picks.isEmpty && step.drawings.isEmpty)) return back;
  if (question.rapidFire?.mode == RapidMode.whiteboard) {
    // The drawings come back, rated as they were.
    var results = back.results;
    for (final MapEntry(key: teamId, value: pick) in picks.entries) {
      if (back.team(teamId) != null) results = results.rated(teamId, pick == 0);
    }
    return back.copyWith(
      results: results,
      answerRound: round.copyWith(
        answers: {
          for (final MapEntry(key: teamId, value: drawing) in step.drawings.entries)
            if (back.team(teamId) != null) teamId: PlayerAnswer(drawing: drawing),
        },
      ),
    );
  }
  return back.copyWith(
    answerRound: round.copyWith(
      answers: {
        for (final MapEntry(key: teamId, value: choice) in picks.entries)
          if (back.team(teamId) != null) teamId: PlayerAnswer(choice: choice),
      },
    ),
  );
}

/// On the devices, the item being asked is scored: each team that picked
/// gets the question's points for a right pick and loses its minus points
/// for a wrong one. On the whiteboard the gamemaster's ratings count.
SessionState _scoreRapidItem(SessionState s, Question question) {
  final item = question.rapidFire?.itemAt(s.revealed);
  final round = s.answerRound;
  if (item == null || round == null) return s;
  var scored = s;
  if (question.rapidFire?.mode == RapidMode.whiteboard) {
    for (final team in s.teams) {
      final right = s.results.verdicts[team.id];
      final drawing = round.answers[team.id]?.drawing;
      if (right != null) scored = _rapidScore(scored, team.id, right ? question.pointsPlus : -question.pointsMinus);
      // Unrated drawings are kept too, for going back.
      if (right == null && drawing == null) continue;
      final step = scored.rapidSteps[s.revealed] ?? const RapidStep();
      scored = scored.copyWith(rapidSteps: {...scored.rapidSteps, s.revealed: step.withAnswer(team.id, right: right, drawing: drawing)});
    }
    return scored;
  }
  if (question.rapidFire?.mode != RapidMode.devices) return s;
  for (final team in s.teams) {
    final choice = round.answers[team.id]?.choice;
    if (choice == null) continue;
    final right = (choice == 0) == item.isTrue;
    scored = _rapidScore(scored, team.id, right ? question.pointsPlus : -question.pointsMinus);
    final step = scored.rapidSteps[s.revealed]!;
    scored = scored.copyWith(rapidSteps: {...scored.rapidSteps, s.revealed: step.withPick(team.id, choice)});
  }
  return scored;
}

bool _feudAnswering(SessionState s, Question? question) =>
    question?.type == QuestionType.feud && s.phase == Phase.buzzered && s.buzzQueue.isNotEmpty;

List<Team> _addPoints(List<Team> teams, String teamId, int delta) => [
  for (final team in teams) team.id == teamId ? team.copyWith(points: team.points + delta) : team,
];
