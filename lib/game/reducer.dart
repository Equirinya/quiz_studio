/// The rules of the show: `(state, command) -> state`. Pure and synchronous;
/// the host is the only place it runs for real.
library;

import 'commands.dart';
import 'companion.dart';
import 'content.dart';
import 'rapid_fire.dart';
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
  const SoundEffect(this.key);
  final String key;
}

/// A one-shot animation over the whole screen; see `screenEffects`.
class VisualEffect extends Effect {
  const VisualEffect(this.name);
  final String name;
}

class Reduction {
  const Reduction(this.state, {this.effects = const [], this.accepted = true});

  final SessionState state;
  final List<Effect> effects;

  /// False when the command made no sense in the current state and was dropped.
  final bool accepted;
}

/// Whether a buzz by any team would count right now.
bool buzzersOpen(SessionState state, GameContent? game) {
  if (state.phase == Phase.buzzerTest) return true;
  final ref = state.current;
  final question = ref == null ? null : game?.question(ref);
  if (question == null || !question.buzzerable) return false;
  // A Fragenhagel whose last item is done has nothing left to buzz for.
  if (question.type == QuestionType.rapidFire && state.revealed >= question.maxReveal) return false;
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
Reduction reduce(SessionState s, Command command, GameContent? game, {int? now}) {
  final question = s.current == null ? null : game?.question(s.current!);
  final questionOpen =
      s.current != null && (s.phase == Phase.question || s.phase == Phase.buzzered || s.phase == Phase.answerRevealed);

  switch (command) {
    // ── game and board ───────────────────────────────────────────────────────
    case SetGame(:final gameId):
      return _ok(_backToBoard(s).copyWith(gameId: gameId, groupId: null, played: const {}, music: null));

    case SelectGroup(:final groupId):
      if (s.current != null) return _no(s);
      if (game != null && game.group(groupId) == null) return _no(s);
      return _ok(s.copyWith(groupId: groupId));

    case OpenQuestion(:final ref):
      if (s.phase == Phase.buzzerTest || game?.question(ref) == null) return _no(s);
      final opened = game!.question(ref)!;
      final companion = opened.companion;
      final next = _backToBoard(s).copyWith(
        phase: Phase.question,
        current: ref,
        groupId: game.groupOfCategory(ref.categoryId)?.id ?? s.groupId,
        played: {...s.played, ?s.current?.key},
        // A question with a companion screen puts it on the teams' devices
        // the moment it opens.
        answerRound: companion == null ? null : _newRound(companion, now),
      );
      // A Fragenhagel starts with its first item, sound and all.
      return _ok(opened.type == QuestionType.rapidFire ? _rapidAt(next, opened, 0, now) : next, const [SoundEffect(effectQuestionOpen)]);

    case CloseQuestion(:final markPlayed):
      if (s.current == null) return _no(s);
      return _ok(
        _backToBoard(s).copyWith(played: markPlayed ? {...s.played, s.current!.key} : null),
        [if (markPlayed) const SoundEffect(effectAnswerClosed)],
      );

    case UnmarkPlayed(:final ref):
      if (!s.played.contains(ref.key)) return _no(s);
      return _ok(s.copyWith(played: {...s.played}..remove(ref.key)));

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
          music: null,
        ),
        sound,
      );

    case Judge(:final correct):
      if (s.phase != Phase.buzzered || s.buzzQueue.isEmpty || question == null || !question.defaultJudging) return _no(s);
      // Top answers: right means tapping the answer the team named.
      if (correct && question.type == QuestionType.topAnswers) return _no(s);
      final team = s.buzzQueue.first;
      if (correct && question.type == QuestionType.rapidFire) {
        // Right: the points, and straight on to the next item.
        final finished = s.revealed + 1 >= question.maxReveal;
        return _ok(
          _rapidAt(s.copyWith(teams: _addPoints(s.teams, team, question.pointsPlus)), question, s.revealed + 1, now),
          [const SoundEffect(effectAnswerCorrect), if (finished) const SoundEffect(effectFanfare)],
        );
      }
      if (correct) {
        return _ok(
          _backToBoard(s).copyWith(
            teams: _addPoints(s.teams, team, question.pointsPlus),
            played: {...s.played, s.current!.key},
          ),
          const [SoundEffect(effectAnswerCorrect)],
        );
      }
      return _ok(
        _nextBuzzer(s, question).copyWith(teams: _addPoints(s.teams, team, -question.pointsMinus)),
        const [SoundEffect(effectAnswerWrong)],
      );

    case SkipBuzzer():
      if (s.phase != Phase.buzzered || s.buzzQueue.length < 2) return _no(s);
      return _ok(s.copyWith(buzzQueue: s.buzzQueue.sublist(1)));

    case ReopenQuestion():
      if (s.phase != Phase.buzzered || question == null) return _no(s);
      return _ok(s.copyWith(
        phase: Phase.question,
        buzzQueue: const [],
        wrongAttempts: 0,
        media: question.musicAt(s.revealed) != null ? MediaPlayback.playing : null,
      ));

    // ── reveals ──────────────────────────────────────────────────────────────
    case Reveal(:final delta):
      if (!questionOpen || question == null || delta == 0) return _no(s);
      final revealed = s.revealed + delta;
      if (revealed < 0 || revealed > question.maxReveal) return _no(s);
      if (question.type == QuestionType.rapidFire) {
        final devices = question.rapidFire?.mode == RapidMode.devices;
        // Points for an item on the devices are given when moving on, so
        // going back would count them twice.
        if (devices && delta < 0) return _no(s);
        final scored = devices ? _scoreRapidItem(s, question) : s;
        final finished = revealed >= question.maxReveal;
        return _ok(_rapidAt(scored, question, revealed, now), [
          if (delta > 0) SoundEffect(finished ? effectFanfare : effectNextItem),
        ]);
      }
      // The enlarged image follows a new reveal and never points past the
      // last revealed one.
      final focus = delta > 0 ? revealed : (s.imageFocus > revealed ? revealed : s.imageFocus);
      // Teams keep playing while groups come up; their time runs on.
      return _ok(
        s.copyWith(revealed: revealed, imageFocus: question.type == QuestionType.progressingReveal ? focus : null),
        [if (question.type == QuestionType.connections && delta > 0) const SoundEffect(effectReveal)],
      );

    case ImageFocus(:final delta):
      if (!questionOpen || question?.type != QuestionType.progressingReveal || delta == 0) return _no(s);
      final focus = s.imageFocus + delta;
      if (focus < 0 || focus > s.revealed) return _no(s);
      return _ok(s.copyWith(imageFocus: focus));

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
        return _ok(s.copyWith(
          feudRevealed: [...s.feudRevealed]..remove(index),
          foundBy: {...s.foundBy}..remove(index),
          teams: finder == null ? null : _addPoints(s.teams, finder, -top.pointsOf(index, question!.pointsPlus)),
          phase: s.phase == Phase.answerRevealed ? Phase.question : null,
        ));
      }
      final revealed = [...s.feudRevealed, index];
      final all = revealed.length >= top.items.length;
      final answering = !top.onDevices && s.phase == Phase.buzzered && s.buzzQueue.isNotEmpty ? s.buzzQueue.first : null;
      if (answering == null) {
        return _ok(
          s.copyWith(feudRevealed: revealed, phase: all && !top.onDevices ? Phase.answerRevealed : null),
          [SoundEffect(all ? effectFanfare : effectReveal)],
        );
      }
      // The answering team named it: its points, and the others may buzz again.
      final next = s.copyWith(
        feudRevealed: revealed,
        foundBy: {...s.foundBy, index: answering},
        teams: _addPoints(s.teams, answering, top.pointsOf(index, question!.pointsPlus)),
        buzzQueue: const [],
        phase: all ? Phase.answerRevealed : Phase.question,
        media: !all && question.musicAt(s.revealed) != null ? MediaPlayback.playing : null,
      );
      return _ok(next, [const SoundEffect(effectAnswerCorrect), if (all) const SoundEffect(effectFanfare)]);

    case MarkTopAnswers(:final teamId, :final found):
      final top = question?.topAnswers;
      final round = s.answerRound;
      if (round == null || top == null || s.team(teamId) == null) return _no(s);
      final indices = {for (final i in found) if (i >= 0 && i < top.items.length) i}.toList()..sort();
      final before = [...?round.found[teamId]]..sort();
      if (_sameList(indices, before) && round.awarded.containsKey(teamId)) return _no(s);
      final points = top.pointsFor(indices, question!.pointsPlus);
      final marked = round.copyWith(found: {...round.found, teamId: indices});
      return _ok(_award(s, marked, teamId, points, verdict: indices.isNotEmpty));

    // ── audio ────────────────────────────────────────────────────────────────
    case SetMedia(:final playback):
      if (playback == s.media) return _no(s);
      if (playback != MediaPlayback.stopped) {
        final listening = s.phase == Phase.question || s.phase == Phase.buzzered;
        if (!listening || question?.musicAt(s.revealed) == null) return _no(s);
      }
      // The question's own sound and the background music never overlap.
      return _ok(s.copyWith(media: playback, music: playback == MediaPlayback.playing ? null : s.music));

    case SetMusic(:final slot):
      if (slot == s.music || (slot != null && !musicSlots.contains(slot))) return _no(s);
      return _ok(s.copyWith(
        music: slot,
        media: slot != null && s.media == MediaPlayback.playing ? MediaPlayback.paused : null,
      ));

    case SetAmbience(:final slot):
      if (slot == s.ambience || (slot != null && !ambienceAssets.containsKey(slot))) return _no(s);
      return _ok(s.copyWith(ambience: slot));

    case SetMusicVolume(:final volume):
      final clamped = volume.clamp(0, 100);
      if (clamped == s.musicVolume) return _no(s);
      return _ok(s.copyWith(musicVolume: clamped));

    case PlayEffect(:final key):
      return Reduction(s, effects: [SoundEffect(key)]);

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
      return _ok(s.copyWith(teams: [...s.teams, Team(id: teamId, name: trimmed)]));

    case RenameTeam(:final teamId, :final name):
      final trimmed = name.trim();
      if (s.team(teamId) == null || trimmed.isEmpty || s.teams.any((team) => team.name == trimmed)) return _no(s);
      return _ok(s.copyWith(teams: [for (final team in s.teams) team.id == teamId ? team.copyWith(name: trimmed) : team]));

    case RemoveTeam(:final teamId):
      if (s.team(teamId) == null) return _no(s);
      final queue = s.buzzQueue.where((id) => id != teamId).toList();
      final round = s.answerRound;
      return _ok(s.copyWith(
        teams: s.teams.where((team) => team.id != teamId).toList(),
        buzzQueue: queue,
        // Nobody is left to answer: let the others buzz again.
        phase: s.phase == Phase.buzzered && queue.isEmpty ? Phase.question : null,
        answerRound: round?.copyWith(
          answers: {...round.answers}..remove(teamId),
          revealed: [...round.revealed]..remove(teamId),
          verdicts: {...round.verdicts}..remove(teamId),
          awarded: {...round.awarded}..remove(teamId),
          found: {...round.found}..remove(teamId),
        ),
        foundBy: {for (final entry in s.foundBy.entries) if (entry.value != teamId) entry.key: entry.value},
      ));

    case SetTeamSound(:final teamId, :final sound):
      final name = sound == null || sound.isEmpty ? null : sound;
      if (s.team(teamId) == null || s.team(teamId)!.sound == name) return _no(s);
      return _ok(s.copyWith(teams: [for (final team in s.teams) team.id == teamId ? team.withSound(name) : team]));

    case SetQueueBuzzers(:final on):
      if (on == s.queueBuzzers) return _no(s);
      return _ok(s.copyWith(queueBuzzers: on));

    // ── answers from the teams' own devices ─────────────────────────────────
    case OpenAnswers(:final spec):
      if (!questionOpen) return _no(s);
      return _ok(s.copyWith(answerRound: _newRound(spec, now)));

    case SubmitAnswer(:final teamId, :final answer):
      final round = s.answerRound;
      if (round == null || !round.open || s.team(teamId) == null || !answer.matches(round.kind)) return _no(s);
      if (round.answers[teamId]?.locked == true) return _no(s);
      return _ok(s.copyWith(answerRound: round.copyWith(answers: {...round.answers, teamId: answer.asLocked(false)})));

    case LockAnswer(:final teamId):
      final round = s.answerRound;
      if (round == null || !round.open || !round.spec.lockable || s.team(teamId) == null) return _no(s);
      if (round.answers[teamId]?.locked == true) return _no(s);
      return _ok(
        s.copyWith(
          answerRound: _withAnswer(s, round, teamId, (round.answers[teamId] ?? const PlayerAnswer()).asLocked(true, atMillis: now)),
        ),
        const [SoundEffect(effectLockIn)],
      );

    case GuessConnection(:final teamId, :final positions):
      final round = s.answerRound;
      if (round == null || !round.open || round.kind != CompanionKind.connections || s.team(teamId) == null) return _no(s);
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
      var next = s;
      var changed = false;
      for (final team in s.teams) {
        final points = connectionsPoints(question.pointsPlus, round.answers[team.id]?.connections);
        final current = next.answerRound!;
        if (current.awarded.containsKey(team.id) && current.awarded[team.id] == points) continue;
        next = _award(next, current, team.id, points, verdict: points > 0);
        changed = true;
      }
      return changed ? _ok(next, const [SoundEffect(effectAnswerCorrect)]) : _no(s);

    case LockAnswers():
      if (s.answerRound?.open != true) return _no(s);
      return _ok(s.copyWith(answerRound: s.answerRound!.copyWith(open: false, endsAtMillis: null)));

    case UnlockAnswers():
      final round = s.answerRound;
      if (round == null) return _no(s);
      return _ok(s.copyWith(
        answerRound: round.copyWith(
          open: true,
          endsAtMillis: null,
          answers: {for (final entry in round.answers.entries) entry.key: entry.value.asLocked(false)},
        ),
      ));

    case RevealAnswer(:final teamId, :final show):
      final round = s.answerRound;
      if (round == null || s.team(teamId) == null || round.revealed.contains(teamId) == show) return _no(s);
      return _ok(s.copyWith(answerRound: _reveal(round, show ? [...round.revealed, teamId] : ([...round.revealed]..remove(teamId)))));

    case RevealNextAnswer():
      final round = s.answerRound;
      final next = s.teams.where((team) => round != null && !round.revealed.contains(team.id)).firstOrNull;
      if (round == null || next == null) return _no(s);
      return _ok(s.copyWith(answerRound: _reveal(round, [...round.revealed, next.id])));

    case RevealAnswers():
      final round = s.answerRound;
      if (round == null || s.teams.every((team) => round.revealed.contains(team.id))) return _no(s);
      return _ok(s.copyWith(
        answerRound: _reveal(round, [
          ...round.revealed,
          for (final team in s.teams)
            if (!round.revealed.contains(team.id)) team.id,
        ]),
      ));

    case RateAnswer(:final teamId, :final correct):
      final round = s.answerRound;
      if (round == null || question == null || s.team(teamId) == null) return _no(s);
      final points = correct == null ? 0 : (correct ? question.pointsPlus : -question.pointsMinus);
      if (round.verdicts[teamId] == correct && (round.awarded[teamId] ?? 0) == points) return _no(s);
      return _ok(
        _award(s, round, teamId, points, verdict: correct),
        [if (correct != null) SoundEffect(correct ? effectAnswerCorrect : effectAnswerWrong)],
      );

    case AwardAnswer(:final teamId, :final points):
      final round = s.answerRound;
      if (round == null || s.team(teamId) == null) return _no(s);
      return _ok(_award(s, round, teamId, points, verdict: points > 0));

    case ClearAnswers():
      if (s.answerRound == null) return _no(s);
      return _ok(s.copyWith(answerRound: null));

    // ── on top of the screen ─────────────────────────────────────────────────
    case ShowCard(:final card):
      if (card.isEmpty) return _no(s);
      // A video brings its own sound; nothing else plays over it.
      final video = (card.video ?? '').isNotEmpty;
      return _ok(s.copyWith(
        overlay: card,
        music: video ? null : _keepTimer,
        media: video && s.media == MediaPlayback.playing ? MediaPlayback.paused : null,
      ));

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

