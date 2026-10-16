/// Companion screens: what the teams' own devices show while a question is
/// open, and the answers they send back. Plain Dart, JSON-serialisable.
library;

import 'dart:math';

/// The kinds of input a team's device can offer.
enum CompanionKind {
  whiteboard("Whiteboard"),
  text("Text"),
  number("Number"),
  slider("Slider"),
  choice("Pick one"),
  order("Put in order"),
  match("Match pairs"),
  connections("Connections");

  const CompanionKind(this.uiString);

  final String uiString;

  static CompanionKind? fromName(Object? name) => CompanionKind.values.where((k) => k.name == name).firstOrNull;
}

/// Connections: sixteen words in four groups of four, from the easiest
/// group (level 0, yellow) to the hardest (level 3, purple).
const int kConnectionsGroups = 4;
const int kConnectionsGroupSize = 4;
const int kConnectionsWords = kConnectionsGroups * kConnectionsGroupSize;

/// One group of a Connections puzzle: what the four words have in common.
class ConnectionGroup {
  const ConnectionGroup({this.name = '', this.words = const ['', '', '', '']});

  final String name;

  /// Always four entries, possibly empty while the puzzle is being written.
  final List<String> words;

  bool get isComplete => name.trim().isNotEmpty && words.length == kConnectionsGroupSize && words.every((w) => w.trim().isNotEmpty);

  static ConnectionGroup fromMap(Object? stored) {
    if (stored is! Map) return const ConnectionGroup();
    final words = _strings(stored['words']);
    return ConnectionGroup(
      name: stored['name'] is String ? stored['name'] as String : '',
      words: [for (var i = 0; i < kConnectionsGroupSize; i++) i < words.length ? words[i] : ''],
    );
  }

  /// Always four groups, padded with empty ones.
  static List<ConnectionGroup> listFrom(Object? stored) {
    final list = stored is List ? stored : const [];
    return [for (var i = 0; i < kConnectionsGroups; i++) fromMap(i < list.length ? list[i] : null)];
  }

  Map<String, dynamic> toMap() => {'name': name, 'words': words};
}

/// A hash of [text] that is the same in every run and on every device, unlike
/// [String.hashCode]: a restarted presenter must lay the words out as before.
int stableHash(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// The order the sixteen words are shown in, as original indices (group
/// level × 4 + position in the group). Devices answer with positions in this
/// order, so they never learn which words belong together.
List<int> connectionsOrder(String seed) {
  final order = List<int>.generate(kConnectionsWords, (i) => i);
  final random = Random(stableHash('connections|$seed'));
  // A layout that leaves a whole group in one row gives it away.
  for (var attempt = 0; attempt < 20; attempt++) {
    order.shuffle(random);
    final rowGivesAway = Iterable<int>.generate(kConnectionsGroups).any((row) {
      final levels = {for (var c = 0; c < kConnectionsGroupSize; c++) order[row * kConnectionsGroupSize + c] ~/ kConnectionsGroupSize};
      return levels.length == 1;
    });
    if (!rowGivesAway) break;
  }
  return order;
}

/// What lies behind the ink on a whiteboard.
const List<String> whiteboardBackgrounds = ['blank', 'lines', 'grid', 'list', 'image'];

double? _num(Object? v) => v is num ? v.toDouble() : null;

List<String> _strings(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is String) e,
    ];

/// How a companion screen is set up for one question. Stored on the question
/// document as `companion`; the same shape travels in the session state.
///
///   kind:        one of [CompanionKind]
///   timer:       seconds until answers lock by themselves; absent = no timer
///   background, listRows:   whiteboard: "blank" | "lines" | "grid" | "list" | "image"
///   backgroundImage:        whiteboard with "image": a media file of the game
///                           to draw on, e.g. a map to mark or a form to fill
///   min, max, step, unit:   number and slider
///   solution:    number and slider: the right value, for the gamemaster
///   options:     choice: what to pick from · order: the items, in the RIGHT
///                order · match: the left-hand items
///   targets:     match: the right-hand items, aligned with `options`
///   lock:        whether teams may lock their answer in before the time is
///                up, which records when they did; absent = true
///   mistakes:    connections: wrong guesses a team may make (default 3)
///   groups:      connections: the four groups, easiest first. On the
///                question they are stored as `connections`; see
///                [Question.companion].
class CompanionSpec {
  const CompanionSpec({
    required this.kind,
    this.timerSeconds,
    this.background = 'blank',
    this.backgroundImage,
    this.listRows = 5,
    this.min,
    this.max,
    this.step,
    this.unit,
    this.solution,
    this.options = const [],
    this.targets = const [],
    this.lockable = true,
    this.mistakes = 3,
    this.groups = const [],
  });

