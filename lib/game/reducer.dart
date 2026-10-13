/// The rules of the show: `(state, command) -> state`. Pure and synchronous;
/// the host is the only place it runs for real.
library;

import 'commands.dart';
import 'content.dart';
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
  if (ref == null || game?.question(ref)?.buzzerable != true) return false;
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
Reduction reduce(SessionState s, Command command, GameContent? game) {
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
      return _ok(_backToBoard(s).copyWith(
        phase: Phase.question,
        current: ref,
        groupId: game!.groupOfCategory(ref.categoryId)?.id ?? s.groupId,
        played: {...s.played, ?s.current?.key},
      ));

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
      final team = s.buzzQueue.first;
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
        media: question.hasMusic ? MediaPlayback.playing : null,
      ));

    // ── reveals ──────────────────────────────────────────────────────────────
    case Reveal(:final delta):
      if (!questionOpen || question == null || delta == 0) return _no(s);
      final revealed = s.revealed + delta;
      if (revealed < 0 || revealed > question.maxReveal) return _no(s);
      // The enlarged image follows a new reveal and never points past the
      // last revealed one.
      final focus = delta > 0 ? revealed : (s.imageFocus > revealed ? revealed : s.imageFocus);
      return _ok(
        s.copyWith(revealed: revealed, imageFocus: question.type == QuestionType.progressingReveal ? focus : null),
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
        const [SoundEffect(effectReveal)],
      );

    case FeudWrong():
      if (!_feudAnswering(s, question) || s.wrongAttempts >= 3) return _no(s);
      return _ok(s.copyWith(wrongAttempts: s.wrongAttempts + 1), const [SoundEffect(effectAnswerWrong)]);

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

    // ── audio ────────────────────────────────────────────────────────────────
    case SetMedia(:final playback):
      if (playback == s.media) return _no(s);
      if (playback != MediaPlayback.stopped) {
        final listening = s.phase == Phase.question || s.phase == Phase.buzzered;
        if (!listening || question?.hasMusic != true) return _no(s);
      }
      // The question's own sound and the background music never overlap.
      return _ok(s.copyWith(media: playback, music: playback == MediaPlayback.playing ? null : s.music));

    case SetMusic(:final slot):
      if (slot == s.music || (slot != null && !musicSlots.contains(slot))) return _no(s);
      return _ok(s.copyWith(
        music: slot,
        media: slot != null && s.media == MediaPlayback.playing ? MediaPlayback.paused : null,
      ));

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
        answerRound: round?.copyWith(answers: {...round.answers}..remove(teamId)),
      ));

    case SetQueueBuzzers(:final on):
      if (on == s.queueBuzzers) return _no(s);
      return _ok(s.copyWith(queueBuzzers: on));

    // ── answers from player devices ──────────────────────────────────────────
    case OpenAnswers(:final kind):
      if (!questionOpen) return _no(s);
      return _ok(s.copyWith(answerRound: AnswerRound(kind: kind)));

    case SubmitAnswer(:final teamId, :final answer):
      final round = s.answerRound;
      if (round == null || !round.open || s.team(teamId) == null || !answer.matches(round.kind)) return _no(s);
      return _ok(s.copyWith(answerRound: round.copyWith(answers: {...round.answers, teamId: answer})));

    case LockAnswers():
      if (s.answerRound?.open != true) return _no(s);
      return _ok(s.copyWith(answerRound: s.answerRound!.copyWith(open: false)));

    case RevealAnswers():
      final round = s.answerRound;
      if (round == null || round.revealed) return _no(s);
      return _ok(s.copyWith(answerRound: round.copyWith(open: false, revealed: true)));

    case ClearAnswers():
      if (s.answerRound == null) return _no(s);
      return _ok(s.copyWith(answerRound: null));
  }
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
    media: question.hasMusic ? MediaPlayback.playing : null,
  );
}

bool _feudAnswering(SessionState s, Question? question) =>
    question?.type == QuestionType.feud && s.phase == Phase.buzzered && s.buzzQueue.isNotEmpty;

List<Team> _addPoints(List<Team> teams, String teamId, int delta) =>
    [for (final team in teams) team.id == teamId ? team.copyWith(points: team.points + delta) : team];
