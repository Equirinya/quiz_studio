/// Everything anyone can ask the host to do. Controllers, players and buzzer
/// hardware all send these; only the reducer turns them into state.
library;

import 'content.dart';
import 'session_state.dart';

/// Who sent a command. Decides what they may ask for; see [mayIssue].
enum Role {
  /// The presenter device, which owns the state.
  host,

  /// The gamemaster's remote.
  controller,

  /// A player's device, bound to one team.
  player,
}

class Sender {
  const Sender(this.role, {this.teamId});

  const Sender.host() : this(Role.host);

  final Role role;

  /// The team a player device belongs to.
  final String? teamId;
}

/// Players may only buzz and answer, and only for their own team. Whether the
/// game currently accepts that buzz or answer is the reducer's decision.
bool mayIssue(Sender sender, Command command) {
  if (sender.role != Role.player) return true;
  return switch (command) {
    Buzz(:final teamId) || SubmitAnswer(:final teamId) => sender.teamId != null && teamId == sender.teamId,
    _ => false,
  };
}

sealed class Command {
  const Command();

  String get type;

  Map<String, dynamic> get _args => const {};

  Map<String, dynamic> toJson() => {'type': type, ..._args};

  /// Returns null for an unknown or malformed command, which the host drops.
  static Command? fromJson(Map<String, dynamic> json) {
    try {
      return _parse(json);
    } catch (_) {
      return null;
    }
  }

  static Command? _parse(Map<String, dynamic> j) {
    QuestionRef ref() => QuestionRef.tryParse(j['ref'])!;
    return switch (j['type']) {
      'setGame' => SetGame(j['gameId'] as String?),
      'selectGroup' => SelectGroup(j['groupId'] as String),
      'openQuestion' => OpenQuestion(ref()),
      'closeQuestion' => CloseQuestion(markPlayed: j['markPlayed'] != false),
      'unmarkPlayed' => UnmarkPlayed(ref()),
      'setBuzzerTest' => SetBuzzerTest(j['on'] as bool),
      'buzz' => Buzz(j['teamId'] as String),
      'judge' => Judge(correct: j['correct'] as bool),
      'skipBuzzer' => const SkipBuzzer(),
      'reopenQuestion' => const ReopenQuestion(),
      'reveal' => Reveal((j['delta'] as num).toInt()),
      'imageFocus' => ImageFocus((j['delta'] as num).toInt()),
      'feudToggle' => FeudToggle((j['index'] as num).toInt()),
      'feudWrong' => const FeudWrong(),
      'feudSteal' => FeudSteal(success: j['success'] as bool),
      'feudResetWrong' => const FeudResetWrong(),
      'setMedia' => SetMedia(MediaPlayback.values.byName(j['playback'] as String)),
      'setMusic' => SetMusic(j['slot'] as String?),
      'playEffect' => PlayEffect(j['key'] as String),
      'adjustPoints' => AdjustPoints(j['teamId'] as String, (j['delta'] as num).toInt()),
      'setPoints' => SetPoints(j['teamId'] as String, (j['points'] as num).toInt()),
      'addTeam' => AddTeam(j['teamId'] as String, j['name'] as String),
      'renameTeam' => RenameTeam(j['teamId'] as String, j['name'] as String),
      'removeTeam' => RemoveTeam(j['teamId'] as String),
      'setQueueBuzzers' => SetQueueBuzzers(j['on'] as bool),
      'openAnswers' => OpenAnswers(AnswerKind.values.byName(j['kind'] as String)),
      'submitAnswer' =>
        SubmitAnswer(j['teamId'] as String, PlayerAnswer.fromJson(Map<String, dynamic>.from(j['answer'] as Map))),
      'lockAnswers' => const LockAnswers(),
      'revealAnswers' => const RevealAnswers(),
      'clearAnswers' => const ClearAnswers(),
      _ => null,
    };
  }
}

// ── game and board ───────────────────────────────────────────────────────────

/// Loads another game into the session and resets the board.
class SetGame extends Command {
  const SetGame(this.gameId);
  final String? gameId;
  @override
  String get type => 'setGame';
  @override
  Map<String, dynamic> get _args => {'gameId': gameId};
}

class SelectGroup extends Command {
  const SelectGroup(this.groupId);
  final String groupId;
  @override
  String get type => 'selectGroup';
  @override
  Map<String, dynamic> get _args => {'groupId': groupId};
}

class OpenQuestion extends Command {
  const OpenQuestion(this.ref);
  final QuestionRef ref;
  @override
  String get type => 'openQuestion';
  @override
  Map<String, dynamic> get _args => {'ref': ref.key};
}

/// Back to the board. With [markPlayed] false the question stays available,
/// for one that was opened by mistake.
class CloseQuestion extends Command {
  const CloseQuestion({this.markPlayed = true});
  final bool markPlayed;
  @override
  String get type => 'closeQuestion';
  @override
  Map<String, dynamic> get _args => {'markPlayed': markPlayed};
}

class UnmarkPlayed extends Command {
  const UnmarkPlayed(this.ref);
  final QuestionRef ref;
  @override
  String get type => 'unmarkPlayed';
  @override
  Map<String, dynamic> get _args => {'ref': ref.key};
}