  final CompanionKind kind;
  final int? timerSeconds;
  final String background;
  final String? backgroundImage;
  final int listRows;
  final double? min;
  final double? max;
  final double? step;
  final String? unit;
  final double? solution;
  final List<String> options;
  final List<String> targets;
  final bool lockable;
  final int mistakes;
  final List<ConnectionGroup> groups;

  static CompanionSpec? fromMap(Object? stored) {
    if (stored is! Map) return null;
    final kind = CompanionKind.fromName(stored['kind']);
    if (kind == null) return null;
    final timer = _num(stored['timer'])?.round();
    final image = stored['backgroundImage'] is String && (stored['backgroundImage'] as String).isNotEmpty
        ? stored['backgroundImage'] as String
        : null;
    // "image" without a picture is just a blank board.
    final background = stored['background'] == 'image' && image == null ? 'blank' : stored['background'];
    return CompanionSpec(
      kind: kind,
      timerSeconds: timer != null && timer > 0 ? timer : null,
      background: whiteboardBackgrounds.contains(background) ? background as String : 'blank',
      backgroundImage: background == 'image' ? image : null,
      listRows: (_num(stored['listRows'])?.round() ?? 5).clamp(1, 20),
      min: _num(stored['min']),
      max: _num(stored['max']),
      step: _num(stored['step']),
      unit: stored['unit'] is String && (stored['unit'] as String).isNotEmpty ? stored['unit'] as String : null,
      solution: _num(stored['solution']),
      options: _strings(stored['options']),
      targets: _strings(stored['targets']),
      lockable: stored['lock'] != false,
      mistakes: (_num(stored['mistakes'])?.round() ?? 3).clamp(1, 10),
      groups: kind == CompanionKind.connections ? ConnectionGroup.listFrom(stored['groups']) : const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        if (timerSeconds != null) 'timer': timerSeconds,
        if (kind == CompanionKind.whiteboard) 'background': background,
        if (kind == CompanionKind.whiteboard && backgroundImage != null) 'backgroundImage': backgroundImage,
        if (kind == CompanionKind.whiteboard && background == 'list') 'listRows': listRows,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (step != null) 'step': step,
        if (unit != null) 'unit': unit,
        if (solution != null) 'solution': solution,
        if (options.isNotEmpty) 'options': options,
        if (targets.isNotEmpty) 'targets': targets,
        if (!lockable) 'lock': false,
        if (kind == CompanionKind.connections) 'mistakes': mistakes,
        if (kind == CompanionKind.connections && groups.isNotEmpty) 'groups': [for (final group in groups) group.toMap()],
      };

  /// The same screen with the groups of a Connections question.
  CompanionSpec withGroups(List<ConnectionGroup> groups) => CompanionSpec(
        kind: kind,
        timerSeconds: timerSeconds,
        lockable: lockable,
        mistakes: mistakes,
        groups: groups,
      );

  CompanionSpec withOptions(List<String> options) => CompanionSpec(
        kind: kind,
        timerSeconds: timerSeconds,
        background: background,
        backgroundImage: backgroundImage,
        listRows: listRows,
        min: min,
        max: max,
        step: step,
        unit: unit,
        solution: solution,
        options: options,
        targets: targets,
        lockable: lockable,
        mistakes: mistakes,
        groups: groups,
      );

  /// The slider's range, with defaults where the editor left a gap.
  ({double min, double max, double step}) get range {
    final low = min ?? 0;
    final high = max != null && max! > low ? max! : low + 100;
    final by = step != null && step! > 0 ? step! : 1.0;
    return (min: low, max: high, step: by);
  }

  /// The word at an original index (group level × 4 + place in the group).
  String _wordAt(int index) {
    final group = index ~/ kConnectionsGroupSize;
    if (group >= groups.length) return '';
    final words = groups[group].words;
    final place = index % kConnectionsGroupSize;
    return place < words.length ? words[place] : '';
  }

  String wordAt(int index) => _wordAt(index);

  /// What a team's device may know: no solution, and the items of "put in
  /// order" and the right-hand side of "match pairs" shuffled. Each shuffled
  /// item keeps its original index, which is what the device answers with.
  Map<String, dynamic> toPublicMap(String seed) {
    List<Map<String, dynamic>> shuffled(List<String> items, String salt) {
      final indexed = [for (final (i, text) in items.indexed) {'i': i, 't': text}];
      if (indexed.length < 2) return indexed;
      final random = Random(Object.hash(seed, salt));
      final original = [...indexed];
      // A shuffle that happens to come out in the right order would give
      // the answer away, so that one result is not accepted.
      for (var attempt = 0; attempt < 8; attempt++) {
        indexed.shuffle(random);
        if (Iterable<int>.generate(indexed.length).any((i) => indexed[i]['i'] != original[i]['i'])) break;
      }
      return indexed;
    }

    final order = kind == CompanionKind.connections ? connectionsOrder(seed) : const <int>[];
    return {
      'kind': kind.name,
      if (timerSeconds != null) 'timer': timerSeconds,
      'lock': lockable,
      if (kind == CompanionKind.connections) 'mistakes': mistakes,
      // In the shown order. The groups come along so a device can tell a
      // team at once whether a guess is right: speed matters more during a
      // show than keeping the answer from someone who digs through the app.
      if (kind == CompanionKind.connections) ...{
        'words': [for (final index in order) _wordAt(index)],
        'groups': [
          for (var level = 0; level < groups.length; level++)
            {
              'name': groups[level].name,
              'positions': [for (var i = 0; i < kConnectionsGroupSize; i++) order.indexOf(level * kConnectionsGroupSize + i)],
            },
        ],
      },
      if (kind == CompanionKind.whiteboard) 'background': background,
      // Only the name; the picture itself reaches the device separately.
      if (kind == CompanionKind.whiteboard && backgroundImage != null) 'backgroundImage': backgroundImage,
      if (kind == CompanionKind.whiteboard && background == 'list') 'listRows': listRows,
      if (min != null) 'min': min,
      if (max != null) 'max': max,
      if (step != null) 'step': step,
      if (unit != null) 'unit': unit,
      if (kind == CompanionKind.choice) 'options': options,
      if (kind == CompanionKind.order) 'items': shuffled(options, 'order'),
      if (kind == CompanionKind.match) 'options': options,
      if (kind == CompanionKind.match) 'items': shuffled(targets, 'match'),
    };
  }
}

/// A team's way through a Connections puzzle. Words are original indices
/// (see [connectionsOrder]).
class ConnectionsProgress {
  const ConnectionsProgress({this.solved = const [], this.wrong = const [], this.oneAway = const []});

