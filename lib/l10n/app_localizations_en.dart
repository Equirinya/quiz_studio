// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Quiz Studio';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get done => 'Done';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get thatDidntWork => 'That didn\'t work.';

  @override
  String get account => 'Account';

  @override
  String get navGames => 'Games';

  @override
  String get navSessions => 'Sessions';

  @override
  String get couldNotOpenStore => 'Couldn\'t open the store';

  @override
  String get downloadPage => 'download page';

  @override
  String get updateRequired => 'Update required';

  @override
  String get updateRequiredText =>
      'This version of the app is no longer supported. Please update to continue.';

  @override
  String installedAndRequired(String installed, String required) {
    return 'Installed $installed · required $required';
  }

  @override
  String openStore(String store) {
    return 'Open $store';
  }

  @override
  String get yourName => 'Your name';

  @override
  String get theNameOthersSee => 'The name others see';

  @override
  String nameLength(int min, int max) {
    return 'A name needs between $min and $max characters.';
  }

  @override
  String get addEmailAndPassword => 'Add email and password';

  @override
  String get upgradeSubtitle =>
      'Your games stay with this account. Afterwards you can sign in to it on your other devices.';

  @override
  String get upgradeDone => 'Done. This account now has an email address.';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutGuestWarning =>
      'You are signed in as a guest. Signing out loses this account and the games only it can access. Add an email address first to keep them.';

  @override
  String get signOutInfo =>
      'You can sign in again with your email address and password.';

  @override
  String get deletingAccount => 'Deleting your account…';

  @override
  String get accountDeleted => 'Your account and its data are deleted.';

  @override
  String get accountNotDeletedConnection =>
      'The account could not be deleted. Check the connection and try again.';

  @override
  String get nameSubtitle => 'The name other players and co-authors see';

  @override
  String get guestAccount => 'Guest account';

  @override
  String get guestAccountText =>
      'Your games live only on this device\'s account. Add an email address and password to keep them safe and to sign in on your other devices, for example the PC that presents and the phone that controls.';

  @override
  String get emailSubtitle => 'Sign in with this address on your other devices';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountSubtitle =>
      'Your profile, your own games and your sessions';

  @override
  String get contact => 'Contact';

  @override
  String get contactSubtitle => 'Feedback, bug reports and feature requests';

  @override
  String get terms => 'Terms';

  @override
  String get privacy => 'Privacy';

  @override
  String get aboutAndLicences => 'About and licences';

  @override
  String get soundCredits => 'Sound credits';

  @override
  String get soundCreditsSubtitle => 'Where the built-in sounds are from';

  @override
  String get deleteAccountQuestion => 'Delete account?';

  @override
  String get deleteAccountText =>
      'This deletes your profile, the games only you are in, with their pictures and sounds, and the sessions you host. Games you share stay with the others; if you are their only admin, a co-author becomes admin. This cannot be undone.';

  @override
  String get password => 'Password';

  @override
  String get wrongPassword => 'That password is not right.';

  @override
  String get tooManyTries => 'Too many tries. Wait a moment and try again.';

  @override
  String get requiresRecentLogin =>
      'Sign out, sign in again and then delete the account.';

  @override
  String get noConnectionTryOnline =>
      'No connection. Try again when you are online.';

  @override
  String get accountNotDeleted =>
      'The account could not be deleted. Try again.';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System language';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get notSignedIn => 'You are not signed in.';

  @override
  String get emailInUse =>
      'There is already an account with this email address. Sign in to that one instead.';

  @override
  String get invalidEmail => 'That is not a valid email address.';

  @override
  String get weakPassword => 'Please choose a stronger password.';

  @override
  String get alreadyHasEmail => 'This account already has an email address.';

  @override
  String get restartAndRetry =>
      'For safety, please restart the app and try again.';

  @override
  String get notConnected => 'You\'re not connected to the internet.';

  @override
  String get emailSignInOff => 'Email sign-in is switched off for this app.';

  @override
  String get didNotWorkTryAgain => 'That did not work. Please try again.';

  @override
  String get unknownUser => 'Unknown user';

  @override
  String get passwordMinLength => 'At least 8 characters';

  @override
  String get passwordUppercase => 'An uppercase letter';

  @override
  String get passwordLowercase => 'A lowercase letter';

  @override
  String get passwordNumber => 'A number';

  @override
  String get email => 'Email';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get showPassword => 'Show password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordsDontMatch => 'Passwords don\'t match.';

  @override
  String get featureBuildTitle => 'Build quizzes together';

  @override
  String get featureBuildText =>
      'Write categories and questions with friends, without spoiling each other.';

  @override
  String get featurePresentTitle => 'Present on the big screen';

  @override
  String get featurePresentText =>
      'Run the show on a TV or projector and control it from your phone.';

  @override
  String get featureBuzzersTitle => 'Phones as buzzers';

  @override
  String get featureBuzzersText =>
      'Players join by scanning a code. Arduino buzzers work too.';

  @override
  String get featureMusicTitle => 'Music and sound effects';

  @override
  String get featureMusicText =>
      'Background music, reveal sounds and a buzzer sound per team.';

  @override
  String get enterValidEmail => 'Please enter a valid email address.';

  @override
  String get enterPassword => 'Please enter your password.';

  @override
  String get noAccountForEmail => 'No account found with this email address.';

  @override
  String get wrongEmailOrPassword => 'Wrong email address or password.';

  @override
  String get invalidEmailShort => 'Invalid email address.';

  @override
  String get accountDisabled => 'This account has been disabled.';

  @override
  String get tooManyAttempts => 'Too many attempts. Please try again later.';

  @override
  String get signInFailed => 'Sign-in failed. Please try again.';

  @override
  String get anonymousSignInDisabled =>
      'Anonymous sign-in is disabled. Please try again later.';

  @override
  String get couldNotStart => 'Could not get you started. Please try again.';

  @override
  String get unknownError => 'An unknown error occurred.';

  @override
  String get couldNotSaveName => 'Could not save your name. Please try again.';

  @override
  String get login => 'Login';

  @override
  String get chooseYourName =>
      'Choose the name other players and co-authors will see:';

  @override
  String get theNameOthersWillSee => 'The name others will see';

  @override
  String get justJoinAShow => 'Just join a show';

  @override
  String get useDifferentAccount => 'Use a different account';

  @override
  String get haveAnAccount => 'I already have an account';

  @override
  String get termsBefore => 'By continuing you agree to the ';

  @override
  String get termsLink => 'Terms & Conditions';

  @override
  String get termsBetween => ' and the ';

  @override
  String get privacyLink => 'Privacy Policy';

  @override
  String get termsAfter => '.';

  @override
  String get back => 'Back';

  @override
  String get letsPlay => 'Let\'s play';

  @override
  String get joinAShow => 'Join a show';

  @override
  String get createOwnQuizzes => 'Create my own quizzes';

  @override
  String get creditsMadeForApp => 'Made for Quiz Studio';

  @override
  String creditsMadeBy(String name) {
    return 'Made by $name';
  }

  @override
  String get creditsPartOfApp => 'Part of the app';

  @override
  String get creditsPublicDomain => '(public domain)';

  @override
  String get creditsIntro =>
      'The sounds that come with Quiz Studio were made for it or are free to use in any project (CC0). Tap a source to see where it is from.';

  @override
  String questionTypeName(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'free': 'Free Question',
      'abcd': 'ABCD',
      'progressingReveal': 'Progressing Reveal',
      'feud': 'Survey duel',
      'connections': 'Word groups',
      'rapidFire': 'Fragenhagel',
      'matching': 'Matching',
      'ordering': 'Put in order',
      'topAnswers': 'Top answers',
      'lastStanding': 'Last team standing',
      'other': 'Unsupported',
    });
    return '$_temp0';
  }

  @override
  String boardTypeName(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'display': 'Display Board',
      'wheel': 'Wheel Playboard',
      'other': 'Map Playboard',
    });
    return '$_temp0';
  }

  @override
  String gameRoleName(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'admin': 'Admin',
      'full': 'Full Access',
      'other': 'Limited Access',
    });
    return '$_temp0';
  }

  @override
  String companionKindName(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'whiteboard': 'Whiteboard',
      'text': 'Text',
      'number': 'Number',
      'slider': 'Slider',
      'choice': 'Pick one',
      'order': 'Put in order',
      'match': 'Match pairs',
      'connections': 'Word groups',
      'other': 'Answer list',
    });
    return '$_temp0';
  }

  @override
  String estimateScoringName(String scoring) {
    String _temp0 = intl.Intl.selectLogic(scoring, {
      'closest': 'Closest wins',
      'podium': '1st, 2nd, 3rd',
      'other': 'By distance',
    });
    return '$_temp0';
  }

  @override
  String turnOrderName(String order) {
    String _temp0 = intl.Intl.selectLogic(order, {
      'teams': 'As the teams are listed',
      'mostPoints': 'Most points first',
      'other': 'Fewest points first',
    });
    return '$_temp0';
  }

  @override
  String standingResultName(String result) {
    String _temp0 = intl.Intl.selectLogic(result, {
      'right': 'Right',
      'out': 'Wrong, out',
      'other': 'Wrong, stays in',
    });
    return '$_temp0';
  }

  @override
  String rapidModeName(String mode) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'buzzer': 'Teams buzz',
      'other': 'Right or wrong on the teams\' devices',
    });
    return '$_temp0';
  }

  @override
  String progressStyleName(String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'off': 'No progress indicator',
      'bar': 'Bar',
      'dots': 'Dots',
      'battery': 'Battery',
      'thermometer': 'Thermometer',
      'other': 'Flux capacitor',
    });
    return '$_temp0';
  }

  @override
  String topAnswersModeName(String mode) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'buzzer': 'Teams buzz',
      'typed': 'Typed in on the teams\' devices',
      'other': 'Written on a whiteboard',
    });
    return '$_temp0';
  }

  @override
  String cardAnimationName(String animation) {
    String _temp0 = intl.Intl.selectLogic(animation, {
      'off': 'Off',
      'fade': 'Fade',
      'slideUp': 'Slide in from bottom',
      'slideDown': 'Slide in from top',
      'bounce': 'Bounce in',
      'zoom': 'Zoom',
      'spin': 'Spin in',
      'other': 'Flip',
    });
    return '$_temp0';
  }

  @override
  String cardStyleName(String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'standard': 'Standard',
      'silentFilm': 'Silent film',
      'poster': 'Poster',
      'other': 'Just the words',
    });
    return '$_temp0';
  }

  @override
  String builtinImageName(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'correct': 'Correct!',
      'wrong': 'Wrong!',
      'times_up': 'Time\'s up!',
      'get_ready': 'Get ready',
      'thinking': 'Thinking time',
      'bonus': 'Bonus question',
      'drumroll': 'Drumroll…',
      'applause': 'Applause!',
      'quiet': 'Quiet please',
      'break': 'Break',
      'final_round': 'Final round',
      'winner': 'And the winner is…',
      'other': 'Picture',
    });
    return '$_temp0';
  }

  @override
  String get rapidRight => 'Right';

  @override
  String get rapidWrong => 'Wrong';

  @override
  String get newGame => 'New game';

  @override
  String get name => 'Name';

  @override
  String get couldNotCreateGame => 'Could not create the game.';

  @override
  String get joinWithInviteLink => 'Join with an invite link';

  @override
  String get couldNotLoadGames => 'Could not load your games.';

  @override
  String get noGamesYet => 'No games yet';

  @override
  String get noGamesYetText =>
      'Create your first quiz, or ask a friend to invite you to theirs.';

  @override
  String get unnamed => 'Unnamed';

  @override
  String get couldNotUploadPicture => 'Could not upload the picture.';

  @override
  String get map => 'Map';

  @override
  String get groupNotAvailable => 'This group is not available.';

  @override
  String newBoard(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'display': 'New Display Board',
      'wheel': 'New Wheel Playboard',
      'other': 'New Map Playboard',
    });
    return '$_temp0';
  }

  @override
  String addBoard(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'display': 'Add Display Board',
      'wheel': 'Add Wheel Playboard',
      'other': 'Add Map Playboard',
    });
    return '$_temp0';
  }

  @override
  String get newCategory => 'New Category';

  @override
  String get hideOne => 'Hide one';

  @override
  String revealedOf(int revealed, int steps) {
    return '$revealed of $steps revealed';
  }

  @override
  String get revealNext => 'Reveal next';

  @override
  String get boardColours => 'Board colours';

  @override
  String get primaryColour => 'Primary';

  @override
  String get accentColour => 'Accent';

  @override
  String get useAppColours => 'Use app colours';

  @override
  String get noTimer => 'No timer';

  @override
  String get timer => 'Timer';

  @override
  String get teamsCanLockIn => 'Teams can lock in early';

  @override
  String get lockInOnText =>
      'Locking in ends a team\'s time, and how long it took is kept. Only when scored by order, fastest first';

  @override
  String get lockInOffText =>
      'Every answer counts as it stands when the time is up or you end the round';

  @override
  String musicCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count music',
      one: '1 music',
    );
    return '$_temp0';
  }

  @override
  String effectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count effects',
      one: '1 effect',
    );
    return '$_temp0';
  }

  @override
  String get none => 'None';

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String cardsOfferedOff(int on, int off) {
    return '$on offered, $off off';
  }

  @override
  String get gameNotAvailable => 'This game is not available.';

  @override
  String get copiedGame => 'Copied the game with its answers.';

  @override
  String get renameGame => 'Rename game';

  @override
  String get deleteGame => 'Delete game';

  @override
  String deleteGameText(String name) {
    return '\"$name\" and all of its questions will be deleted for everyone.';
  }

  @override
  String get leaveGame => 'Leave game';

  @override
  String leaveGameText(String name) {
    return 'You will lose access to \"$name\" until someone invites you again.';
  }

  @override
  String get leave => 'Leave';

  @override
  String get musicAndSounds => 'Music & sounds';

  @override
  String get noneYet => 'None yet';

  @override
  String get soundsForGame => 'Sounds for the whole game';

  @override
  String get cards => 'Cards';

  @override
  String get cardsForGame => 'Cards for the whole game';

  @override
  String get people => 'People';

  @override
  String get more => 'More';

  @override
  String get rename => 'Rename';

  @override
  String get copyAsText => 'Copy as text';

  @override
  String get nothingSharedYet =>
      'Nothing here yet. Ask an admin to share a category with you.';

  @override
  String get onlyYou => 'Only you';

  @override
  String memberCount(int count) {
    return '$count members';
  }

  @override
  String get renameGroup => 'Rename group';

  @override
  String get displayText => 'Display text';

  @override
  String get shownOnBoard => 'Shown on the board';

  @override
  String categoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$_temp0';
  }

  @override
  String get ownSounds => 'own sounds';

  @override
  String get usesGames => 'Uses the game\'s';

  @override
  String get soundsForBoard => 'Sounds for this board';

  @override
  String get onlyGames => 'Only the game\'s';

  @override
  String get cardsForBoard => 'Cards for this board';

  @override
  String get colours => 'Colours';

  @override
  String get appsColours => 'The app\'s colours';

  @override
  String get ownColours => 'Own colours';

  @override
  String get textOnBoard => 'Text on the board';

  @override
  String get splitPointFields => 'Split point fields';

  @override
  String get splitPointFieldsText =>
      'When a value appears more than once in a ring';

  @override
  String get arrangeMap => 'Arrange the map';

  @override
  String get arrangeMapShort => 'Bubbles, arrows, titles, pictures and lines';

  @override
  String get arrangeMapLong =>
      'Place bubbles, connect them, add titles, pictures and lines';

  @override
  String get labelsInsteadOfPoints => 'Labels instead of points';

  @override
  String get labelsInsteadOfPointsText =>
      'Questions without a label still show their points';

  @override
  String get deleteBoard => 'Delete board';

  @override
  String get deleteBoardFirst => 'Move or delete its categories first';

  @override
  String get ungroupedCategories => 'Ungrouped categories';

  @override
  String get boardSettings => 'Board settings';

  @override
  String get moveBoard => 'Move board';

  @override
  String get addCategory => 'Add category';

  @override
  String get moveToAnotherBoard => 'Move to another board';

  @override
  String comesAfterTitle(String name) {
    return '\"$name\" comes after';
  }

  @override
  String get categoryBeforeIt => 'The category before it (default)';

  @override
  String get startsNewChain => 'Nothing: it starts a new chain';

  @override
  String get deleteCategory => 'Delete category';

  @override
  String deleteCategoryText(String name, int count) {
    return '\"$name\" and its $count questions will be deleted.';
  }

  @override
  String get inPlayTip => 'In play: tap to take it out of the game';

  @override
  String get notInPlayTip => 'Not in play: tap to put it back';

  @override
  String get moveCategory => 'Move category';

  @override
  String questionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$_temp0';
  }

  @override
  String get notInPlay => 'not in play';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get moveToAnotherBoardMenu => 'Move to another board…';

  @override
  String get comesAfterMenu => 'Comes after…';

  @override
  String get renameCategory => 'Rename category';

  @override
  String get shareCategory => 'Share category';

  @override
  String get shareCategoryText =>
      'Members with limited access only see the categories switched on here.';

  @override
  String get createdThisCategory => 'Created this category';

  @override
  String get notShared => 'Not shared';

  @override
  String sharedWith(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'With $count people',
      one: 'With 1 person',
    );
    return '$_temp0';
  }

  @override
  String get categoryNotAvailable => 'This category is not available.';

  @override
  String get addQuestion => 'Add question';

  @override
  String get usesBoards => 'Uses the board\'s';

  @override
  String get soundsForCategory => 'Sounds for this category';

  @override
  String get onlyBoardsAndGames => 'Only the board\'s and game\'s';

  @override
  String get cardsForCategory => 'Cards for this category';

  @override
  String get share => 'Share';

  @override
  String get noQuestionsYet => 'No questions yet.';

  @override
  String get couldNotSave => 'Could not save.';

  @override
  String get deleteQuestion => 'Delete question';

  @override
  String get deleteQuestionText => 'This question will be deleted.';

  @override
  String get onTheDevices => 'on the devices';

  @override
  String kindOnTheDevices(String kind) {
    return '$kind on the devices';
  }

  @override
  String get teamsBetShort => 'teams bet';

  @override
  String get teamsBetHowManyShort => 'teams bet how many';

  @override
  String get byOrderShort => 'by order';

  @override
  String get fixed => 'Fixed';

  @override
  String pointsBetSummary(int limit) {
    return 'Teams bet their points · at least $limit to bet';
  }

  @override
  String get betOnHowMany => 'Bet on how many';

  @override
  String plusEach(int plus) {
    return '+$plus each';
  }

  @override
  String plusMinusEach(int plus, int minus) {
    return '+$plus / −$minus each';
  }

  @override
  String byOrderSummary(int plus, int step) {
    return 'By order · $plus, then −$step per place';
  }

  @override
  String wrongMinus(int minus) {
    return 'wrong −$minus';
  }

  @override
  String get picture => 'Picture';

  @override
  String get music => 'Music';

  @override
  String get noOwnMedia => 'No picture, music or sounds of its own';

  @override
  String get rule => 'Rule';

  @override
  String scoringRuleName(String rule) {
    String _temp0 = intl.Intl.selectLogic(rule, {
      'fixed': 'Fixed points',
      'points': 'Teams bet their points',
      'amount': 'Teams bet how many they can do',
      'closest': 'By closeness: nearest first',
      'other': 'By order: fastest first',
    });
    return '$_temp0';
  }

  @override
  String get scoringFixedText => 'Every team plays for the same points.';

  @override
  String get scoringRankedText =>
      'The first team gets the most points, each after it a bit less. The order is the order teams locked in a right answer on their devices, or the order you tap them in, e.g. as they finish on stage. Wrong answers lose the minus points.';

  @override
  String scoringPointsText(int limit) {
    return 'Before the question, each team bets some of its points: a right answer wins the bet, a wrong one loses it. Teams may bet up to their score, or up to $limit if they have less.';
  }

  @override
  String get scoringAmountText =>
      'First only the bet question is shown and each team says how many it can do. Then the question runs; you decide per team whether it reached its number. Reached: the points for each one. Missed: the minus points for each one.';

  @override
  String get betQuestion => 'Bet question';

  @override
  String get betQuestionHint => 'How many science fiction films can you name?';

  @override
  String get points => 'Points';

  @override
  String get eachPlus => 'Each +';

  @override
  String get firstPlacePlus => '1st place +';

  @override
  String get eachItemPlus => 'Each item +';

  @override
  String get winnerPlus => 'Winner +';

  @override
  String get eachAnswerPlus => 'Each answer +';

  @override
  String get ifRightPlus => 'If right +';

  @override
  String onTheBoard(int points) {
    return '$points on the board';
  }

  @override
  String get eachMinus => 'Each −';

  @override
  String get ifWrongMinus => 'If wrong −';

  @override
  String get lessPerPlace => 'Less per place';

  @override
  String get highestBet => 'Highest bet';

  @override
  String get musicAndEffects => 'Music & effects';

  @override
  String get theCategorys => 'The category\'s';

  @override
  String get soundsForQuestion => 'Sounds for this question';

  @override
  String get type => 'Type';

  @override
  String get question => 'Question';

  @override
  String get answerHint => 'Answer hint';

  @override
  String get onlyGamemasterSees => 'Only the gamemaster sees this';

  @override
  String get label => 'Label';

  @override
  String get labelHelper => 'Small badge shown on the question card';

  @override
  String get labelTooltip => 'A small badge shown on the question card';

  @override
  String get howTeamsAnswer => 'How teams answer';

  @override
  String get scoring => 'Scoring';

  @override
  String get mediaAndSound => 'Media & sound';

  @override
  String get moveQuestion => 'Move question';

  @override
  String get newQuestion => 'New question';

  @override
  String get preview => 'Preview';

  @override
  String get explainFree =>
      'The most basic question: no answer options and nothing to reveal. Under \"How teams answer\" buzzers can be switched off, e.g. for estimation questions.';

  @override
  String get explainAbcd =>
      'Shows right and wrong answer suggestions, which the gamemaster reveals one by one.';

  @override
  String get explainProgressingReveal =>
      'The gamemaster reveals more information piece by piece.';

  @override
  String get explainFeud =>
      'A duel over a survey: the team that buzzed uncovers answers until its third strike, then the other team may steal them all.';

  @override
  String get explainTopAnswers =>
      'Name the most popular answers: teams find answers on a list, by buzzing or on their devices, and get the points of each one.';

  @override
  String get explainConnections =>
      'Sixteen words in four groups of four. Every team solves it on its own device; each group found is worth a quarter of the points.';

  @override
  String get explainRapidFire =>
      'Fragenhagel: many short questions right after one another. Teams buzz, or judge statements right or wrong on their devices; each item can have a picture and a sound.';

  @override
  String get explainMatching =>
      'Matching: pairs of texts or pictures, e.g. films and their years. Every team puts them back together on its device; the big screen shows the pictures.';

  @override
  String get explainLastStanding =>
      'Last team standing: one player per team takes turns, e.g. naming films or saying whether a star has a biopic. A wrong answer puts the team out; the last team left gets the points.';

  @override
  String get explainUnsupported =>
      'This question type is not supported by this version of the app.';

  @override
  String groupsNeedNameAndWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups need a name and four words.',
      one: '1 group needs a name and four words.',
    );
    return '$_temp0';
  }

  @override
  String wordTwice(String word) {
    return '\"$word\" is in the puzzle twice.';
  }

  @override
  String groupInCommon(int group) {
    String _temp0 = intl.Intl.pluralLogic(
      group,
      locale: localeName,
      other: 'Purple',
      two: 'Blue',
      one: 'Green',
      zero: 'Yellow',
    );
    return '$_temp0: what they have in common';
  }

  @override
  String wordN(int n) {
    return 'Word $n';
  }

  @override
  String get connectionsReady =>
      'Ready. Yellow is meant to be the easiest group and purple the hardest.';

  @override
  String answerLetter(String letter) {
    return 'Answer $letter';
  }

  @override
  String get removeAnswer => 'Remove answer';

  @override
  String get addAnswer => 'Add answer';

  @override
  String get absoluteValues => 'Show absolute values instead of percentages';

  @override
  String get value => 'Value';

  @override
  String answerN(int n) {
    return 'Answer $n';
  }

  @override
  String informationN(int n) {
    return 'Information $n';
  }

  @override
  String get addInformation => 'Add information';

  @override
  String get importFromRanker => 'Import from Ranker';

  @override
  String get pictureStrip => 'Picture strip';

  @override
  String get pictureStripText =>
      'Small pictures under the question, \"?\" for those still hidden';

  @override
  String get teamsBuzz => 'Teams buzz';

  @override
  String get onTheDevicesShort => 'On the devices';

  @override
  String get progressOnBigScreen => 'Progress on the big screen';

  @override
  String get rapidDevicesText =>
      'Each item is a statement. Every team picks right or wrong on its device; when you move on, a right pick gets the points.';

  @override
  String get rapidBuzzText =>
      'Teams buzz for each item. A right answer gets the points and moves straight on to the next item.';

  @override
  String statementN(int n) {
    return 'Statement $n';
  }

  @override
  String questionN(int n) {
    return 'Question $n';
  }

  @override
  String get answer => 'Answer';

  @override
  String get remove => 'Remove';

  @override
  String get addStatement => 'Add statement';

  @override
  String get turnOrderLabel => 'Turn order';

  @override
  String get lastStandingText =>
      'One player per team takes turns. You rate each turn: right, wrong (the team is out) or wrong but it stays in. The last team left gets the points.';

  @override
  String get noPrompts => 'No prompts: every turn answers the question itself.';

  @override
  String get onePromptPerTurn => 'One prompt per turn, in this order.';

  @override
  String promptN(int n) {
    return 'Prompt $n';
  }

  @override
  String get addPrompt => 'Add prompt';

  @override
  String get onlyWithDevices =>
      'Only playable with the teams\' own devices: every team needs a phone or tablet connected (Setup, then Connect devices). Without them there is nothing to answer with.';

  @override
  String get matchingEditorText =>
      'Write each pair the way it belongs together; the teams get the right side mixed up. A side can be a text, a picture or both. A picture without text gets a name on the devices, such as \"Picture 3\".';

  @override
  String get matchLeft => 'Left';

  @override
  String get matchBelongsTo => 'Belongs to';

  @override
  String get removePair => 'Remove pair';

  @override
  String get addPair => 'Add pair';

  @override
  String get buzz => 'Buzz';

  @override
  String get typed => 'Typed';

  @override
  String get whiteboard => 'Whiteboard';

  @override
  String get topAnswersBuzzText =>
      'A team buzzes and names an answer. Tap the one it named: it is uncovered and the team gets its points. Then everyone may buzz again.';

  @override
  String get topAnswersTypedText =>
      'Every team types its answers into a list on its device. You tick the ones it found, with suggestions for what it typed.';

  @override
  String get topAnswersWhiteboardText =>
      'Every team writes its answers on a numbered whiteboard. You tick the ones it found.';

  @override
  String get topAnswersListText =>
      'Most popular first. Without its own points an answer is worth the question\'s points. Other spellings to accept go after a /.';

  @override
  String paperName(String paper) {
    String _temp0 = intl.Intl.selectLogic(paper, {
      'lines': 'Ruled',
      'grid': 'Squared',
      'list': 'Numbered list',
      'image': 'Picture',
      'other': 'Blank',
    });
    return '$_temp0';
  }

  @override
  String get connectionsDevicesText =>
      'Every team solves the puzzle on its own device. You see live which groups each team has found.';

  @override
  String get chooseDeviceScreenText =>
      'Choose a screen to open on every team\'s device with the question. You see the answers as they are written and decide when to show them.';

  @override
  String get deviceScreenText =>
      'Opens on every team\'s device with the question. You see the answers as they are written and decide when to show them.';

  @override
  String get buzzer => 'Buzzer';

  @override
  String get nothing => 'Nothing';

  @override
  String get recommended => 'Recommended';

  @override
  String get mistakesAllowed => 'Mistakes allowed';

  @override
  String get paper => 'Paper';

  @override
  String get rows => 'Rows';

  @override
  String get choosePictureToDrawOn => 'Choose the picture to draw on';

  @override
  String get pictureSet => 'Picture set';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String get step => 'Step';

  @override
  String get unit => 'Unit';

  @override
  String get rightValue => 'Right value';

  @override
  String get rightWithin => 'Right within ±';

  @override
  String get noBuzzingAtAll => 'No buzzing at all';

  @override
  String get noBuzzingAtAllText =>
      'Buzzer boxes stay off too, e.g. for estimation questions';

  @override
  String get teamsCanStopEarly => 'Teams can stop early';

  @override
  String get orderEditorText =>
      'Enter the items in the right order. The teams get them shuffled.';

  @override
  String get matchEditorText =>
      'Enter each pair. The teams get the right-hand side shuffled.';

  @override
  String get item => 'Item';

  @override
  String get matchRight => 'Right';

  @override
  String get addItem => 'Add item';

  @override
  String timerSummary(String time) {
    return 'timer $time';
  }

  @override
  String progressSummary(String style) {
    return 'progress: $style';
  }

  @override
  String mistakesAllowedSummary(int count) {
    return '$count mistakes allowed';
  }

  @override
  String get outLoudNoBuzzer => 'Out loud, no buzzer';

  @override
  String get buzzerBoxesOnly => 'Buzzer boxes only';

  @override
  String sliderSummary(String from, String to) {
    return 'Slider $from–$to';
  }

  @override
  String whiteboardSummary(String paper) {
    return 'Whiteboard, $paper';
  }

  @override
  String orderSummary(int count) {
    return 'Put $count in order';
  }

  @override
  String matchSummary(int count) {
    return 'Match $count pairs';
  }

  @override
  String listSummary(int count) {
    return 'Answer list, $count rows';
  }

  @override
  String get rightShort => 'right';

  @override
  String get emptyCard => 'Empty card';

  @override
  String get card => 'Card';

  @override
  String get moveCard => 'Move card';

  @override
  String get off => 'off';

  @override
  String get offerInShow => 'Offer it in the show';

  @override
  String get keepOutOfShow => 'Keep it out of the show';

  @override
  String get edit => 'Edit';

  @override
  String get cardsDialogText =>
      'What you can put over the screen during the show, offered in this order. Tap a card to change it, drag it by its handle to move it, or switch it off to keep it out of the show.';

  @override
  String get newCard => 'New card';

  @override
  String get uploading => 'Uploading…';

  @override
  String get addPicture => 'Add picture';

  @override
  String get title => 'Title';

  @override
  String get text => 'Text';

  @override
  String get videoClip => 'Video clip';

  @override
  String get videoClipText =>
      'A clip plays full screen on the big screen and the card goes when it ends.';

  @override
  String get look => 'Look';

  @override
  String get removeCard => 'Remove card';

  @override
  String get add => 'Add';

  @override
  String get boardMusic => 'Board music';

  @override
  String get calmMusic => 'Calm music';

  @override
  String get thrillingMusic => 'Thrilling music';

  @override
  String get effectRightAnswer => 'Right answer';

  @override
  String get effectWrongAnswer => 'Wrong answer';

  @override
  String get effectQuestionClosed => 'Question closed';

  @override
  String get effectReveal => 'Reveal';

  @override
  String get effectQuestionOpens => 'Question opens';

  @override
  String get effectTeamLocksIn => 'Team locks in';

  @override
  String get effectNextItem => 'Next Fragenhagel item';

  @override
  String get effectLastTenSeconds => 'Last 10 seconds';

  @override
  String get effectTimesUp => 'Time\'s up';

  @override
  String get effectSteal => 'Steal';

  @override
  String get effectFullySolved => 'Fully solved';

  @override
  String appDefault(String sound) {
    return 'App default: $sound';
  }

  @override
  String get asSetAbove => 'As set above';

  @override
  String get silent => 'Silent';

  @override
  String get ownFile => 'Own file';

  @override
  String get ownFileMenu => 'Own file…';

  @override
  String get stop => 'Stop';

  @override
  String get listen => 'Listen';

  @override
  String get soundsGameText =>
      'What plays during this game. Anything not set uses the sounds that come with the app.';

  @override
  String get soundsLevelText =>
      'Anything left on \"As set above\" comes from the board or the game.';

  @override
  String get soundsAtMoments => 'Sounds at moments of the show';

  @override
  String get ownEffects => 'Your own effects';

  @override
  String get addEffect => 'Add effect';

  @override
  String get oggNotSupported =>
      'Ogg sounds do not play on Windows. Please use MP3, WAV or M4A.';

  @override
  String get fileTypeNotSupported => 'This file type is not supported.';

  @override
  String couldNotUploadMedia(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'image': 'Could not upload the picture.',
      'audio': 'Could not upload the sound.',
      'other': 'Could not upload the video.',
    });
    return '$_temp0';
  }

  @override
  String addMedia(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'image': 'Add picture',
      'audio': 'Add sound',
      'other': 'Add video',
    });
    return '$_temp0';
  }

  @override
  String get pictureTooltip =>
      'Picture: tap to see it large, replace or remove it';

  @override
  String get replaceOrRemoveSound => 'Replace or remove the sound';

  @override
  String get videoTooltip => 'Video: tap to watch, replace or remove it';

  @override
  String get sound => 'Sound';

  @override
  String get video => 'Video';

  @override
  String get replace => 'Replace';

  @override
  String get enterRankerUrl =>
      'Enter a ranker.com list URL, e.g. https://www.ranker.com/list/best-smells/jacob-shelton';

  @override
  String rankerError(String kind, Object status) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'page': 'The page could not be loaded ($status).',
      'noList': 'No list was found on that page.',
      'list': 'The list could not be loaded ($status).',
      'items': 'The list items could not be loaded ($status).',
      'other': 'The list has too few entries.',
    });
    return '$_temp0';
  }

  @override
  String get importFailed => 'The import failed.';

  @override
  String get rankerImportText =>
      'The top ten entries of the list replace this question\'s answers.';

  @override
  String get rankerListUrl => 'Ranker list URL';

  @override
  String get import => 'Import';

  @override
  String get addTitle => 'Add title';

  @override
  String get arrowCircle => 'That arrow would go round in a circle.';

  @override
  String screensWide(String count) {
    return '$count screens wide';
  }

  @override
  String get mapTapFirst => 'Tap the bubble that comes first.';

  @override
  String get mapTapNext =>
      'Now tap the bubble it leads to: that adds an arrow, or removes the one already there. Tap the same bubble again to remove every arrow into it.';

  @override
  String get mapDragBubble =>
      'Drag to move. Use − and + below to change this bubble\'s size.';

  @override
  String get mapDragSelected =>
      'Drag to move. Use the buttons below to change or remove it.';

  @override
  String get mapDragAnything =>
      'Drag things to place them. Tap a bubble, title, picture or line to select it.';

  @override
  String get connect => 'Connect';

  @override
  String get line => 'Line';

  @override
  String get narrower => 'Narrower';

  @override
  String get wider => 'Wider';

  @override
  String get tidyUp => 'Tidy up';

  @override
  String get smaller => 'Smaller';

  @override
  String get larger => 'Larger';

  @override
  String get editText => 'Edit text';

  @override
  String get couldNotCreateInvite => 'Could not create the invite link.';

  @override
  String get inviteLinkCopied => 'Invite link copied';

  @override
  String get removeFromGame => 'Remove from game';

  @override
  String get removeFromGameText =>
      'They lose access right away. Revoke any invite link they still have, or they can join again.';

  @override
  String get access => 'Access';

  @override
  String get members => 'Members';

  @override
  String get you => 'You';

  @override
  String get accessExplanation =>
      'Full access edits everything. Limited access only sees categories they created or were given, so they can write questions and still play along.';

  @override
  String get inviteLinks => 'Invite links';

  @override
  String get noInviteLinksYet => 'No invite links yet';

  @override
  String get expired => 'Expired';

  @override
  String get valid => 'Valid';

  @override
  String validFor(String time) {
    return 'Valid for $time';
  }

  @override
  String get copyLink => 'Copy link';

  @override
  String get revoke => 'Revoke';

  @override
  String newRoleLink(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'admin': 'New admin link',
      'full': 'New full access link',
      'other': 'New limited access link',
    });
    return '$_temp0';
  }

  @override
  String get inviteLinksText =>
      'Anyone with a link can join until it expires or you revoke it.';

  @override
  String hourCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String dayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get notAnInviteLink => 'That doesn\'t look like an invite link.';

  @override
  String get inviteGone => 'This invite link no longer exists.';

  @override
  String get inviteExpired => 'This invite link has expired.';

  @override
  String get couldNotCheckInvite => 'Could not check the invite link.';

  @override
  String get couldNotJoinGame =>
      'Could not join. You may already be a member, or the link was revoked.';

  @override
  String get joinAGame => 'Join a game';

  @override
  String get inviteLink => 'Invite link';

  @override
  String get unnamedGame => 'Unnamed game';

  @override
  String youWillJoinWith(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'admin': 'You will join with admin.',
      'full': 'You will join with full access.',
      'other': 'You will join with limited access.',
    });
    return '$_temp0';
  }

  @override
  String get continueLabel => 'Continue';

  @override
  String get join => 'Join';

  @override
  String get couldNotCreateSession => 'Could not create the session.';

  @override
  String get presentHere => 'Present here';

  @override
  String get presentHereText =>
      'Another of your devices was presenting this session last. It stops if it is still running.';

  @override
  String get deleteSession => 'Delete session';

  @override
  String deleteSessionText(String game) {
    return 'The session of \"$game\" with its teams and points will be deleted.';
  }

  @override
  String get joinSessionScan => 'Join a session: scan its code';

  @override
  String get joinSessionLink => 'Join a session with its link';

  @override
  String get newSession => 'New session';

  @override
  String get couldNotLoadSessions => 'Could not load your sessions.';

  @override
  String get noSessionsText =>
      'A session is one evening\'s show: its teams, points and progress. Create one, present it on the big screen and control it from your phone.';

  @override
  String get changeGame => 'Change game';

  @override
  String createdAt(String date) {
    return 'Created $date';
  }

  @override
  String get present => 'Present';

  @override
  String get control => 'Control';

  @override
  String get setUpTeamsAndBuzzers => 'Set up teams and buzzers';

  @override
  String get chooseAGame => 'Choose a game';

  @override
  String get gameYouCannotOpen => 'A game you cannot open';

  @override
  String get noGamesForSession =>
      'You have no games yet. Create one in the Games tab first.';

  @override
  String get game => 'Game';

  @override
  String get createWithoutGame => 'Create without a game';

  @override
  String get create => 'Create';

  @override
  String get didNotReachPresenter => 'That did not reach the presenter.';

  @override
  String get noDevicePresenting =>
      'No device is presenting this session. Nothing you do here happens until one presents it.';

  @override
  String get presentingElsewhere => 'Presenting elsewhere';

  @override
  String get presentingElsewhereText =>
      'Another of your devices took over this session.';

  @override
  String get couldNotOpenWindow => 'Could not open a second window.';

  @override
  String get couldNotStartPresenting =>
      'Could not start presenting this session.';

  @override
  String get controlling => 'Controlling';

  @override
  String get closePresenterWindow => 'Close presenter window';

  @override
  String get stopPresenting => 'Stop presenting';

  @override
  String get openInNewWindow =>
      'Open in a new window, to drag onto another screen';

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get controls => 'Controls';

  @override
  String get buzzerBoxRetrying => 'Buzzer box not connected · retrying';

  @override
  String mediaNotDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count media files could not be downloaded',
      one: '1 media file could not be downloaded',
    );
    return '$_temp0';
  }

  @override
  String get couldNotSaveChange => 'Could not save the change.';

  @override
  String setUpTitle(String title) {
    return 'Set up $title';
  }

  @override
  String get couldNotLoadSession => 'Could not load the session.';

  @override
  String get setUpFromControl =>
      'If this session is on a screen right now, set it up from Control instead: the presenting device keeps its own teams.';

  @override
  String get teams => 'Teams';

  @override
  String get noTeamsYet => 'No teams yet';

  @override
  String get queueBuzzers => 'Queue buzzers';

  @override
  String get queueBuzzersText => 'Later buzzes line up behind the first';

  @override
  String get buzzerTest => 'Buzzer test';

  @override
  String get buzzerTestText =>
      'Buzzers light up their team; only from the board';

  @override
  String get buzzerBoxAndSounds => 'Buzzer box and team sounds';

  @override
  String get buzzerBoxAndSoundsText =>
      'The USB buzzer box, and the sound each team buzzes with';

  @override
  String get connectDevices => 'Connect devices';

  @override
  String get connectDevicesText => 'Phones as buzzers, or another controller';

  @override
  String get newTeam => 'New team';

  @override
  String get renameTeam => 'Rename team';

  @override
  String get removeTeam => 'Remove team';

  @override
  String removeTeamText(String team) {
    return '\"$team\" and its points will be removed.';
  }

  @override
  String get addTeam => 'Add team';

  @override
  String get noTeamsYetText =>
      'No teams yet. Add them here, or let them join with a code.';

  @override
  String get couldNotCreateCodes => 'Could not create the codes.';

  @override
  String get controller => 'Controller';

  @override
  String get scanToControl =>
      'Scan in Quiz Studio to control this session from another device. That device must be signed in with an account that can open the game.';

  @override
  String scanToBuzz(String team) {
    return 'Scan in Quiz Studio to use a phone as the buzzer of $team.';
  }

  @override
  String get devicesViaInternet => 'Devices connect through the internet.';

  @override
  String get devicesViaLan =>
      'Devices on this network connect directly; others through the internet.';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get copyLinkInstead => 'Copy link instead';

  @override
  String get addTeamsFirst => 'Add teams first to get a buzzer code for each.';

  @override
  String get teamRemoved => 'This team was removed.';

  @override
  String get buzzForTeam => 'Buzz for this team';

  @override
  String get setPoints => 'Set points';

  @override
  String get sessionHasNoGame => 'This session has no game yet.';

  @override
  String get statusBoard => 'Board';

  @override
  String get statusBetsShown =>
      'The bets are on the big screen · start the question when ready';

  @override
  String statusBetting(int placed, int total) {
    return 'Teams are betting · $placed of $total bets in';
  }

  @override
  String get statusRapidDevices => 'Teams pick right or wrong on their devices';

  @override
  String get statusAmountBet => 'Teams go for the number they bet';

  @override
  String get statusOpenNoBuzzers => 'Question open · no buzzers';

  @override
  String get statusOpenWaiting => 'Question open · waiting for a buzz';

  @override
  String statusAnswering(String team) {
    return '$team is answering';
  }

  @override
  String statusAnsweringThen(String team, String next) {
    return '$team is answering · then $next';
  }

  @override
  String get statusAnswerRevealed => 'Answer revealed';

  @override
  String get noGamePicked =>
      'No game picked yet. Choose one for this session in the sessions list.';

  @override
  String get groupHasNoQuestions => 'This group has no questions.';

  @override
  String questionsPlayed(int played, int total) {
    return '$played of $total questions played';
  }

  @override
  String get teamsBetTheirPoints => 'teams bet their points';

  @override
  String betQuestionShown(String prompt) {
    return 'Bet question: $prompt';
  }

  @override
  String get enlargedImage => 'Enlarged image';

  @override
  String get noStrikes => 'No strikes';

  @override
  String get strikes => 'Strikes';

  @override
  String get resetStrikes => 'Reset strikes';

  @override
  String get buzzBeforeUncover =>
      'A team has to buzz before answers can be uncovered.';

  @override
  String betFor(String team) {
    return 'Bet for $team';
  }

  @override
  String betRange(int limit) {
    return '0 to $limit points';
  }

  @override
  String get betsTapTeam => 'Bets · tap a team to enter its bet';

  @override
  String get bets => 'Bets';

  @override
  String upTo(int limit) {
    return 'up to $limit';
  }

  @override
  String get noBet => 'no bet';

  @override
  String get allPointsGiven => 'All points given';

  @override
  String get givePoints => 'Give points';

  @override
  String givePointsToTeams(int count) {
    return 'Give points to $count teams';
  }

  @override
  String get given => 'Given';

  @override
  String get notGivenYet => 'Not given yet';

  @override
  String givenSoFar(String points) {
    return 'Given $points so far';
  }

  @override
  String get takeOutOfOrder => 'Take out of the order';

  @override
  String get putNextInOrder => 'Put next in order';

  @override
  String pointsFor(String team) {
    return 'Points for $team';
  }

  @override
  String get pointsForQuestion => 'Points for this question';

  @override
  String get didTeamsReach => 'Did each team reach its number?';

  @override
  String tapInOrder(String points, int step) {
    return 'Tap the teams in order as they finish · $points, then $step less each';
  }

  @override
  String get rateEachTeam => 'Rate each team';

  @override
  String goal(int goal) {
    return 'goal $goal';
  }

  @override
  String get otherPoints => 'Other points';

  @override
  String get otherPointsMenu => 'Other points…';

  @override
  String get reached => 'Reached';

  @override
  String get missed => 'Missed';

  @override
  String get pointsForAnswer => 'Points for this answer';

  @override
  String teamWins(String team, int points) {
    return '$team wins · +$points';
  }

  @override
  String teamsTurn(String team) {
    return '$team\'s turn';
  }

  @override
  String get nobodyLeft => 'Nobody left';

  @override
  String get noPromptsLeft => 'No prompts left';

  @override
  String get undo => 'Undo';

  @override
  String get rapidNoItems => 'This Fragenhagel has no items yet.';

  @override
  String answerShown(String answer) {
    return 'Answer: $answer';
  }

  @override
  String allDone(int count) {
    return 'All $count done';
  }

  @override
  String itemOf(int item, int count) {
    return 'Item $item of $count';
  }

  @override
  String get topAnswersEmpty => 'This question has no answers on its list yet.';

  @override
  String get topTapToUncover =>
      'Tap an answer to uncover it on the big screen.';

  @override
  String topTapNamed(String team) {
    return 'Tap the answer $team named. Wrong if it is not on the list.';
  }

  @override
  String get topWhenBuzz => 'When a team buzzes, tap the answer it names.';

  @override
  String get revealGroupNow => 'Reveal a group now?';

  @override
  String get revealGroupNowText =>
      'The teams are still playing and will see this group on their devices too. Their time keeps running.';

  @override
  String get reveal => 'Reveal';

  @override
  String get stealWorked => 'Steal worked';

  @override
  String get stealFailed => 'Steal failed';

  @override
  String get strike => 'Strike';

  @override
  String get hide => 'Hide';

  @override
  String get betsAreIn => 'Bets are in';

  @override
  String get startQuestion => 'Start question';

  @override
  String get showAnswer => 'Show answer';

  @override
  String get finish => 'Finish';

  @override
  String get nextItem => 'Next item';

  @override
  String get solution => 'Solution';

  @override
  String get revealGroup => 'Reveal group';

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Play';

  @override
  String get nextTeam => 'Next team';

  @override
  String get reopen => 'Reopen';

  @override
  String get tabBoard => 'Board';

  @override
  String get tabEffects => 'Effects';

  @override
  String get tabAnswers => 'Answers';

  @override
  String get tabSetup => 'Setup';

  @override
  String get ungrouped => 'Ungrouped';

  @override
  String get groupHasNoCategories => 'This group has no categories.';

  @override
  String get showCategoryInMiddle => 'Show this category in the middle';

  @override
  String get tapFieldToRead => 'Tap a field to read its question.';

  @override
  String get onScreen => 'on screen';

  @override
  String get played => 'played';

  @override
  String get takeOffKeepPlayable => 'Take off screen, keep playable';

  @override
  String get markNotPlayed => 'Mark as not played';

  @override
  String get openQuestion => 'Open question';

  @override
  String get slotBoard => 'Board';

  @override
  String get slotCalm => 'Calm';

  @override
  String get slotThrilling => 'Thrilling';

  @override
  String get effectClosed => 'Closed';

  @override
  String get effectLockedIn => 'Locked in';

  @override
  String get effectCountdown => 'Countdown';

  @override
  String get effectFanfare => 'Fanfare';

  @override
  String get onScreenHeader => 'On screen';

  @override
  String get animation => 'Animation';

  @override
  String get noCardsPrepare => 'No cards. Prepare some in the editor.';

  @override
  String get textToShow => 'Text to show';

  @override
  String get show => 'Show';

  @override
  String get noCardOnScreen => 'No card on screen';

  @override
  String get takeCardOff => 'Take card off screen';

  @override
  String get keepSpeakersAwake => 'Keep speakers awake';

  @override
  String get fewerDetails => 'Fewer details';

  @override
  String get whatIsThis => 'What is this?';

  @override
  String get keepSpeakersAwakeText =>
      'Many speakers switch themselves off after a few minutes of silence and miss the start of the next sound. This plays a very quiet noise whenever nothing else plays; music and question sounds take over as they start.';

  @override
  String get softNoise => 'Soft noise';

  @override
  String get whiteNoise => 'White noise';

  @override
  String noiseVolume(int volume) {
    return 'Noise $volume %';
  }

  @override
  String get soundEffects => 'Sound effects';

  @override
  String get questionSound => 'Question sound';

  @override
  String get answersOnDevices => 'Answers on the teams\' devices';

  @override
  String get openAQuestionFirst => 'Open a question first.';

  @override
  String get answersOnDevicesText =>
      'Every team answers on its own device. You see the answers as they come in; the audience only when you show them.';

  @override
  String get preparedScreensText =>
      'Sliders, sorting, matching and prepared whiteboards are set up per question in the editor and start by themselves.';

  @override
  String get roundOpen => 'open';

  @override
  String get roundLocked => 'locked';

  @override
  String answersIn(int count, int total) {
    return '$count of $total in';
  }

  @override
  String get lockAll => 'Lock all';

  @override
  String get letThemEditAgain => 'Let them edit again';

  @override
  String get showAll => 'Show all';

  @override
  String get rateAutomatically => 'Rate automatically';

  @override
  String get givePointsForGroups => 'Give points for groups';

  @override
  String get discard => 'Discard';

  @override
  String solutionShown(String solution) {
    return 'Solution: $solution';
  }

  @override
  String partialRight(int right, int total) {
    return '$right of $total right';
  }

  @override
  String get looksRight => 'Looks right';

  @override
  String get looksWrong => 'Looks wrong';

  @override
  String get takeOffScreen => 'Take off screen';

  @override
  String get showOnScreen => 'Show on screen';

  @override
  String halfPoints(int points) {
    return 'Half points (+$points)';
  }

  @override
  String outPlaceLabel(String place) {
    return '$place out';
  }

  @override
  String get waitingForGame => 'Waiting for a game…';

  @override
  String betValue(int bet) {
    return 'Bet $bet';
  }

  @override
  String goalValue(int goal) {
    return 'Goal $goal';
  }

  @override
  String get howManyCanYouDo => 'How many can you do?';

  @override
  String get theBets => 'The bets';

  @override
  String get placeYourBets => 'Place your bets';

  @override
  String get betRule => 'Right wins your bet, wrong loses it';

  @override
  String amountRuleWithMinus(int plus, int minus) {
    return 'Reach your number: $plus points for each one · miss it: −$minus for each';
  }

  @override
  String amountRule(int plus) {
    return 'Reach your number: $plus points for each one';
  }

  @override
  String get findFourGroups => 'Find four groups of four';

  @override
  String get isLastTeamStanding => 'is the last team standing';

  @override
  String get thatWasTheLastOne => 'That was the last one!';

  @override
  String thenTeams(String teams) {
    return 'then $teams';
  }

  @override
  String get noColour => 'No colour';

  @override
  String get useThisColour => 'Use this colour';

  @override
  String get presenterWindowTitle => 'Quiz Studio · Presenter';

  @override
  String get reconnectingMainWindow => 'Reconnecting to the main window…';

  @override
  String get connectingMainWindow => 'Connecting to the main window…';

  @override
  String get leaveFullScreen => 'Leave full screen (Esc)';

  @override
  String get fullScreenF11 => 'Full screen (F11)';

  @override
  String get dragToProjector =>
      'Drag this window to the projector, then double-click it or press F11 for full screen.';

  @override
  String pictureLabel(String label) {
    return 'Picture $label';
  }

  @override
  String get yourAnswer => 'Your answer';

  @override
  String get slideToAnswer => 'Slide to answer';

  @override
  String get dragIntoOrder => 'Drag into the right order';

  @override
  String foundOfFour(int count) {
    return '$count of 4 found';
  }

  @override
  String mistakeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mistakes',
      one: '1 mistake',
    );
    return '$_temp0';
  }

  @override
  String get yourPairs => 'Your pairs';

  @override
  String tapWhereItGoes(String item) {
    return 'Now tap where “$item” goes';
  }

  @override
  String get allPlacedSwap => 'All placed · drag to swap';

  @override
  String get dragOntoPartner => 'Drag each answer onto its partner';

  @override
  String get dropToTakeBack => 'Drop here to take it back';

  @override
  String get allPlaced => 'All placed';

  @override
  String get praisePerfect => 'Perfect!';

  @override
  String get praiseGreat => 'Great!';

  @override
  String get praiseNice => 'Nice!';

  @override
  String get praiseSolid => 'Solid!';

  @override
  String get allFourFound => 'All four found!';

  @override
  String get noTriesLeft => 'No tries left';

  @override
  String get oneAway => 'One away…';

  @override
  String get notAGroup => 'Not a group';

  @override
  String get alreadyGuessed => 'Already guessed';

  @override
  String get allFourGroupsFound => 'All four groups found';

  @override
  String get noTriesLeftWait => 'No tries left. Wait for the solution';

  @override
  String lockedInWith(int count) {
    return 'Locked in with $count of 4';
  }

  @override
  String get timeIsUp => 'Time is up';

  @override
  String get mistakesRemaining => 'Mistakes remaining:';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get submit => 'Submit';

  @override
  String get wereDone => 'We\'re done';

  @override
  String get clear => 'Clear';

  @override
  String get notASessionCode => 'That is not a Quiz Studio session code.';

  @override
  String get couldNotJoinSession =>
      'Could not join. The code may no longer be valid.';

  @override
  String get session => 'Session';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int count) {
    return '$count minutes ago';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get rejoinAsTeam => 'Rejoin as a team\'s device';

  @override
  String get rejoinAsController => 'Rejoin as controller';

  @override
  String joinedAgo(String ago) {
    return 'Joined $ago';
  }

  @override
  String get joinLink => 'Join link';

  @override
  String get orPasteLink => 'Or paste the link';

  @override
  String get joinTerms =>
      'By joining you agree to the terms and privacy policy. No account or name needed.';

  @override
  String get joinASession => 'Join a session';

  @override
  String get pasteJoinLinkHelp =>
      'Open \"Connect devices\" on the presenting device, copy the join link there and paste it here.';

  @override
  String get didNotGetThrough => 'That did not get through.';

  @override
  String get couldNotReachSession => 'Could not reach this session.';

  @override
  String get waitingForShow => 'Waiting for the show to start…';

  @override
  String get teamRemovedFromSession =>
      'Your team was removed from the session.';

  @override
  String get youAreLastTeam => 'You are the last team standing!';

  @override
  String teamWinsShort(String team) {
    return '$team wins';
  }

  @override
  String get youAreOut => 'You are out';

  @override
  String get yourTurn => 'Your turn!';

  @override
  String get buzzerTestPress => 'Buzzer test: press to check';

  @override
  String get waitingForNextQuestion => 'Waiting for the next question';

  @override
  String yourGoal(int goal) {
    return 'Your goal: $goal';
  }

  @override
  String get goalReached => 'Goal reached!';

  @override
  String get goalMissed => 'Goal missed';

  @override
  String get buzzOnBox => 'Buzz on the buzzer box';

  @override
  String get buzzWhenYouKnow => 'Buzz when you know it!';

  @override
  String get noBuzzersForQuestion => 'No buzzers for this question';

  @override
  String numberInLine(int n) {
    return 'You are number $n in line';
  }

  @override
  String get anotherTeam => 'Another team';

  @override
  String get needsNewerVersion =>
      'This question needs a newer version of Quiz Studio. Please update the app.';

  @override
  String get answerHere => 'Answer here';

  @override
  String get answerBeingShown => 'Your answer is being shown';

  @override
  String get lockedInWaiting => 'Locked in, waiting for the others';

  @override
  String get answersAreIn => 'Answers are in';

  @override
  String pointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String betShort(int bet) {
    return 'bet $bet';
  }

  @override
  String get rightExclaim => 'Right!';

  @override
  String get notThisTime => 'Not this time';

  @override
  String get answerCountsWhenEnded =>
      'Your answer counts as it stands when the gamemaster ends the round.';

  @override
  String get answerCountsWhenTimeUp =>
      'Your answer counts as it stands when the time is up.';

  @override
  String get lockedIn => 'Locked in';

  @override
  String lockedInAfter(String seconds) {
    return 'Locked in after $seconds s';
  }

  @override
  String get lockInAnswer => 'Lock in answer';

  @override
  String get answerFirst => 'Answer first';

  @override
  String get answerOnBigScreen => 'Your answer is on the big screen.';

  @override
  String get gettingPicture => 'Getting the picture…';

  @override
  String get connectedLan => 'Connected over the local network';

  @override
  String get connectedInternet => 'Connected through the internet';

  @override
  String yourBetOn(String category) {
    return 'Your bet on $category';
  }

  @override
  String get placeYourBet => 'Place your bet';

  @override
  String get theGoals => 'The goals';

  @override
  String betOutcome(int value) {
    return 'Right: +$value · Wrong: −$value';
  }

  @override
  String amountOutcomeWithMinus(int win, int lose) {
    return 'If successful: +$win · Missed: −$lose';
  }

  @override
  String amountOutcome(int win) {
    return 'If successful: +$win';
  }

  @override
  String get betNothing => 'Nothing';

  @override
  String get betHalf => 'Half';

  @override
  String get allIn => 'All in';

  @override
  String get questionStartsSoon => 'The question starts in a moment';

  @override
  String get betPlaced => 'Bet placed';

  @override
  String changeTo(int value) {
    return 'Change to $value';
  }

  @override
  String betAction(int value) {
    return 'Bet $value';
  }

  @override
  String get buzzerSoundTooBig =>
      'This file is too big; a buzzer sound can be up to 5 MB.';

  @override
  String get notASoundFile => 'This is not a sound file the app can play.';

  @override
  String get couldNotUploadBuzzerSound =>
      'Could not upload the sound. The team keeps the one it had.';

  @override
  String get buzzers => 'Buzzers';

  @override
  String get useUsbBox => 'Use a USB buzzer box';

  @override
  String get useUsbBoxText =>
      'Off: teams buzz with their phones only, and the big screen does not look for a box.';

  @override
  String get usbBoxPlatforms =>
      'A USB buzzer box works on Windows, macOS and Linux. Phones and tablets can still be buzzers: see Connect devices.';

  @override
  String get buzzerSounds => 'Buzzer sounds';

  @override
  String get buzzerSoundsText =>
      'Saved with the session and played by whichever device presents. Until that device has fetched a sound, and for teams without one, the built-in buzzer plays.';

  @override
  String get ownSound => 'Own sound';

  @override
  String get chooseBuzzerSound => 'Choose a buzzer sound';

  @override
  String get uploadOwnSound => 'Upload own sound…';

  @override
  String get choose => 'Choose';

  @override
  String get backToBuiltinBuzzer => 'Back to the built-in buzzer';

  @override
  String get addTeamsFirstShort => 'Add teams first.';

  @override
  String get test => 'Test';

  @override
  String get clearOrder => 'Clear order';

  @override
  String get calibrate => 'Calibrate';

  @override
  String get buzzersAppearHere =>
      'Buzzers appear here as soon as the box sends readings.';

  @override
  String get pressTheBuzzers =>
      'Press the buzzers. Each lights up while it is held, and the numbers show who was first. Tap one to change its team or sensitivity.';

  @override
  String get assignAllByPressing => 'Assign all by pressing';

  @override
  String pressBuzzerOf(String team) {
    return 'Press the buzzer of $team now';
  }

  @override
  String moreToGo(int count) {
    return '$count more to go';
  }

  @override
  String get defaultAssignment =>
      'Without anything assigned, buzzer 1 is the first team, buzzer 2 the second, and so on.';

  @override
  String get noBuzzer => 'No buzzer';

  @override
  String buzzerN(int n) {
    return 'Buzzer $n';
  }

  @override
  String get assignByPressing => 'Assign by pressing';

  @override
  String get addTeamsInSessionFirst => 'Add teams in the session first.';

  @override
  String get rawData => 'Raw data';

  @override
  String get rawDataText => 'Exactly what the box sends, for finding faults';

  @override
  String get nothingReceivedYet => 'Nothing received yet.';

  @override
  String get notConnectedDot => 'Not connected.';

  @override
  String get team => 'Team';

  @override
  String get byPosition => 'By position';

  @override
  String get howHardPressed => 'How hard it has to be pressed';

  @override
  String readingThreshold(int value, int threshold) {
    return 'Reading $value · counts as pressed above $threshold';
  }

  @override
  String get noBuzzerPressedClearly => 'No buzzer was pressed clearly.';

  @override
  String calibratedBuzzers(int count) {
    return 'Calibrated $count buzzers.';
  }

  @override
  String get connected => 'Connected';

  @override
  String readingsPerSecond(int rate, String uptime) {
    return '$rate readings per second · up $uptime';
  }

  @override
  String reconnectedTimes(int count) {
    return 'reconnected $count×';
  }

  @override
  String get boxSilent => 'Open, but the box is not sending';

  @override
  String get boxSilentText =>
      'Trying again every few seconds. Is it the right port, and is the box powered?';

  @override
  String get notConnectedShort => 'Not connected';

  @override
  String get boxDisconnectedText =>
      'Trying again every few seconds. Plug the box in; nothing needs to be pressed here.';

  @override
  String get choosePort => 'Choose the port of the buzzer box';

  @override
  String get rememberedOnDevice => 'It is remembered on this device.';

  @override
  String get noSerialPorts => 'No serial ports on this device';

  @override
  String get port => 'Port';

  @override
  String get reconnectNow => 'Reconnect now';

  @override
  String get noTeam => 'No team';

  @override
  String get pressEveryBuzzer =>
      'Now press every buzzer once, as hard as a player would.';

  @override
  String get handsOff => 'Hands off all buzzers for a moment…';

  @override
  String get waitingFirstPress => 'Waiting for the first press.';

  @override
  String gotBuzzers(String buzzers) {
    return 'Got buzzer $buzzers.';
  }

  @override
  String get yourNumber => 'Your number';

  @override
  String get confetti => 'Confetti';

  @override
  String get flash => 'Flash';

  @override
  String get fireworks => 'Fireworks';

  @override
  String get balloons => 'Balloons';

  @override
  String get stars => 'Stars';

  @override
  String get spotlight => 'Spotlight';

  @override
  String get editTitle => 'Edit title';

  @override
  String get noPicture => 'No picture';

  @override
  String get noMusic => 'No music';

  @override
  String get firstItem => 'First item';

  @override
  String get rapidIntro =>
      'The question first: read it out, then Next brings up item 1';

  @override
  String hintShown(String hint) {
    return 'Hint: $hint';
  }

  @override
  String get byClosenessShort => 'by closeness';

  @override
  String byClosenessSummary(int plus, int step) {
    return 'By closeness · $plus, then −$step per place';
  }

  @override
  String get scoringClosenessText =>
      'The team whose number is nearest the right value gets the most points, each place after it a bit less. Teams equally near share a place. The places count once the answering is closed, and the big screen shows them with the answers.';

  @override
  String get scoringClosenessNoSolution =>
      'Places go by how near each number is to the solution, so give the slider or number a right value under How teams answer.';

  @override
  String placeN(String place) {
    return '$place place';
  }

  @override
  String get statusRapidIntro => 'Question open · read it out first';

  @override
  String get pickSeveral => 'Teams can pick several';

  @override
  String get pickSeveralText =>
      'For questions with more than one right answer: right only when a team picks exactly the right ones';

  @override
  String get explainOrdering =>
      'Put in order: entries such as inventions, films or cities that every team sorts on its device, e.g. by year. The big screen shows them mixed up, then puts them in place one by one.';

  @override
  String get orderingEditorText =>
      'Write the entries in the right order, first to last; drag them to change it. Each can be a text, a picture or both, plus what it\'s sorted by (a year, a size), which appears as the entry is put in place.';

  @override
  String get orderEntry => 'Entry';

  @override
  String get orderValue => 'Sorted by (optional)';

  @override
  String get orderValueHint => 'e.g. 1969';

  @override
  String get removeEntry => 'Remove entry';

  @override
  String get addEntry => 'Add entry';

  @override
  String get orderScoringTitle => 'Points for';

  @override
  String orderScoring(String rule) {
    String _temp0 = intl.Intl.selectLogic(rule, {
      'exact': 'Exact order',
      'pairs': 'Per pair',
      'other': 'Per place',
    });
    return '$_temp0';
  }

  @override
  String orderScoringText(String rule) {
    String _temp0 = intl.Intl.selectLogic(rule, {
      'exact': 'All points for the exact order, none otherwise.',
      'pairs':
          'A share for every two entries the right way round. One entry in the wrong spot costs only a little.',
      'other': 'A share for every entry in its right place.',
    });
    return '$_temp0';
  }

  @override
  String get rightOrder => 'Right order';

  @override
  String get placeNext => 'Place next';

  @override
  String partialPairs(int right, int total) {
    return '$right of $total pairs right';
  }

  @override
  String get testOnThisComputer => 'Test on this computer';

  @override
  String get testDevices => 'Test devices';

  @override
  String get bot => 'Bot';

  @override
  String get allBots => 'All bots';

  @override
  String get noBots => 'No bots';

  @override
  String get whoAnswers => 'Who answers';

  @override
  String get notes => 'Notes';

  @override
  String get roundForOtherTeams => 'This round is for other teams';

  @override
  String get nextPair => 'Next pair';

  @override
  String get moreTime => 'More time';

  @override
  String get noTimeLimit => 'No time limit';

  @override
  String get notesText =>
      'Chosen teams get a notes field on their devices, next to whatever they answer, e.g. to estimate for a bonus. You read the notes here.';

  @override
  String get script => 'Script';

  @override
  String get scriptSummary => 'Your notes for the show';

  @override
  String get scriptExplain =>
      'Your notes for the show, read on the controller. The lines between the sections follow the game: what you write under a question stays with it. Format with the buttons above, or type **bold**, *italic*, # heading or - point.';

  @override
  String get scriptWriteHere => 'Write here…';

  @override
  String get scriptIntro => 'Start';

  @override
  String scriptCategory(String name) {
    return 'Category: $name';
  }

  @override
  String scriptQuestion(String name) {
    return 'Question: $name';
  }

  @override
  String get scriptBold => 'Bold';

  @override
  String get scriptItalic => 'Italic';

  @override
  String get scriptHeading => 'Heading';

  @override
  String get scriptSubheading => 'Subheading';

  @override
  String get scriptBullet => 'Bullet point';

  @override
  String get scriptColour => 'Colour';

  @override
  String get scriptClearFormat => 'Clear formatting';

  @override
  String get scriptNotSaved =>
      'Not saved. Check the connection; the text stays here.';

  @override
  String get scriptToCurrent => 'Current';

  @override
  String get scriptEmpty =>
      'No script yet. Write it in the game editor under Script.';
}