// ── buzzing and judging ──────────────────────────────────────────────────────

class SetBuzzerTest extends Command {
  const SetBuzzerTest(this.on);
  final bool on;
  @override
  String get type => 'setBuzzerTest';
  @override
  Map<String, dynamic> get _args => {'on': on};
}

class Buzz extends Command {
  const Buzz(this.teamId);
  final String teamId;
  @override
  String get type => 'buzz';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId};
}

/// Rules on the answer of the first team in the buzz queue.
class Judge extends Command {
  const Judge({required this.correct});
  final bool correct;
  @override
  String get type => 'judge';
  @override
  Map<String, dynamic> get _args => {'correct': correct};
}

/// Drops the answering team without judging; the next in the queue is up.
class SkipBuzzer extends Command {
  const SkipBuzzer();
  @override
  String get type => 'skipBuzzer';
}

/// Clears the buzz queue and lets everyone buzz again.
class ReopenQuestion extends Command {
  const ReopenQuestion();
  @override
  String get type => 'reopenQuestion';
}

// ── reveals ──────────────────────────────────────────────────────────────────

class Reveal extends Command {
  const Reveal(this.delta);
  final int delta;
  @override
  String get type => 'reveal';
  @override
  Map<String, dynamic> get _args => {'delta': delta};
}

class ImageFocus extends Command {
  const ImageFocus(this.delta);
  final int delta;
  @override
  String get type => 'imageFocus';
  @override
  Map<String, dynamic> get _args => {'delta': delta};
}

class FeudToggle extends Command {
  const FeudToggle(this.index);
  final int index;
  @override
  String get type => 'feudToggle';
  @override
  Map<String, dynamic> get _args => {'index': index};
}

/// A strike for the answering team; after the third the other team may steal.
class FeudWrong extends Command {
  const FeudWrong();
  @override
  String get type => 'feudWrong';
}

/// Resolves the steal after three strikes. On success the stealing team gets
/// the points uncovered so far, otherwise the original team keeps them.
class FeudSteal extends Command {
  const FeudSteal({required this.success});
  final bool success;
  @override
  String get type => 'feudSteal';
  @override
  Map<String, dynamic> get _args => {'success': success};
}

class FeudResetWrong extends Command {
  const FeudResetWrong();
  @override
  String get type => 'feudResetWrong';
}

// ── audio ────────────────────────────────────────────────────────────────────

class SetMedia extends Command {
  const SetMedia(this.playback);
  final MediaPlayback playback;
  @override
  String get type => 'setMedia';
  @override
  Map<String, dynamic> get _args => {'playback': playback.name};
}

class SetMusic extends Command {
  const SetMusic(this.slot);

  /// One of `musicSlots`, or null to stop.
  final String? slot;
  @override
  String get type => 'setMusic';
  @override
  Map<String, dynamic> get _args => {'slot': slot};
}

class PlayEffect extends Command {
  const PlayEffect(this.key);
  final String key;
  @override
  String get type => 'playEffect';
  @override
  Map<String, dynamic> get _args => {'key': key};
}

// ── teams and points ─────────────────────────────────────────────────────────

class AdjustPoints extends Command {
  const AdjustPoints(this.teamId, this.delta);
  final String teamId;
  final int delta;
  @override
  String get type => 'adjustPoints';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId, 'delta': delta};
}

class SetPoints extends Command {
  const SetPoints(this.teamId, this.points);
  final String teamId;
  final int points;
  @override
  String get type => 'setPoints';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId, 'points': points};
}

/// The sender picks [teamId], so the reducer stays deterministic.
class AddTeam extends Command {
  const AddTeam(this.teamId, this.name);
  final String teamId;
  final String name;
  @override
  String get type => 'addTeam';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId, 'name': name};
}

class RenameTeam extends Command {
  const RenameTeam(this.teamId, this.name);
  final String teamId;
  final String name;
  @override
  String get type => 'renameTeam';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId, 'name': name};
}

class RemoveTeam extends Command {
  const RemoveTeam(this.teamId);
  final String teamId;
  @override
  String get type => 'removeTeam';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId};
}

class SetQueueBuzzers extends Command {
  const SetQueueBuzzers(this.on);
  final bool on;
  @override
  String get type => 'setQueueBuzzers';
  @override
  Map<String, dynamic> get _args => {'on': on};
}

// ── answers from player devices ──────────────────────────────────────────────

/// Starts collecting answers of [kind] for the open question.
class OpenAnswers extends Command {
  const OpenAnswers(this.kind);
  final AnswerKind kind;
  @override
  String get type => 'openAnswers';
  @override
  Map<String, dynamic> get _args => {'kind': kind.name};
}

class SubmitAnswer extends Command {
  const SubmitAnswer(this.teamId, this.answer);
  final String teamId;
  final PlayerAnswer answer;
  @override
  String get type => 'submitAnswer';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId, 'answer': answer.toJson()};
}

class LockAnswers extends Command {
  const LockAnswers();
  @override
  String get type => 'lockAnswers';
}

class RevealAnswers extends Command {
  const RevealAnswers();
  @override
  String get type => 'revealAnswers';
}

class ClearAnswers extends Command {
  const ClearAnswers();
  @override
  String get type => 'clearAnswers';
}