/// Marker for "leave the timer as it is" in a copyWith that may clear it.
const Object _keepTimer = Object();

AnswerRound _newRound(CompanionSpec spec, int? now) => AnswerRound(
      spec: spec,
      openedAtMillis: now,
      endsAtMillis: now != null && spec.timerSeconds != null ? now + spec.timerSeconds! * 1000 : null,
    );

/// [round] with [answer] for [teamId]. Once every team has locked in there is
/// nothing left to wait for, so the round closes.
AnswerRound _withAnswer(SessionState s, AnswerRound round, String teamId, PlayerAnswer answer) {
  final answers = {...round.answers, teamId: answer};
  final everyone = s.teams.every((team) => answers[team.id]?.locked == true);
  return round.copyWith(answers: answers, open: everyone ? false : null, endsAtMillis: everyone ? null : _keepTimer);
}

bool _sameList(List<int> a, List<int> b) => a.length == b.length && Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

/// Showing an answer on the big screen ends the time to change it.
AnswerRound _reveal(AnswerRound round, List<String> revealed) =>
    round.copyWith(revealed: revealed, open: revealed.isEmpty ? null : false, endsAtMillis: revealed.isEmpty ? _keepTimer : null);

/// Gives [teamId] exactly [points] for this round, taking back whatever it
/// had been given for it before.
SessionState _award(SessionState s, AnswerRound round, String teamId, int points, {required bool? verdict}) {
  final before = round.awarded[teamId] ?? 0;
  return s.copyWith(
    teams: _addPoints(s.teams, teamId, points - before),
    answerRound: round.copyWith(
      verdicts: verdict == null ? ({...round.verdicts}..remove(teamId)) : {...round.verdicts, teamId: verdict},
      awarded: verdict == null ? ({...round.awarded}..remove(teamId)) : {...round.awarded, teamId: points},
    ),
  );
}

