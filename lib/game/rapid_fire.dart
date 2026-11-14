/// Fragenhagel: many short questions right after one another, inside one
/// question of the game. Plain Dart.
library;

/// How the teams answer each item.
enum RapidMode {
  /// Teams buzz; the gamemaster judges the answer, a right one moves on.
  buzzer("Teams buzz"),

  /// Each item is a statement; every team picks right or wrong on its own
  /// device, scored when the gamemaster moves on.
  devices("Right or wrong"),

  /// Every team writes or draws its answer to each item on a whiteboard on
  /// its device; the gamemaster rates them, scored when moving on.
  whiteboard("Whiteboard");

  const RapidMode(this.uiString);

  final String uiString;

  /// Whether the teams answer on their own devices, not by buzzing.
  bool get onDevices => this != buzzer;

  static RapidMode fromName(Object? name) => RapidMode.values.where((m) => m.name == name).firstOrNull ?? RapidMode.buzzer;
}

/// What shows how far the round has come, on the big screen.
enum ProgressStyle {
  off("No progress indicator"),
  bar("Bar"),
  dots("Dots"),
  battery("Battery"),
  thermometer("Thermometer"),
  flux("Flux capacitor");

  const ProgressStyle(this.uiString);

  final String uiString;

  static ProgressStyle fromName(Object? name) => ProgressStyle.values.where((p) => p.name == name).firstOrNull ?? ProgressStyle.off;
}

/// The options a team's device offers for a statement, in this order.
const List<String> rapidChoices = ["Right", "Wrong"];

/// One item of a Fragenhagel.
///
///   question: what is asked, or the statement to judge
///   answer:   buzzer mode: the answer, for the gamemaster
///   true:     devices mode: whether the statement is right
///   hint:     optional, for the gamemaster only: something to help judge
///             or to tell after the item ("also accept: Lisbon")
///   image, music: media files of the game shown and played with the item
class RapidItem {
  const RapidItem({this.question = '', this.answer = '', this.isTrue = true, this.hint = '', this.image, this.music});

  final String question;
  final String answer;
  final bool isTrue;
  final String hint;
  final String? image;
  final String? music;

  static RapidItem fromMap(Object? stored) {
    if (stored is! Map) return const RapidItem();
    String? file(Object? v) => v is String && v.isNotEmpty ? v : null;
    return RapidItem(
      question: stored['question'] is String ? stored['question'] as String : '',
      answer: stored['answer'] is String ? stored['answer'] as String : '',
      isTrue: stored['true'] != false,
      hint: stored['hint'] is String ? stored['hint'] as String : '',
      image: file(stored['image']),
      music: file(stored['music']),
    );
  }

  Map<String, dynamic> toMap() => {
        'question': question,
        'answer': answer,
        'true': isTrue,
        if (hint.isNotEmpty) 'hint': hint,
        'image': image,
        'music': music,
      };

  RapidItem copyWith({String? question, String? answer, bool? isTrue, String? hint, Object? image = _keep, Object? music = _keep}) =>
      RapidItem(
        question: question ?? this.question,
        answer: answer ?? this.answer,
        isTrue: isTrue ?? this.isTrue,
        hint: hint ?? this.hint,
        image: image == _keep ? this.image : image as String?,
        music: music == _keep ? this.music : music as String?,
      );
}

const Object _keep = Object();

/// A Fragenhagel's setup, stored on the question as `rapidFire`.
///
/// In the session the reveal counter counts the items done: item `revealed`
/// is the one asked, and `revealed == items.length` means the round is over.
/// It starts at -1: only the question itself is on screen, for the
/// gamemaster to read out, and the first "next" brings up the first item.
class RapidFire {
  const RapidFire({this.mode = RapidMode.buzzer, this.progress = ProgressStyle.bar, this.items = const []});

  final RapidMode mode;
  final ProgressStyle progress;
  final List<RapidItem> items;

  static RapidFire fromMap(Object? stored) {
    if (stored is! Map) return const RapidFire();
    return RapidFire(
      mode: RapidMode.fromName(stored['mode']),
      progress: stored.containsKey('progress') ? ProgressStyle.fromName(stored['progress']) : ProgressStyle.bar,
      items: [
        if (stored['items'] is List)
          for (final item in stored['items'] as List) RapidItem.fromMap(item),
      ],
    );
  }

  Map<String, dynamic> toMap() => {
        'mode': mode.name,
        'progress': progress.name,
        'items': [for (final item in items) item.toMap()],
      };

  /// The item asked at reveal counter [done]; null once all are done.
  RapidItem? itemAt(int done) => done >= 0 && done < items.length ? items[done] : null;

  Iterable<String> get mediaPaths => [
        for (final item in items) ...[?item.image, ?item.music],
      ];
}

/// What happened on one Fragenhagel item: the points each team got or lost
/// on it, and on the devices what each team picked. Kept so that going back
/// takes the points back and gives the picks back.
class RapidStep {
  const RapidStep({this.points = const {}, this.picks = const {}, this.drawings = const {}});

  final Map<String, int> points;

  /// Team id to the index of its pick in [rapidChoices]. On the whiteboard:
  /// how the gamemaster rated it, 0 right and 1 wrong.
  final Map<String, int> picks;

  /// Whiteboard: team id to its drawing, to give it back on going back.
  final Map<String, String> drawings;

  RapidStep withPoints(String teamId, int delta) =>
      RapidStep(points: {...points, teamId: (points[teamId] ?? 0) + delta}, picks: picks, drawings: drawings);

  RapidStep withPick(String teamId, int choice) => RapidStep(points: points, picks: {...picks, teamId: choice}, drawings: drawings);

  /// Whiteboard: the team's drawing and how it was rated, where it was.
  RapidStep withAnswer(String teamId, {bool? right, String? drawing}) => RapidStep(
        points: points,
        picks: right == null ? picks : {...picks, teamId: right ? 0 : 1},
        drawings: drawing == null ? drawings : {...drawings, teamId: drawing},
      );

  Map<String, dynamic> toJson() => {
        if (points.isNotEmpty) 'points': points,
        if (picks.isNotEmpty) 'picks': picks,
        if (drawings.isNotEmpty) 'drawings': drawings,
      };

  static RapidStep fromJson(Object? json) {
    Map<String, int> ints(Object? map) => {
          if (map is Map)
            for (final MapEntry(:key, :value) in map.entries)
              if (value is num) '$key': value.toInt(),
        };
    final drawings = json is Map ? json['drawings'] : null;
    return json is Map
        ? RapidStep(
            points: ints(json['points']),
            picks: ints(json['picks']),
            drawings: {
              if (drawings is Map)
                for (final MapEntry(:key, :value) in drawings.entries)
                  if (value is String) '$key': value,
            },
          )
        : const RapidStep();
  }
}