  /// Group levels in the order the team found them.
  final List<int> solved;

  /// Wrong guesses, each sorted; a guess is never counted twice.
  final List<List<int>> wrong;

  /// Per wrong guess: three of the four words belonged together.
  final List<bool> oneAway;

  int get mistakes => wrong.length;

  bool finished(CompanionSpec spec) => solved.length == kConnectionsGroups || mistakes >= spec.mistakes;

  Map<String, dynamic> toJson() => {'solved': solved, 'wrong': wrong, 'oneAway': oneAway};

  factory ConnectionsProgress.fromJson(Map<String, dynamic> json) => ConnectionsProgress(
        solved: [for (final e in json['solved'] as List? ?? const []) (e as num).toInt()],
        wrong: [
          for (final guess in json['wrong'] as List? ?? const []) [for (final e in guess as List) (e as num).toInt()],
        ],
        oneAway: [for (final e in json['oneAway'] as List? ?? const []) e == true],
      );
}

/// Points for a Connections round: the question's value shared out over the
/// four groups.
int connectionsPoints(int pointsPlus, ConnectionsProgress? progress) =>
    progress == null ? 0 : (pointsPlus * progress.solved.length / kConnectionsGroups).round();

/// One team's answer. Exactly the field matching the round's kind is set.
class PlayerAnswer {
  const PlayerAnswer({
    this.text,
    this.number,
    this.choice,
    this.order,
    this.pairs,
    this.drawing,
    this.connections,
    this.locked = false,
    this.lockedAtMillis,
  });

  final String? text;
  final double? number;

  /// Index into the options.
  final int? choice;