Reduction _ok(SessionState state, [List<Effect> effects = const []]) =>
    Reduction(state.copyWith(seq: state.seq + 1), effects: effects);

Reduction _no(SessionState state) => Reduction(state, accepted: false);

/// No question open and everything that belonged to one cleared.
SessionState _backToBoard(SessionState s) => s.copyWith(
      phase: Phase.overview,
      current: null,
      buzzQueue: const [],
      revealed: 0,
      imageFocus: 0,
      feudRevealed: const [],
      foundBy: const {},
      wrongAttempts: 0,
      media: MediaPlayback.stopped,
      answerRound: null,
    );

/// After a wrong answer: the next queued team is up, or the question reopens.
SessionState _nextBuzzer(SessionState s, Question question) {
  if (s.buzzQueue.length > 1) return s.copyWith(buzzQueue: s.buzzQueue.sublist(1));
  return s.copyWith(
    phase: Phase.question,
    buzzQueue: const [],
    media: question.musicAt(s.revealed) != null ? MediaPlayback.playing : null,
  );
}

/// A Fragenhagel at item [index]: everyone may answer again, the item's sound
/// plays, and on the devices a fresh round asks it. At the end nothing is
/// asked any more.
SessionState _rapidAt(SessionState s, Question question, int index, int? now) {
  final done = index >= question.maxReveal;
  final music = done ? null : question.musicAt(index);
  final companion = question.companion;
  return s.copyWith(
    revealed: index,
    phase: done ? Phase.answerRevealed : Phase.question,
    buzzQueue: const [],
    wrongAttempts: 0,
    media: music == null ? MediaPlayback.stopped : MediaPlayback.playing,
    music: music == null ? _keepTimer : null,
    answerRound: companion == null || done ? null : _newRound(companion, now),
  );
}

/// Devices mode: the item being asked is scored, each team that picked gets
/// the question's points for a right pick and loses its minus points for a
/// wrong one.
SessionState _scoreRapidItem(SessionState s, Question question) {
  final item = question.rapidFire?.itemAt(s.revealed);
  final round = s.answerRound;
  if (item == null || round == null) return s;
  var teams = s.teams;
  for (final team in s.teams) {
    final choice = round.answers[team.id]?.choice;
    if (choice == null) continue;
    final right = (choice == 0) == item.isTrue;
    teams = _addPoints(teams, team.id, right ? question.pointsPlus : -question.pointsMinus);
  }
  return s.copyWith(teams: teams);
}

bool _feudAnswering(SessionState s, Question? question) =>
    question?.type == QuestionType.feud && s.phase == Phase.buzzered && s.buzzQueue.isNotEmpty;

List<Team> _addPoints(List<Team> teams, String teamId, int delta) =>
    [for (final team in teams) team.id == teamId ? team.copyWith(points: team.points + delta) : team];
