/// Everything anyone can ask the host to do. Controllers, players and buzzer
/// hardware all send these; only the reducer turns them into state.
library;

import 'cards.dart';
import 'companion.dart';
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

/// Players may only buzz, answer and lock their answer, and only for their own team. Whether the
/// game currently accepts that buzz or answer is the reducer's decision.
bool mayIssue(Sender sender, Command command) {
  if (sender.role != Role.player) return true;
  return switch (command) {
    Buzz(:final teamId) || SubmitAnswer(:final teamId) || LockAnswer(:final teamId) || GuessConnection(:final teamId) =>
      sender.teamId != null && teamId == sender.teamId,
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
      'setThumbnails' => SetThumbnails(j['on'] as bool),
      'setCardAnimation' => SetCardAnimation(CardAnimation.fromName(j['animation'])),
      'guessConnection' => GuessConnection(j['teamId'] as String, [for (final p in j['positions'] as List) (p as num).toInt()]),
      'awardConnections' => const AwardConnections(),
      'setTeamSound' => SetTeamSound(j['teamId'] as String, j['sound'] as String?),
      'openAnswers' => OpenAnswers(CompanionSpec.fromMap(j['spec'])!),
      'submitAnswer' =>
        SubmitAnswer(j['teamId'] as String, PlayerAnswer.fromJson(Map<String, dynamic>.from(j['answer'] as Map))),
      'lockAnswer' => LockAnswer(j['teamId'] as String),
      'lockAnswers' => const LockAnswers(),
      'unlockAnswers' => const UnlockAnswers(),
      'revealAnswer' => RevealAnswer(j['teamId'] as String, show: j['show'] != false),
      'revealNextAnswer' => const RevealNextAnswer(),
      'revealAnswers' => const RevealAnswers(),
      'rateAnswer' => RateAnswer(j['teamId'] as String, correct: j['correct'] as bool?),
      'awardAnswer' => AwardAnswer(j['teamId'] as String, (j['points'] as num).toInt()),
      'clearAnswers' => const ClearAnswers(),
      'showCard' => ShowCard(OverlayCard.fromJson(Map<String, dynamic>.from(j['card'] as Map))),
      'hideCard' => const HideCard(),
      'screenEffect' => ScreenEffect(j['name'] as String),
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

/// Gives a team its own buzzer sound, a file among the session's files, or
/// takes it away again with null.
class SetTeamSound extends Command {
  const SetTeamSound(this.teamId, this.sound);
  final String teamId;
  final String? sound;
  @override
  String get type => 'setTeamSound';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId, 'sound': sound};
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

/// Shows or hides the row of small pictures under a progressing reveal.
class SetThumbnails extends Command {
  const SetThumbnails(this.on);
  final bool on;
  @override
  String get type => 'setThumbnails';
  @override
  Map<String, dynamic> get _args => {'on': on};
}

// ── answers from the teams' own devices ─────────────────────────────────────

/// Starts collecting answers for the open question on the screen [spec]
/// describes. A question with its own companion screen does this by itself
/// when it is opened.
class OpenAnswers extends Command {
  const OpenAnswers(this.spec);
  final CompanionSpec spec;
  @override
  String get type => 'openAnswers';
  @override
  Map<String, dynamic> get _args => {'spec': spec.toMap()};
}

/// A team's answer as it stands. Sent again whenever it changes, so the
/// gamemaster can watch along.
class SubmitAnswer extends Command {
  const SubmitAnswer(this.teamId, this.answer);
  final String teamId;
  final PlayerAnswer answer;
  @override
  String get type => 'submitAnswer';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId, 'answer': answer.toJson()};
}

/// A team locks its own answer in; it cannot change it afterwards.
class LockAnswer extends Command {
  const LockAnswer(this.teamId);
  final String teamId;
  @override
  String get type => 'lockAnswer';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId};
}

/// Closes the round for everyone. The timer does this when it runs out.
/// Connections: a team says these four words, by their places in the shown
/// order, belong together.
class GuessConnection extends Command {
  const GuessConnection(this.teamId, this.positions);
  final String teamId;
  final List<int> positions;
  @override
  String get type => 'guessConnection';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId, 'positions': positions};
}

/// Connections: every team gets its share of the points for the groups it
/// found. Can be given again after a change; nothing is counted twice.
class AwardConnections extends Command {
  const AwardConnections();
  @override
  String get type => 'awardConnections';
  @override
  Map<String, dynamic> get _args => const {};
}

class LockAnswers extends Command {
  const LockAnswers();
  @override
  String get type => 'lockAnswers';
}

/// Lets every team change its answer again; a timer does not restart.
class UnlockAnswers extends Command {
  const UnlockAnswers();
  @override
  String get type => 'unlockAnswers';
}

/// Puts one team's answer on the big screen, or takes it off again.
class RevealAnswer extends Command {
  const RevealAnswer(this.teamId, {this.show = true});
  final String teamId;
  final bool show;
  @override
  String get type => 'revealAnswer';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId, 'show': show};
}

/// Shows the next team's answer, in team order.
class RevealNextAnswer extends Command {
  const RevealNextAnswer();
  @override
  String get type => 'revealNextAnswer';
}

class RevealAnswers extends Command {
  const RevealAnswers();
  @override
  String get type => 'revealAnswers';
}

/// Rules a team's answer right or wrong and gives or takes the question's
/// points; null withdraws the ruling and its points.
class RateAnswer extends Command {
  const RateAnswer(this.teamId, {required this.correct});
  final String teamId;
  final bool? correct;
  @override
  String get type => 'rateAnswer';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId, 'correct': correct};
}

/// Gives a team a number of points of the gamemaster's choosing for its
/// answer, replacing whatever it got for this round before.
class AwardAnswer extends Command {
  const AwardAnswer(this.teamId, this.points);
  final String teamId;
  final int points;
  @override
  String get type => 'awardAnswer';
  @override
  Map<String, dynamic> get _args => {'teamId': teamId, 'points': points};
}

class ClearAnswers extends Command {
  const ClearAnswers();
  @override
  String get type => 'clearAnswers';
}

// ── on top of the screen ─────────────────────────────────────────────────────

/// Puts a text card or image over whatever the presenter shows.
class ShowCard extends Command {
  const ShowCard(this.card);
  final OverlayCard card;
  @override
  String get type => 'showCard';
  @override
  Map<String, dynamic> get _args => {'card': card.toJson()};
}

/// How cards come on screen from now on, until it is changed again.
class SetCardAnimation extends Command {
  const SetCardAnimation(this.animation);
  final CardAnimation animation;
  @override
  String get type => 'setCardAnimation';
  @override
  Map<String, dynamic> get _args => {'animation': animation.name};
}

class HideCard extends Command {
  const HideCard();
  @override
  String get type => 'hideCard';
}

/// Names of the one-shot animations the presenter can play.
const String screenEffectConfetti = 'confetti';
const String screenEffectFlash = 'flash';
const List<String> screenEffects = [screenEffectConfetti, screenEffectFlash];

/// Plays a one-shot animation over the screen, e.g. confetti.
class ScreenEffect extends Command {
  const ScreenEffect(this.name);
  final String name;
  @override
  String get type => 'screenEffect';
  @override
  Map<String, dynamic> get _args => {'name': name};
}