  /// "Put in order": original indices of the items, in the team's order.
  final List<int>? order;

  /// "Match pairs": for each left-hand item, the original index of the
  /// right-hand item assigned to it; -1 where nothing is assigned.
  final List<int>? pairs;

  /// Encoded strokes; see drawing.dart.
  final String? drawing;

  /// Connections only; built by the host from the team's guesses, never sent
  /// by a device.
  final ConnectionsProgress? connections;

  /// The team has locked this answer in and can no longer change it.
  final bool locked;

  /// When the team locked in, on the host's clock; null when the round ended
  /// before they did.
  final int? lockedAtMillis;

  bool get isEmpty =>
      text == null && number == null && choice == null && order == null && pairs == null && drawing == null && connections == null;

  /// Seconds from the start of [round] until the team locked in.
  double? secondsTaken(AnswerRound round) => lockedAtMillis == null || round.openedAtMillis == null
      ? null
      : (lockedAtMillis! - round.openedAtMillis!) / 1000;

  /// Whether a device may send this as its answer to a round of [kind].
  bool matches(CompanionKind kind) {
    if (connections != null) return false;
    final set = [text, number, choice, order, pairs, drawing].where((v) => v != null).length;
    if (set != 1) return false;
    return switch (kind) {
      CompanionKind.whiteboard => drawing != null,
      CompanionKind.text => text != null,
      CompanionKind.number || CompanionKind.slider => number != null,
      CompanionKind.choice => choice != null,
      CompanionKind.order => order != null,
      CompanionKind.match => pairs != null,
      CompanionKind.connections => false,
    };
  }

  /// Locked in at [atMillis], or unlocked again.
  PlayerAnswer asLocked(bool locked, {int? atMillis}) => PlayerAnswer(
        text: text,
        number: number,
        choice: choice,
        order: order,
        pairs: pairs,
        drawing: drawing,
        connections: connections,
        locked: locked,
        lockedAtMillis: locked ? (atMillis ?? lockedAtMillis) : null,
      );

  Map<String, dynamic> toJson() => {
        if (text != null) 'text': text,
        if (number != null) 'number': number,
        if (choice != null) 'choice': choice,
        if (order != null) 'order': order,
        if (pairs != null) 'pairs': pairs,
        if (drawing != null) 'drawing': drawing,
        if (connections != null) 'connections': connections!.toJson(),
        if (locked) 'locked': true,
        if (lockedAtMillis != null) 'lockedAt': lockedAtMillis,
      };

  factory PlayerAnswer.fromJson(Map<String, dynamic> json) {
    List<int>? ints(Object? v) => v is List ? [for (final e in v) (e as num).toInt()] : null;
    return PlayerAnswer(
      text: json['text'] as String?,
      number: _num(json['number']),
      choice: (json['choice'] as num?)?.toInt(),
      order: ints(json['order']),
      pairs: ints(json['pairs']),
      drawing: json['drawing'] as String?,
      connections: json['connections'] is Map
          ? ConnectionsProgress.fromJson(Map<String, dynamic>.from(json['connections'] as Map))
          : null,
      locked: json['locked'] == true,
      lockedAtMillis: (json['lockedAt'] as num?)?.toInt(),
    );
  }
}

/// Teams answering on their own devices. Answers stay with the host, visible
/// to the gamemaster, until they are shown on the big screen one by one.
class AnswerRound {
  const AnswerRound({
    required this.spec,
    this.open = true,
    this.openedAtMillis,
    this.endsAtMillis,
    this.answers = const {},
    this.revealed = const [],
    this.verdicts = const {},
    this.awarded = const {},
  });

  final CompanionSpec spec;

  /// Whether answers can still be changed.
  final bool open;

  /// Host clock; lets a device run a countdown without sharing that clock.
  final int? openedAtMillis;

  /// When the timer locks the round; null without a timer.
  final int? endsAtMillis;

  /// By team id.
  final Map<String, PlayerAnswer> answers;

  /// Team ids whose answers are on the big screen, in the order shown.
  final List<String> revealed;

  /// The gamemaster's ruling per team, where one was made.
  final Map<String, bool> verdicts;

  /// Points given for this round per team, so a ruling can be changed
  /// without counting twice.
  final Map<String, int> awarded;

  CompanionKind get kind => spec.kind;

