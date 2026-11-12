import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/game/cards.dart';
import 'package:quiz_show/game/companion.dart';
import 'package:quiz_show/game/content.dart';
import 'package:quiz_show/game/last_standing.dart';
import 'package:quiz_show/game/rapid_fire.dart';
import 'package:quiz_show/game/top_answers.dart';

import 'app_localizations.dart';

/// The names of lib/game's enums in the user's language. lib/game keeps
/// its English `uiString`s and stays free of Flutter.
extension GameNames on AppLocalizations {
  String questionType(QuestionType type) => questionTypeName(type.name);
  String boardType(BoardType type) => boardTypeName(type.name);
  String gameRole(GameRole role) => gameRoleName(role.name);
  String companionKind(CompanionKind kind) => companionKindName(kind.name);

  /// A name in the middle of a sentence: lower case in English, as in
  /// "slider on the devices"; German nouns keep their capital.
  String inline(String name) => localeName == 'de' ? name : name.toLowerCase();
  String estimateScoring(EstimateScoring scoring) => estimateScoringName(scoring.name);
  String turnOrder(TurnOrder order) => turnOrderName(order.name);
  String standingResult(StandingResult result) => standingResultName(result.name);
  String rapidMode(RapidMode mode) => rapidModeName(mode.name);
  String progressStyle(ProgressStyle style) => progressStyleName(style.name);
  String topAnswersMode(TopAnswersMode mode) => topAnswersModeName(mode.name);
  String cardAnimation(CardAnimation animation) => cardAnimationName(animation.name);
  String cardStyle(CardStyle style) => cardStyleName(style.name);
  String builtinImage(BuiltinImage image) => builtinImageName(image.id);

  /// The picture's file: its words are drawn into it, so German has its own.
  String builtinImageAsset(BuiltinImage image) => localeName == 'de' ? 'assets/cards/de/${image.id}.jpg' : image.asset;

  /// "1st", "2nd" in English; "1.", "2." in German.
  String ordinal(int place) {
    if (localeName == 'de') return '$place.';
    final suffix = (place % 100 >= 11 && place % 100 <= 13) ? 'th' : switch (place % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
    return '$place$suffix';
  }

  /// "2. out": the place a team went out in, short as it sits on a chip.
  String outPlace(int place) => outPlaceLabel('$place.');

  /// A label lib/game made for the teams' devices, such as "Picture B" for
  /// a matching item without text, or "Right" of [rapidChoices].
  String deviceLabel(String text) {
    final picture = RegExp(r'^Picture (\w+)$').firstMatch(text);
    if (picture != null) return pictureLabel(picture.group(1)!);
    return rapidChoice(text);
  }

  /// One of [rapidChoices] ("Right", "Wrong") as the device shows it.
  String rapidChoice(String choice) => switch (choice) {
    "Right" => rapidRight,
    "Wrong" => rapidWrong,
    _ => choice,
  };
}
