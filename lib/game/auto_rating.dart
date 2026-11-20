/// How a question's answers on the teams' devices are rated by themselves,
/// set in the editor. Plain Dart.
library;

/// ABCD where teams may pick several options: what counts as right.
enum MultipleChoiceScoring {
  /// Exactly the right options, no more and no fewer.
  all,

  /// At least one right option and no wrong one.
  any,

  /// A share of the points: right picks less wrong ones, out of the right
  /// options there are.
  partial;

  static MultipleChoiceScoring fromName(Object? name) =>
      MultipleChoiceScoring.values.where((scoring) => scoring.name == name).firstOrNull ?? MultipleChoiceScoring.all;
}

/// Stored on the question as `autoRating`; absent means the defaults: rated
/// by itself, and with several picks only exactly the right ones count, as
/// before there was a setting.
///
///   off:       true when the gamemaster rates every answer by hand
///   multiple:  see [MultipleChoiceScoring]; absent = all
class AutoRating {
  const AutoRating({this.on = true, this.multiple = MultipleChoiceScoring.all});

  /// Whether answers are rated as soon as they are final, as if the
  /// gamemaster had tapped right or wrong.
  final bool on;

  final MultipleChoiceScoring multiple;

  bool get isDefault => on && multiple == MultipleChoiceScoring.all;

  static AutoRating fromMap(Object? stored) {
    if (stored is! Map) return const AutoRating();
    return AutoRating(on: stored['off'] != true, multiple: MultipleChoiceScoring.fromName(stored['multiple']));
  }

  /// Null for the defaults, so questions that never changed them store
  /// nothing.
  Map<String, dynamic>? toMap() => isDefault
      ? null
      : {
          if (!on) 'off': true,
          if (multiple != MultipleChoiceScoring.all) 'multiple': multiple.name,
        };

  AutoRating copyWith({bool? on, MultipleChoiceScoring? multiple}) => AutoRating(on: on ?? this.on, multiple: multiple ?? this.multiple);

  @override
  bool operator ==(Object other) => other is AutoRating && other.on == on && other.multiple == multiple;

  @override
  int get hashCode => Object.hash(on, multiple);
}
