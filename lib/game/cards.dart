/// What the gamemaster can put over the screen besides a game's own cards:
/// the pictures that come with the app, and how cards come on screen.
library;

/// Names of built-in pictures start with this; everything else is a media
/// file of the game.
const String builtinImagePrefix = 'builtin:';

class BuiltinImage {
  const BuiltinImage(this.id, this.label);

  final String id;
  final String label;

  /// The name to store on a card.
  String get name => '$builtinImagePrefix$id';

  /// Where the picture is in the app's assets.
  String get asset => 'assets/cards/$id.jpg';
}

/// The pictures that come with the app, in the order they are offered.
const List<BuiltinImage> builtinImages = [
  BuiltinImage('correct', "Correct!"),
  BuiltinImage('wrong', "Wrong!"),
  BuiltinImage('times_up', "Time's up!"),
  BuiltinImage('get_ready', "Get ready"),
  BuiltinImage('thinking', "Thinking time"),
  BuiltinImage('bonus', "Bonus question"),
  BuiltinImage('drumroll', "Drumroll…"),
  BuiltinImage('applause', "Applause!"),
  BuiltinImage('quiet', "Quiet please"),
  BuiltinImage('break', "Break"),
  BuiltinImage('final_round', "Final round"),
  BuiltinImage('winner', "And the winner is…"),
];

bool isBuiltinImage(String? name) => name != null && name.startsWith(builtinImagePrefix);

/// The built-in picture [name] refers to; null for game media and for names
/// this version does not know.
BuiltinImage? builtinImage(String? name) {
  if (!isBuiltinImage(name)) return null;
  final id = name!.substring(builtinImagePrefix.length);
  return builtinImages.where((image) => image.id == id).firstOrNull;
}

/// How a card comes on screen and goes again. Chosen by the gamemaster and
/// kept with the session until it is changed.
enum CardAnimation {
  off("Off"),
  fade("Fade"),
  slideUp("Slide in from bottom"),
  slideDown("Slide in from top"),
  bounce("Bounce in"),
  zoom("Zoom"),
  spin("Spin in"),
  flip("Flip");

  const CardAnimation(this.uiString);

  final String uiString;

  static CardAnimation fromName(Object? name) =>
      CardAnimation.values.where((a) => a.name == name).firstOrNull ?? CardAnimation.fade;
}

/// How a card with text looks on the big screen. Stored on the card as
/// `style`, only when it is not [standard].
enum CardStyle {
  standard("Standard"),
  silentFilm("Silent film"),
  poster("Poster"),
  plain("Just the words");

  const CardStyle(this.uiString);

  final String uiString;

  static CardStyle fromName(Object? name) => CardStyle.values.where((s) => s.name == name).firstOrNull ?? CardStyle.standard;
}