  AnswerRound copyWith({
    bool? open,
    /// An int sets the timer, null clears it; leave out (or pass any other
    /// object) to keep it as it is.
    Object? endsAtMillis = _keep,
    Map<String, PlayerAnswer>? answers,
    List<String>? revealed,
    Map<String, bool>? verdicts,
    Map<String, int>? awarded,
  }) =>
      AnswerRound(
        spec: spec,
        open: open ?? this.open,
        openedAtMillis: openedAtMillis,
        endsAtMillis: endsAtMillis is int? ? endsAtMillis : this.endsAtMillis,
        answers: answers ?? this.answers,
        revealed: revealed ?? this.revealed,
        verdicts: verdicts ?? this.verdicts,
        awarded: awarded ?? this.awarded,
      );

  Map<String, dynamic> toJson() => {
        'spec': spec.toMap(),
        'open': open,
        'openedAt': openedAtMillis,
        'endsAt': endsAtMillis,
        'answers': {for (final entry in answers.entries) entry.key: entry.value.toJson()},
        'revealed': revealed,
        'verdicts': verdicts,
        'awarded': awarded,
      };

  factory AnswerRound.fromJson(Map<String, dynamic> json) => AnswerRound(
        spec: CompanionSpec.fromMap(json['spec']) ?? const CompanionSpec(kind: CompanionKind.text),
        open: json['open'] == true,
        openedAtMillis: (json['openedAt'] as num?)?.toInt(),
        endsAtMillis: (json['endsAt'] as num?)?.toInt(),
        answers: {
          for (final entry in (json['answers'] as Map? ?? const {}).entries)
            entry.key as String: PlayerAnswer.fromJson(Map<String, dynamic>.from(entry.value as Map)),
        },
        revealed: (json['revealed'] as List? ?? const []).cast<String>().toList(),
        verdicts: {
          for (final entry in (json['verdicts'] as Map? ?? const {}).entries) entry.key as String: entry.value == true,
        },
        awarded: {
          for (final entry in (json['awarded'] as Map? ?? const {}).entries) entry.key as String: (entry.value as num).toInt(),
        },
      );
}

const Object _keep = Object();

/// Whether an answer is right, where that can be decided without a human:
/// a pick, an order, a matching, or a number with a known solution. Null for
/// everything that needs the gamemaster's eye.
bool? autoVerdict(CompanionSpec spec, PlayerAnswer? answer, {List<bool> choiceCorrect = const []}) {
  if (answer == null) return null;
  bool identity(List<int> list, int length) =>
      list.length == length && Iterable<int>.generate(length).every((i) => list[i] == i);
  switch (spec.kind) {
    case CompanionKind.choice:
      final choice = answer.choice;
      if (choice == null || choiceCorrect.isEmpty) return null;
      return choice >= 0 && choice < choiceCorrect.length && choiceCorrect[choice];
    case CompanionKind.order:
      return answer.order == null ? null : identity(answer.order!, spec.options.length);
    case CompanionKind.match:
      return answer.pairs == null ? null : identity(answer.pairs!, spec.options.length);
    case CompanionKind.number:
    case CompanionKind.slider:
      if (spec.solution == null || answer.number == null) return null;
      return (answer.number! - spec.solution!).abs() < 1e-9;
    case CompanionKind.connections:
      final progress = answer.connections;
      return progress == null ? null : progress.solved.length == kConnectionsGroups;
    case CompanionKind.whiteboard:
    case CompanionKind.text:
      return null;
  }
}

/// For estimation questions: the teams whose number is nearest the solution.
/// Empty without a solution or without numeric answers.
List<String> closestTeams(CompanionSpec spec, Map<String, PlayerAnswer> answers) {
  final solution = spec.solution;
  if (solution == null) return const [];
  double? best;
  final closest = <String>[];
  answers.forEach((teamId, answer) {
    final number = answer.number;
    if (number == null) return;
    final distance = (number - solution).abs();
    if (best == null || distance < best! - 1e-9) {
      best = distance;
      closest
        ..clear()
        ..add(teamId);
    } else if ((distance - best!).abs() <= 1e-9) {
      closest.add(teamId);
    }
  });
  return closest;
}

/// How a number reads on screen: no trailing ".0", with its unit.
String formatNumber(double value, {String? unit}) {
  final text = value % 1 == 0 ? value.toInt().toString() : value.toString();
  return unit == null ? text : '$text $unit';
}
