/// Fragenhagel: many short questions right after one another, inside one
/// question of the game. Plain Dart.
library;

/// How the teams answer each item.
enum RapidMode {
  /// Teams buzz; the gamemaster judges the answer, a right one moves on.
  buzzer("Teams buzz"),

  /// Each item is a statement; every team picks right or wrong on its own
  /// device, scored when the gamemaster moves on.
  devices("Right or wrong on the teams' devices");

  const RapidMode(this.uiString);

  final String uiString;

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
///   image, music: media files of the game shown and played with the item
class RapidItem {
  const RapidItem({this.question = '', this.answer = '', this.isTrue = true, this.image, this.music});

  final String question;
  final String answer;
  final bool isTrue;
  final String? image;
  final String? music;

  static RapidItem fromMap(Object? stored) {
    if (stored is! Map) return const RapidItem();
    String? file(Object? v) => v is String && v.isNotEmpty ? v : null;
    return RapidItem(
      question: stored['question'] is String ? stored['question'] as String : '',
      answer: stored['answer'] is String ? stored['answer'] as String : '',
      isTrue: stored['true'] != false,
      image: file(stored['image']),
      music: file(stored['music']),
    );
  }

  Map<String, dynamic> toMap() => {'question': question, 'answer': answer, 'true': isTrue, 'image': image, 'music': music};

  RapidItem copyWith({String? question, String? answer, bool? isTrue, Object? image = _keep, Object? music = _keep}) => RapidItem(
        question: question ?? this.question,
        answer: answer ?? this.answer,
        isTrue: isTrue ?? this.isTrue,
        image: image == _keep ? this.image : image as String?,
        music: music == _keep ? this.music : music as String?,
      );
}

const Object _keep = Object();

/// A Fragenhagel's setup, stored on the question as `rapidFire`.
///
/// In the session the reveal counter counts the items done: item `revealed`
/// is the one asked, and `revealed == items.length` means the round is over.
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
