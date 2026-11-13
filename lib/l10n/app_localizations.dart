import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz Studio'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @thatDidntWork.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work.'**
  String get thatDidntWork;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @navGames.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get navGames;

  /// No description provided for @navSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get navSessions;

  /// No description provided for @couldNotOpenStore.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the store'**
  String get couldNotOpenStore;

  /// No description provided for @downloadPage.
  ///
  /// In en, this message translates to:
  /// **'download page'**
  String get downloadPage;

  /// No description provided for @updateRequired.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequired;

  /// No description provided for @updateRequiredText.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is no longer supported. Please update to continue.'**
  String get updateRequiredText;

  /// No description provided for @installedAndRequired.
  ///
  /// In en, this message translates to:
  /// **'Installed {installed} · required {required}'**
  String installedAndRequired(String installed, String required);

  /// No description provided for @openStore.
  ///
  /// In en, this message translates to:
  /// **'Open {store}'**
  String openStore(String store);

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @theNameOthersSee.
  ///
  /// In en, this message translates to:
  /// **'The name others see'**
  String get theNameOthersSee;

  /// No description provided for @nameLength.
  ///
  /// In en, this message translates to:
  /// **'A name needs between {min} and {max} characters.'**
  String nameLength(int min, int max);

  /// No description provided for @addEmailAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Add email and password'**
  String get addEmailAndPassword;

  /// No description provided for @upgradeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your games stay with this account. Afterwards you can sign in to it on your other devices.'**
  String get upgradeSubtitle;

  /// No description provided for @upgradeDone.
  ///
  /// In en, this message translates to:
  /// **'Done. This account now has an email address.'**
  String get upgradeDone;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutGuestWarning.
  ///
  /// In en, this message translates to:
  /// **'You are signed in as a guest. Signing out loses this account and the games only it can access. Add an email address first to keep them.'**
  String get signOutGuestWarning;

  /// No description provided for @signOutInfo.
  ///
  /// In en, this message translates to:
  /// **'You can sign in again with your email address and password.'**
  String get signOutInfo;

  /// No description provided for @deletingAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account…'**
  String get deletingAccount;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account and its data are deleted.'**
  String get accountDeleted;

  /// No description provided for @accountNotDeletedConnection.
  ///
  /// In en, this message translates to:
  /// **'The account could not be deleted. Check the connection and try again.'**
  String get accountNotDeletedConnection;

  /// No description provided for @nameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The name other players and co-authors see'**
  String get nameSubtitle;

  /// No description provided for @guestAccount.
  ///
  /// In en, this message translates to:
  /// **'Guest account'**
  String get guestAccount;

  /// No description provided for @guestAccountText.
  ///
  /// In en, this message translates to:
  /// **'Your games live only on this device\'s account. Add an email address and password to keep them safe and to sign in on your other devices, for example the PC that presents and the phone that controls.'**
  String get guestAccountText;

  /// No description provided for @emailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with this address on your other devices'**
  String get emailSubtitle;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile, your own games and your sessions'**
  String get deleteAccountSubtitle;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @contactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback, bug reports and feature requests'**
  String get contactSubtitle;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get terms;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @aboutAndLicences.
  ///
  /// In en, this message translates to:
  /// **'About and licences'**
  String get aboutAndLicences;

  /// No description provided for @soundCredits.
  ///
  /// In en, this message translates to:
  /// **'Sound credits'**
  String get soundCredits;

  /// No description provided for @soundCreditsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where the built-in sounds are from'**
  String get soundCreditsSubtitle;

  /// No description provided for @deleteAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountQuestion;

  /// No description provided for @deleteAccountText.
  ///
  /// In en, this message translates to:
  /// **'This deletes your profile, the games only you are in, with their pictures and sounds, and the sessions you host. Games you share stay with the others; if you are their only admin, a co-author becomes admin. This cannot be undone.'**
  String get deleteAccountText;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @wrongPassword.
  ///
  /// In en, this message translates to:
  /// **'That password is not right.'**
  String get wrongPassword;

  /// No description provided for @tooManyTries.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait a moment and try again.'**
  String get tooManyTries;

  /// No description provided for @requiresRecentLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign out, sign in again and then delete the account.'**
  String get requiresRecentLogin;

  /// No description provided for @noConnectionTryOnline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again when you are online.'**
  String get noConnectionTryOnline;

  /// No description provided for @accountNotDeleted.
  ///
  /// In en, this message translates to:
  /// **'The account could not be deleted. Try again.'**
  String get accountNotDeleted;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get languageSystem;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'You are not signed in.'**
  String get notSignedIn;

  /// No description provided for @emailInUse.
  ///
  /// In en, this message translates to:
  /// **'There is already an account with this email address. Sign in to that one instead.'**
  String get emailInUse;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'That is not a valid email address.'**
  String get invalidEmail;

  /// No description provided for @weakPassword.
  ///
  /// In en, this message translates to:
  /// **'Please choose a stronger password.'**
  String get weakPassword;

  /// No description provided for @alreadyHasEmail.
  ///
  /// In en, this message translates to:
  /// **'This account already has an email address.'**
  String get alreadyHasEmail;

  /// No description provided for @restartAndRetry.
  ///
  /// In en, this message translates to:
  /// **'For safety, please restart the app and try again.'**
  String get restartAndRetry;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'You\'re not connected to the internet.'**
  String get notConnected;

  /// No description provided for @emailSignInOff.
  ///
  /// In en, this message translates to:
  /// **'Email sign-in is switched off for this app.'**
  String get emailSignInOff;

  /// No description provided for @didNotWorkTryAgain.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Please try again.'**
  String get didNotWorkTryAgain;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get unknownUser;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordMinLength;

  /// No description provided for @passwordUppercase.
  ///
  /// In en, this message translates to:
  /// **'An uppercase letter'**
  String get passwordUppercase;

  /// No description provided for @passwordLowercase.
  ///
  /// In en, this message translates to:
  /// **'A lowercase letter'**
  String get passwordLowercase;

  /// No description provided for @passwordNumber.
  ///
  /// In en, this message translates to:
  /// **'A number'**
  String get passwordNumber;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match.'**
  String get passwordsDontMatch;

  /// No description provided for @featureBuildTitle.
  ///
  /// In en, this message translates to:
  /// **'Build quizzes together'**
  String get featureBuildTitle;

  /// No description provided for @featureBuildText.
  ///
  /// In en, this message translates to:
  /// **'Write categories and questions with friends, without spoiling each other.'**
  String get featureBuildText;

  /// No description provided for @featurePresentTitle.
  ///
  /// In en, this message translates to:
  /// **'Present on the big screen'**
  String get featurePresentTitle;

  /// No description provided for @featurePresentText.
  ///
  /// In en, this message translates to:
  /// **'Run the show on a TV or projector and control it from your phone.'**
  String get featurePresentText;

  /// No description provided for @featureBuzzersTitle.
  ///
  /// In en, this message translates to:
  /// **'Phones as buzzers'**
  String get featureBuzzersTitle;

  /// No description provided for @featureBuzzersText.
  ///
  /// In en, this message translates to:
  /// **'Players join by scanning a code. Arduino buzzers work too.'**
  String get featureBuzzersText;

  /// No description provided for @featureMusicTitle.
  ///
  /// In en, this message translates to:
  /// **'Music and sound effects'**
  String get featureMusicTitle;

  /// No description provided for @featureMusicText.
  ///
  /// In en, this message translates to:
  /// **'Background music, reveal sounds and a buzzer sound per team.'**
  String get featureMusicText;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get enterValidEmail;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password.'**
  String get enterPassword;

  /// No description provided for @noAccountForEmail.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email address.'**
  String get noAccountForEmail;

  /// No description provided for @wrongEmailOrPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong email address or password.'**
  String get wrongEmailOrPassword;

  /// No description provided for @invalidEmailShort.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address.'**
  String get invalidEmailShort;

  /// No description provided for @accountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get accountDisabled;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get tooManyAttempts;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get signInFailed;

  /// No description provided for @anonymousSignInDisabled.
  ///
  /// In en, this message translates to:
  /// **'Anonymous sign-in is disabled. Please try again later.'**
  String get anonymousSignInDisabled;

  /// No description provided for @couldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Could not get you started. Please try again.'**
  String get couldNotStart;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred.'**
  String get unknownError;

  /// No description provided for @couldNotSaveName.
  ///
  /// In en, this message translates to:
  /// **'Could not save your name. Please try again.'**
  String get couldNotSaveName;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @chooseYourName.
  ///
  /// In en, this message translates to:
  /// **'Choose the name other players and co-authors will see:'**
  String get chooseYourName;

  /// No description provided for @theNameOthersWillSee.
  ///
  /// In en, this message translates to:
  /// **'The name others will see'**
  String get theNameOthersWillSee;

  /// No description provided for @justJoinAShow.
  ///
  /// In en, this message translates to:
  /// **'Just join a show'**
  String get justJoinAShow;

  /// No description provided for @useDifferentAccount.
  ///
  /// In en, this message translates to:
  /// **'Use a different account'**
  String get useDifferentAccount;

  /// No description provided for @haveAnAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get haveAnAccount;

  /// No description provided for @termsBefore.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to the '**
  String get termsBefore;

  /// No description provided for @termsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsLink;

  /// No description provided for @termsBetween.
  ///
  /// In en, this message translates to:
  /// **' and the '**
  String get termsBetween;

  /// No description provided for @privacyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyLink;

  /// No description provided for @termsAfter.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get termsAfter;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @letsPlay.
  ///
  /// In en, this message translates to:
  /// **'Let\'s play'**
  String get letsPlay;

  /// No description provided for @joinAShow.
  ///
  /// In en, this message translates to:
  /// **'Join a show'**
  String get joinAShow;

  /// No description provided for @createOwnQuizzes.
  ///
  /// In en, this message translates to:
  /// **'Create my own quizzes'**
  String get createOwnQuizzes;

  /// No description provided for @creditsMadeForApp.
  ///
  /// In en, this message translates to:
  /// **'Made for Quiz Studio'**
  String get creditsMadeForApp;

  /// No description provided for @creditsMadeBy.
  ///
  /// In en, this message translates to:
  /// **'Made by {name}'**
  String creditsMadeBy(String name);

  /// No description provided for @creditsPartOfApp.
  ///
  /// In en, this message translates to:
  /// **'Part of the app'**
  String get creditsPartOfApp;

  /// No description provided for @creditsPublicDomain.
  ///
  /// In en, this message translates to:
  /// **'(public domain)'**
  String get creditsPublicDomain;

  /// No description provided for @creditsIntro.
  ///
  /// In en, this message translates to:
  /// **'The sounds that come with Quiz Studio were made for it or are free to use in any project (CC0). Tap a source to see where it is from.'**
  String get creditsIntro;

  /// No description provided for @questionTypeName.
  ///
  /// In en, this message translates to:
  /// **'{type, select, free{Free Question} abcd{ABCD} progressingReveal{Progressing Reveal} feud{Survey duel} connections{Word groups} rapidFire{Fragenhagel} matching{Matching} ordering{Put in order} topAnswers{Top answers} lastStanding{Last team standing} other{Unsupported}}'**
  String questionTypeName(String type);

  /// No description provided for @boardTypeName.
  ///
  /// In en, this message translates to:
  /// **'{type, select, display{Display Board} wheel{Wheel Playboard} other{Map Playboard}}'**
  String boardTypeName(String type);

  /// No description provided for @gameRoleName.
  ///
  /// In en, this message translates to:
  /// **'{role, select, admin{Admin} full{Full Access} other{Limited Access}}'**
  String gameRoleName(String role);

  /// No description provided for @companionKindName.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, whiteboard{Whiteboard} text{Text} number{Number} slider{Slider} choice{Pick one} order{Put in order} match{Match pairs} connections{Word groups} other{Answer list}}'**
  String companionKindName(String kind);

  /// No description provided for @estimateScoringName.
  ///
  /// In en, this message translates to:
  /// **'{scoring, select, closest{Closest wins} podium{1st, 2nd, 3rd} other{By distance}}'**
  String estimateScoringName(String scoring);

  /// No description provided for @turnOrderName.
  ///
  /// In en, this message translates to:
  /// **'{order, select, teams{As the teams are listed} mostPoints{Most points first} other{Fewest points first}}'**
  String turnOrderName(String order);

  /// No description provided for @standingResultName.
  ///
  /// In en, this message translates to:
  /// **'{result, select, right{Right} out{Wrong, out} other{Wrong, stays in}}'**
  String standingResultName(String result);

  /// No description provided for @rapidModeName.
  ///
  /// In en, this message translates to:
  /// **'{mode, select, buzzer{Teams buzz} other{Right or wrong on the teams\' devices}}'**
  String rapidModeName(String mode);

  /// No description provided for @progressStyleName.
  ///
  /// In en, this message translates to:
  /// **'{style, select, off{No progress indicator} bar{Bar} dots{Dots} battery{Battery} thermometer{Thermometer} other{Flux capacitor}}'**
  String progressStyleName(String style);

  /// No description provided for @topAnswersModeName.
  ///
  /// In en, this message translates to:
  /// **'{mode, select, buzzer{Teams buzz} typed{Typed in on the teams\' devices} other{Written on a whiteboard}}'**
  String topAnswersModeName(String mode);

  /// No description provided for @cardAnimationName.
  ///
  /// In en, this message translates to:
  /// **'{animation, select, off{Off} fade{Fade} slideUp{Slide in from bottom} slideDown{Slide in from top} bounce{Bounce in} zoom{Zoom} spin{Spin in} other{Flip}}'**
  String cardAnimationName(String animation);

  /// No description provided for @cardStyleName.
  ///
  /// In en, this message translates to:
  /// **'{style, select, standard{Standard} silentFilm{Silent film} poster{Poster} other{Just the words}}'**
  String cardStyleName(String style);

  /// No description provided for @builtinImageName.
  ///
  /// In en, this message translates to:
  /// **'{id, select, correct{Correct!} wrong{Wrong!} times_up{Time\'s up!} get_ready{Get ready} thinking{Thinking time} bonus{Bonus question} drumroll{Drumroll…} applause{Applause!} quiet{Quiet please} break{Break} final_round{Final round} winner{And the winner is…} other{Picture}}'**
  String builtinImageName(String id);

  /// No description provided for @rapidRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get rapidRight;

  /// No description provided for @rapidWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get rapidWrong;

  /// No description provided for @newGame.
  ///
  /// In en, this message translates to:
  /// **'New game'**
  String get newGame;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @couldNotCreateGame.
  ///
  /// In en, this message translates to:
  /// **'Could not create the game.'**
  String get couldNotCreateGame;

  /// No description provided for @joinWithInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Join with an invite link'**
  String get joinWithInviteLink;

  /// No description provided for @couldNotLoadGames.
  ///
  /// In en, this message translates to:
  /// **'Could not load your games.'**
  String get couldNotLoadGames;

  /// No description provided for @noGamesYet.
  ///
  /// In en, this message translates to:
  /// **'No games yet'**
  String get noGamesYet;

  /// No description provided for @noGamesYetText.
  ///
  /// In en, this message translates to:
  /// **'Create your first quiz, or ask a friend to invite you to theirs.'**
  String get noGamesYetText;

  /// No description provided for @unnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get unnamed;

  /// No description provided for @couldNotUploadPicture.
  ///
  /// In en, this message translates to:
  /// **'Could not upload the picture.'**
  String get couldNotUploadPicture;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @groupNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This group is not available.'**
  String get groupNotAvailable;

  /// No description provided for @newBoard.
  ///
  /// In en, this message translates to:
  /// **'{type, select, display{New Display Board} wheel{New Wheel Playboard} other{New Map Playboard}}'**
  String newBoard(String type);

  /// No description provided for @addBoard.
  ///
  /// In en, this message translates to:
  /// **'{type, select, display{Add Display Board} wheel{Add Wheel Playboard} other{Add Map Playboard}}'**
  String addBoard(String type);

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get newCategory;

  /// No description provided for @hideOne.
  ///
  /// In en, this message translates to:
  /// **'Hide one'**
  String get hideOne;

  /// No description provided for @revealedOf.
  ///
  /// In en, this message translates to:
  /// **'{revealed} of {steps} revealed'**
  String revealedOf(int revealed, int steps);

  /// No description provided for @revealNext.
  ///
  /// In en, this message translates to:
  /// **'Reveal next'**
  String get revealNext;

  /// No description provided for @boardColours.
  ///
  /// In en, this message translates to:
  /// **'Board colours'**
  String get boardColours;

  /// No description provided for @primaryColour.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primaryColour;

  /// No description provided for @accentColour.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get accentColour;

  /// No description provided for @useAppColours.
  ///
  /// In en, this message translates to:
  /// **'Use app colours'**
  String get useAppColours;

  /// No description provided for @noTimer.
  ///
  /// In en, this message translates to:
  /// **'No timer'**
  String get noTimer;

  /// No description provided for @timer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timer;

  /// No description provided for @teamsCanLockIn.
  ///
  /// In en, this message translates to:
  /// **'Teams can lock in early'**
  String get teamsCanLockIn;

  /// No description provided for @lockInOnText.
  ///
  /// In en, this message translates to:
  /// **'Locking in ends a team\'s time, and how long it took is kept. Only when scored by order, fastest first'**
  String get lockInOnText;

  /// No description provided for @lockInOffText.
  ///
  /// In en, this message translates to:
  /// **'Every answer counts as it stands when the time is up or you end the round'**
  String get lockInOffText;

  /// No description provided for @musicCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 music} other{{count} music}}'**
  String musicCount(int count);

  /// No description provided for @effectCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 effect} other{{count} effects}}'**
  String effectCount(int count);

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @cardCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card} other{{count} cards}}'**
  String cardCount(int count);

  /// No description provided for @cardsOfferedOff.
  ///
  /// In en, this message translates to:
  /// **'{on} offered, {off} off'**
  String cardsOfferedOff(int on, int off);

  /// No description provided for @gameNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This game is not available.'**
  String get gameNotAvailable;

  /// No description provided for @copiedGame.
  ///
  /// In en, this message translates to:
  /// **'Copied the game with its answers.'**
  String get copiedGame;

  /// No description provided for @renameGame.
  ///
  /// In en, this message translates to:
  /// **'Rename game'**
  String get renameGame;

  /// No description provided for @deleteGame.
  ///
  /// In en, this message translates to:
  /// **'Delete game'**
  String get deleteGame;

  /// No description provided for @deleteGameText.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" and all of its questions will be deleted for everyone.'**
  String deleteGameText(String name);

  /// No description provided for @leaveGame.
  ///
  /// In en, this message translates to:
  /// **'Leave game'**
  String get leaveGame;

  /// No description provided for @leaveGameText.
  ///
  /// In en, this message translates to:
  /// **'You will lose access to \"{name}\" until someone invites you again.'**
  String leaveGameText(String name);

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @musicAndSounds.
  ///
  /// In en, this message translates to:
  /// **'Music & sounds'**
  String get musicAndSounds;

  /// No description provided for @noneYet.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get noneYet;

  /// No description provided for @soundsForGame.
  ///
  /// In en, this message translates to:
  /// **'Sounds for the whole game'**
  String get soundsForGame;

  /// No description provided for @cards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get cards;

  /// No description provided for @cardsForGame.
  ///
  /// In en, this message translates to:
  /// **'Cards for the whole game'**
  String get cardsForGame;

  /// No description provided for @people.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get people;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @copyAsText.
  ///
  /// In en, this message translates to:
  /// **'Copy as text'**
  String get copyAsText;

  /// No description provided for @nothingSharedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Ask an admin to share a category with you.'**
  String get nothingSharedYet;

  /// No description provided for @onlyYou.
  ///
  /// In en, this message translates to:
  /// **'Only you'**
  String get onlyYou;

  /// No description provided for @memberCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String memberCount(int count);

  /// No description provided for @renameGroup.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get renameGroup;

  /// No description provided for @displayText.
  ///
  /// In en, this message translates to:
  /// **'Display text'**
  String get displayText;

  /// No description provided for @shownOnBoard.
  ///
  /// In en, this message translates to:
  /// **'Shown on the board'**
  String get shownOnBoard;

  /// No description provided for @categoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 category} other{{count} categories}}'**
  String categoryCount(int count);

  /// No description provided for @ownSounds.
  ///
  /// In en, this message translates to:
  /// **'own sounds'**
  String get ownSounds;

  /// No description provided for @usesGames.
  ///
  /// In en, this message translates to:
  /// **'Uses the game\'s'**
  String get usesGames;

  /// No description provided for @soundsForBoard.
  ///
  /// In en, this message translates to:
  /// **'Sounds for this board'**
  String get soundsForBoard;

  /// No description provided for @onlyGames.
  ///
  /// In en, this message translates to:
  /// **'Only the game\'s'**
  String get onlyGames;

  /// No description provided for @cardsForBoard.
  ///
  /// In en, this message translates to:
  /// **'Cards for this board'**
  String get cardsForBoard;

  /// No description provided for @colours.
  ///
  /// In en, this message translates to:
  /// **'Colours'**
  String get colours;

  /// No description provided for @appsColours.
  ///
  /// In en, this message translates to:
  /// **'The app\'s colours'**
  String get appsColours;

  /// No description provided for @ownColours.
  ///
  /// In en, this message translates to:
  /// **'Own colours'**
  String get ownColours;

  /// No description provided for @textOnBoard.
  ///
  /// In en, this message translates to:
  /// **'Text on the board'**
  String get textOnBoard;

  /// No description provided for @splitPointFields.
  ///
  /// In en, this message translates to:
  /// **'Split point fields'**
  String get splitPointFields;

  /// No description provided for @splitPointFieldsText.
  ///
  /// In en, this message translates to:
  /// **'When a value appears more than once in a ring'**
  String get splitPointFieldsText;

  /// No description provided for @arrangeMap.
  ///
  /// In en, this message translates to:
  /// **'Arrange the map'**
  String get arrangeMap;

  /// No description provided for @arrangeMapShort.
  ///
  /// In en, this message translates to:
  /// **'Bubbles, arrows, titles, pictures and lines'**
  String get arrangeMapShort;

  /// No description provided for @arrangeMapLong.
  ///
  /// In en, this message translates to:
  /// **'Place bubbles, connect them, add titles, pictures and lines'**
  String get arrangeMapLong;

  /// No description provided for @labelsInsteadOfPoints.
  ///
  /// In en, this message translates to:
  /// **'Labels instead of points'**
  String get labelsInsteadOfPoints;

  /// No description provided for @labelsInsteadOfPointsText.
  ///
  /// In en, this message translates to:
  /// **'Questions without a label still show their points'**
  String get labelsInsteadOfPointsText;

  /// No description provided for @deleteBoard.
  ///
  /// In en, this message translates to:
  /// **'Delete board'**
  String get deleteBoard;

  /// No description provided for @deleteBoardFirst.
  ///
  /// In en, this message translates to:
  /// **'Move or delete its categories first'**
  String get deleteBoardFirst;

  /// No description provided for @ungroupedCategories.
  ///
  /// In en, this message translates to:
  /// **'Ungrouped categories'**
  String get ungroupedCategories;

  /// No description provided for @boardSettings.
  ///
  /// In en, this message translates to:
  /// **'Board settings'**
  String get boardSettings;

  /// No description provided for @moveBoard.
  ///
  /// In en, this message translates to:
  /// **'Move board'**
  String get moveBoard;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @moveToAnotherBoard.
  ///
  /// In en, this message translates to:
  /// **'Move to another board'**
  String get moveToAnotherBoard;

  /// No description provided for @comesAfterTitle.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" comes after'**
  String comesAfterTitle(String name);

  /// No description provided for @categoryBeforeIt.
  ///
  /// In en, this message translates to:
  /// **'The category before it (default)'**
  String get categoryBeforeIt;

  /// No description provided for @startsNewChain.
  ///
  /// In en, this message translates to:
  /// **'Nothing: it starts a new chain'**
  String get startsNewChain;

  /// No description provided for @deleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete category'**
  String get deleteCategory;

  /// No description provided for @deleteCategoryText.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" and its {count} questions will be deleted.'**
  String deleteCategoryText(String name, int count);

  /// No description provided for @inPlayTip.
  ///
  /// In en, this message translates to:
  /// **'In play: tap to take it out of the game'**
  String get inPlayTip;

  /// No description provided for @notInPlayTip.
  ///
  /// In en, this message translates to:
  /// **'Not in play: tap to put it back'**
  String get notInPlayTip;

  /// No description provided for @moveCategory.
  ///
  /// In en, this message translates to:
  /// **'Move category'**
  String get moveCategory;

  /// No description provided for @questionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question} other{{count} questions}}'**
  String questionCount(int count);

  /// No description provided for @notInPlay.
  ///
  /// In en, this message translates to:
  /// **'not in play'**
  String get notInPlay;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @moveToAnotherBoardMenu.
  ///
  /// In en, this message translates to:
  /// **'Move to another board…'**
  String get moveToAnotherBoardMenu;

  /// No description provided for @comesAfterMenu.
  ///
  /// In en, this message translates to:
  /// **'Comes after…'**
  String get comesAfterMenu;

  /// No description provided for @renameCategory.
  ///
  /// In en, this message translates to:
  /// **'Rename category'**
  String get renameCategory;

  /// No description provided for @shareCategory.
  ///
  /// In en, this message translates to:
  /// **'Share category'**
  String get shareCategory;

  /// No description provided for @shareCategoryText.
  ///
  /// In en, this message translates to:
  /// **'Members with limited access only see the categories switched on here.'**
  String get shareCategoryText;

  /// No description provided for @createdThisCategory.
  ///
  /// In en, this message translates to:
  /// **'Created this category'**
  String get createdThisCategory;

  /// No description provided for @notShared.
  ///
  /// In en, this message translates to:
  /// **'Not shared'**
  String get notShared;

  /// No description provided for @sharedWith.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{With 1 person} other{With {count} people}}'**
  String sharedWith(int count);

  /// No description provided for @categoryNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This category is not available.'**
  String get categoryNotAvailable;

  /// No description provided for @addQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add question'**
  String get addQuestion;

  /// No description provided for @usesBoards.
  ///
  /// In en, this message translates to:
  /// **'Uses the board\'s'**
  String get usesBoards;

  /// No description provided for @soundsForCategory.
  ///
  /// In en, this message translates to:
  /// **'Sounds for this category'**
  String get soundsForCategory;

  /// No description provided for @onlyBoardsAndGames.
  ///
  /// In en, this message translates to:
  /// **'Only the board\'s and game\'s'**
  String get onlyBoardsAndGames;

  /// No description provided for @cardsForCategory.
  ///
  /// In en, this message translates to:
  /// **'Cards for this category'**
  String get cardsForCategory;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @noQuestionsYet.
  ///
  /// In en, this message translates to:
  /// **'No questions yet.'**
  String get noQuestionsYet;

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save.'**
  String get couldNotSave;

  /// No description provided for @deleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete question'**
  String get deleteQuestion;

  /// No description provided for @deleteQuestionText.
  ///
  /// In en, this message translates to:
  /// **'This question will be deleted.'**
  String get deleteQuestionText;

  /// No description provided for @onTheDevices.
  ///
  /// In en, this message translates to:
  /// **'on the devices'**
  String get onTheDevices;

  /// No description provided for @kindOnTheDevices.
  ///
  /// In en, this message translates to:
  /// **'{kind} on the devices'**
  String kindOnTheDevices(String kind);

  /// No description provided for @teamsBetShort.
  ///
  /// In en, this message translates to:
  /// **'teams bet'**
  String get teamsBetShort;

  /// No description provided for @teamsBetHowManyShort.
  ///
  /// In en, this message translates to:
  /// **'teams bet how many'**
  String get teamsBetHowManyShort;

  /// No description provided for @byOrderShort.
  ///
  /// In en, this message translates to:
  /// **'by order'**
  String get byOrderShort;

  /// No description provided for @fixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get fixed;

  /// No description provided for @pointsBetSummary.
  ///
  /// In en, this message translates to:
  /// **'Teams bet their points · at least {limit} to bet'**
  String pointsBetSummary(int limit);

  /// No description provided for @betOnHowMany.
  ///
  /// In en, this message translates to:
  /// **'Bet on how many'**
  String get betOnHowMany;

  /// No description provided for @plusEach.
  ///
  /// In en, this message translates to:
  /// **'+{plus} each'**
  String plusEach(int plus);

  /// No description provided for @plusMinusEach.
  ///
  /// In en, this message translates to:
  /// **'+{plus} / −{minus} each'**
  String plusMinusEach(int plus, int minus);

  /// No description provided for @byOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'By order · {plus}, then −{step} per place'**
  String byOrderSummary(int plus, int step);

  /// No description provided for @wrongMinus.
  ///
  /// In en, this message translates to:
  /// **'wrong −{minus}'**
  String wrongMinus(int minus);

  /// No description provided for @picture.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get picture;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @noOwnMedia.
  ///
  /// In en, this message translates to:
  /// **'No picture, music or sounds of its own'**
  String get noOwnMedia;

  /// No description provided for @rule.
  ///
  /// In en, this message translates to:
  /// **'Rule'**
  String get rule;

  /// No description provided for @scoringRuleName.
  ///
  /// In en, this message translates to:
  /// **'{rule, select, fixed{Fixed points} points{Teams bet their points} amount{Teams bet how many they can do} closest{By closeness: nearest first} other{By order: fastest first}}'**
  String scoringRuleName(String rule);

  /// No description provided for @scoringFixedText.
  ///
  /// In en, this message translates to:
  /// **'Every team plays for the same points.'**
  String get scoringFixedText;

  /// No description provided for @scoringRankedText.
  ///
  /// In en, this message translates to:
  /// **'The first team gets the most points, each after it a bit less. The order is the order teams locked in a right answer on their devices, or the order you tap them in, e.g. as they finish on stage. Wrong answers lose the minus points.'**
  String get scoringRankedText;

  /// No description provided for @scoringPointsText.
  ///
  /// In en, this message translates to:
  /// **'Before the question, each team bets some of its points: a right answer wins the bet, a wrong one loses it. Teams may bet up to their score, or up to {limit} if they have less.'**
  String scoringPointsText(int limit);

  /// No description provided for @scoringAmountText.
  ///
  /// In en, this message translates to:
  /// **'First only the bet question is shown and each team says how many it can do. Then the question runs; you decide per team whether it reached its number. Reached: the points for each one. Missed: the minus points for each one.'**
  String get scoringAmountText;

  /// No description provided for @betQuestion.
  ///
  /// In en, this message translates to:
  /// **'Bet question'**
  String get betQuestion;

  /// No description provided for @betQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'How many science fiction films can you name?'**
  String get betQuestionHint;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @eachPlus.
  ///
  /// In en, this message translates to:
  /// **'Each +'**
  String get eachPlus;

  /// No description provided for @firstPlacePlus.
  ///
  /// In en, this message translates to:
  /// **'1st place +'**
  String get firstPlacePlus;

  /// No description provided for @eachItemPlus.
  ///
  /// In en, this message translates to:
  /// **'Each item +'**
  String get eachItemPlus;

  /// No description provided for @winnerPlus.
  ///
  /// In en, this message translates to:
  /// **'Winner +'**
  String get winnerPlus;

  /// No description provided for @eachAnswerPlus.
  ///
  /// In en, this message translates to:
  /// **'Each answer +'**
  String get eachAnswerPlus;

  /// No description provided for @ifRightPlus.
  ///
  /// In en, this message translates to:
  /// **'If right +'**
  String get ifRightPlus;

  /// No description provided for @onTheBoard.
  ///
  /// In en, this message translates to:
  /// **'{points} on the board'**
  String onTheBoard(int points);

  /// No description provided for @eachMinus.
  ///
  /// In en, this message translates to:
  /// **'Each −'**
  String get eachMinus;

  /// No description provided for @ifWrongMinus.
  ///
  /// In en, this message translates to:
  /// **'If wrong −'**
  String get ifWrongMinus;

  /// No description provided for @lessPerPlace.
  ///
  /// In en, this message translates to:
  /// **'Less per place'**
  String get lessPerPlace;

  /// No description provided for @highestBet.
  ///
  /// In en, this message translates to:
  /// **'Highest bet'**
  String get highestBet;

  /// No description provided for @musicAndEffects.
  ///
  /// In en, this message translates to:
  /// **'Music & effects'**
  String get musicAndEffects;

  /// No description provided for @theCategorys.
  ///
  /// In en, this message translates to:
  /// **'The category\'s'**
  String get theCategorys;

  /// No description provided for @soundsForQuestion.
  ///
  /// In en, this message translates to:
  /// **'Sounds for this question'**
  String get soundsForQuestion;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @answerHint.
  ///
  /// In en, this message translates to:
  /// **'Answer hint'**
  String get answerHint;

  /// No description provided for @onlyGamemasterSees.
  ///
  /// In en, this message translates to:
  /// **'Only the gamemaster sees this'**
  String get onlyGamemasterSees;

  /// No description provided for @label.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// No description provided for @labelHelper.
  ///
  /// In en, this message translates to:
  /// **'Small badge shown on the question card'**
  String get labelHelper;

  /// No description provided for @labelTooltip.
  ///
  /// In en, this message translates to:
  /// **'A small badge shown on the question card'**
  String get labelTooltip;

  /// No description provided for @howTeamsAnswer.
  ///
  /// In en, this message translates to:
  /// **'How teams answer'**
  String get howTeamsAnswer;

  /// No description provided for @scoring.
  ///
  /// In en, this message translates to:
  /// **'Scoring'**
  String get scoring;

  /// No description provided for @mediaAndSound.
  ///
  /// In en, this message translates to:
  /// **'Media & sound'**
  String get mediaAndSound;

  /// No description provided for @moveQuestion.
  ///
  /// In en, this message translates to:
  /// **'Move question'**
  String get moveQuestion;

  /// No description provided for @newQuestion.
  ///
  /// In en, this message translates to:
  /// **'New question'**
  String get newQuestion;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @explainFree.
  ///
  /// In en, this message translates to:
  /// **'The most basic question: no answer options and nothing to reveal. Under \"How teams answer\" buzzers can be switched off, e.g. for estimation questions.'**
  String get explainFree;

  /// No description provided for @explainAbcd.
  ///
  /// In en, this message translates to:
  /// **'Shows right and wrong answer suggestions, which the gamemaster reveals one by one.'**
  String get explainAbcd;

  /// No description provided for @explainProgressingReveal.
  ///
  /// In en, this message translates to:
  /// **'The gamemaster reveals more information piece by piece.'**
  String get explainProgressingReveal;

  /// No description provided for @explainFeud.
  ///
  /// In en, this message translates to:
  /// **'A duel over a survey: the team that buzzed uncovers answers until its third strike, then the other team may steal them all.'**
  String get explainFeud;

  /// No description provided for @explainTopAnswers.
  ///
  /// In en, this message translates to:
  /// **'Name the most popular answers: teams find answers on a list, by buzzing or on their devices, and get the points of each one.'**
  String get explainTopAnswers;

  /// No description provided for @explainConnections.
  ///
  /// In en, this message translates to:
  /// **'Sixteen words in four groups of four. Every team solves it on its own device; each group found is worth a quarter of the points.'**
  String get explainConnections;

  /// No description provided for @explainRapidFire.
  ///
  /// In en, this message translates to:
  /// **'Fragenhagel: many short questions right after one another. Teams buzz, or judge statements right or wrong on their devices; each item can have a picture and a sound.'**
  String get explainRapidFire;

  /// No description provided for @explainMatching.
  ///
  /// In en, this message translates to:
  /// **'Matching: pairs of texts or pictures, e.g. films and their years. Every team puts them back together on its device; the big screen shows the pictures.'**
  String get explainMatching;

  /// No description provided for @explainLastStanding.
  ///
  /// In en, this message translates to:
  /// **'Last team standing: one player per team takes turns, e.g. naming films or saying whether a star has a biopic. A wrong answer puts the team out; the last team left gets the points.'**
  String get explainLastStanding;

  /// No description provided for @explainUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This question type is not supported by this version of the app.'**
  String get explainUnsupported;

  /// No description provided for @groupsNeedNameAndWords.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 group needs a name and four words.} other{{count} groups need a name and four words.}}'**
  String groupsNeedNameAndWords(int count);

  /// No description provided for @wordTwice.
  ///
  /// In en, this message translates to:
  /// **'\"{word}\" is in the puzzle twice.'**
  String wordTwice(String word);

  /// No description provided for @groupInCommon.
  ///
  /// In en, this message translates to:
  /// **'{group, plural, =0{Yellow} =1{Green} =2{Blue} other{Purple}}: what they have in common'**
  String groupInCommon(int group);

  /// No description provided for @wordN.
  ///
  /// In en, this message translates to:
  /// **'Word {n}'**
  String wordN(int n);

  /// No description provided for @connectionsReady.
  ///
  /// In en, this message translates to:
  /// **'Ready. Yellow is meant to be the easiest group and purple the hardest.'**
  String get connectionsReady;

  /// No description provided for @answerLetter.
  ///
  /// In en, this message translates to:
  /// **'Answer {letter}'**
  String answerLetter(String letter);

  /// No description provided for @removeAnswer.
  ///
  /// In en, this message translates to:
  /// **'Remove answer'**
  String get removeAnswer;

  /// No description provided for @addAnswer.
  ///
  /// In en, this message translates to:
  /// **'Add answer'**
  String get addAnswer;

  /// No description provided for @absoluteValues.
  ///
  /// In en, this message translates to:
  /// **'Show absolute values instead of percentages'**
  String get absoluteValues;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @answerN.
  ///
  /// In en, this message translates to:
  /// **'Answer {n}'**
  String answerN(int n);

  /// No description provided for @informationN.
  ///
  /// In en, this message translates to:
  /// **'Information {n}'**
  String informationN(int n);

  /// No description provided for @addInformation.
  ///
  /// In en, this message translates to:
  /// **'Add information'**
  String get addInformation;

  /// No description provided for @importFromRanker.
  ///
  /// In en, this message translates to:
  /// **'Import from Ranker'**
  String get importFromRanker;

  /// No description provided for @pictureStrip.
  ///
  /// In en, this message translates to:
  /// **'Picture strip'**
  String get pictureStrip;

  /// No description provided for @pictureStripText.
  ///
  /// In en, this message translates to:
  /// **'Small pictures under the question, \"?\" for those still hidden'**
  String get pictureStripText;

  /// No description provided for @teamsBuzz.
  ///
  /// In en, this message translates to:
  /// **'Teams buzz'**
  String get teamsBuzz;

  /// No description provided for @onTheDevicesShort.
  ///
  /// In en, this message translates to:
  /// **'On the devices'**
  String get onTheDevicesShort;

  /// No description provided for @progressOnBigScreen.
  ///
  /// In en, this message translates to:
  /// **'Progress on the big screen'**
  String get progressOnBigScreen;

  /// No description provided for @rapidDevicesText.
  ///
  /// In en, this message translates to:
  /// **'Each item is a statement. Every team picks right or wrong on its device; when you move on, a right pick gets the points.'**
  String get rapidDevicesText;

  /// No description provided for @rapidBuzzText.
  ///
  /// In en, this message translates to:
  /// **'Teams buzz for each item. A right answer gets the points and moves straight on to the next item.'**
  String get rapidBuzzText;

  /// No description provided for @statementN.
  ///
  /// In en, this message translates to:
  /// **'Statement {n}'**
  String statementN(int n);

  /// No description provided for @questionN.
  ///
  /// In en, this message translates to:
  /// **'Question {n}'**
  String questionN(int n);

  /// No description provided for @answer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get answer;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @addStatement.
  ///
  /// In en, this message translates to:
  /// **'Add statement'**
  String get addStatement;

  /// No description provided for @turnOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Turn order'**
  String get turnOrderLabel;

  /// No description provided for @lastStandingText.
  ///
  /// In en, this message translates to:
  /// **'One player per team takes turns. You rate each turn: right, wrong (the team is out) or wrong but it stays in. The last team left gets the points.'**
  String get lastStandingText;

  /// No description provided for @noPrompts.
  ///
  /// In en, this message translates to:
  /// **'No prompts: every turn answers the question itself.'**
  String get noPrompts;

  /// No description provided for @onePromptPerTurn.
  ///
  /// In en, this message translates to:
  /// **'One prompt per turn, in this order.'**
  String get onePromptPerTurn;

  /// No description provided for @promptN.
  ///
  /// In en, this message translates to:
  /// **'Prompt {n}'**
  String promptN(int n);

  /// No description provided for @addPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add prompt'**
  String get addPrompt;

  /// No description provided for @onlyWithDevices.
  ///
  /// In en, this message translates to:
  /// **'Only playable with the teams\' own devices: every team needs a phone or tablet connected (Setup, then Connect devices). Without them there is nothing to answer with.'**
  String get onlyWithDevices;

  /// No description provided for @matchingEditorText.
  ///
  /// In en, this message translates to:
  /// **'Write each pair the way it belongs together; the teams get the right side mixed up. A side can be a text, a picture or both. A picture without text gets a name on the devices, such as \"Picture 3\".'**
  String get matchingEditorText;

  /// No description provided for @matchLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get matchLeft;

  /// No description provided for @matchBelongsTo.
  ///
  /// In en, this message translates to:
  /// **'Belongs to'**
  String get matchBelongsTo;

  /// No description provided for @removePair.
  ///
  /// In en, this message translates to:
  /// **'Remove pair'**
  String get removePair;

  /// No description provided for @addPair.
  ///
  /// In en, this message translates to:
  /// **'Add pair'**
  String get addPair;

  /// No description provided for @buzz.
  ///
  /// In en, this message translates to:
  /// **'Buzz'**
  String get buzz;

  /// No description provided for @typed.
  ///
  /// In en, this message translates to:
  /// **'Typed'**
  String get typed;

  /// No description provided for @whiteboard.
  ///
  /// In en, this message translates to:
  /// **'Whiteboard'**
  String get whiteboard;

  /// No description provided for @topAnswersBuzzText.
  ///
  /// In en, this message translates to:
  /// **'A team buzzes and names an answer. Tap the one it named: it is uncovered and the team gets its points. Then everyone may buzz again.'**
  String get topAnswersBuzzText;

  /// No description provided for @topAnswersTypedText.
  ///
  /// In en, this message translates to:
  /// **'Every team types its answers into a list on its device. You tick the ones it found, with suggestions for what it typed.'**
  String get topAnswersTypedText;

  /// No description provided for @topAnswersWhiteboardText.
  ///
  /// In en, this message translates to:
  /// **'Every team writes its answers on a numbered whiteboard. You tick the ones it found.'**
  String get topAnswersWhiteboardText;

  /// No description provided for @topAnswersListText.
  ///
  /// In en, this message translates to:
  /// **'Most popular first. Without its own points an answer is worth the question\'s points. Other spellings to accept go after a /.'**
  String get topAnswersListText;

  /// No description provided for @paperName.
  ///
  /// In en, this message translates to:
  /// **'{paper, select, lines{Ruled} grid{Squared} list{Numbered list} image{Picture} other{Blank}}'**
  String paperName(String paper);

  /// No description provided for @connectionsDevicesText.
  ///
  /// In en, this message translates to:
  /// **'Every team solves the puzzle on its own device. You see live which groups each team has found.'**
  String get connectionsDevicesText;

  /// No description provided for @chooseDeviceScreenText.
  ///
  /// In en, this message translates to:
  /// **'Choose a screen to open on every team\'s device with the question. You see the answers as they are written and decide when to show them.'**
  String get chooseDeviceScreenText;

  /// No description provided for @deviceScreenText.
  ///
  /// In en, this message translates to:
  /// **'Opens on every team\'s device with the question. You see the answers as they are written and decide when to show them.'**
  String get deviceScreenText;

  /// No description provided for @buzzer.
  ///
  /// In en, this message translates to:
  /// **'Buzzer'**
  String get buzzer;

  /// No description provided for @nothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get nothing;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @mistakesAllowed.
  ///
  /// In en, this message translates to:
  /// **'Mistakes allowed'**
  String get mistakesAllowed;

  /// No description provided for @paper.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get paper;

  /// No description provided for @rows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get rows;

  /// No description provided for @choosePictureToDrawOn.
  ///
  /// In en, this message translates to:
  /// **'Choose the picture to draw on'**
  String get choosePictureToDrawOn;

  /// No description provided for @pictureSet.
  ///
  /// In en, this message translates to:
  /// **'Picture set'**
  String get pictureSet;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @step.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get step;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @rightValue.
  ///
  /// In en, this message translates to:
  /// **'Right value'**
  String get rightValue;

  /// No description provided for @rightWithin.
  ///
  /// In en, this message translates to:
  /// **'Right within ±'**
  String get rightWithin;

  /// No description provided for @noBuzzingAtAll.
  ///
  /// In en, this message translates to:
  /// **'No buzzing at all'**
  String get noBuzzingAtAll;

  /// No description provided for @noBuzzingAtAllText.
  ///
  /// In en, this message translates to:
  /// **'Buzzer boxes stay off too, e.g. for estimation questions'**
  String get noBuzzingAtAllText;

  /// No description provided for @teamsCanStopEarly.
  ///
  /// In en, this message translates to:
  /// **'Teams can stop early'**
  String get teamsCanStopEarly;

  /// No description provided for @orderEditorText.
  ///
  /// In en, this message translates to:
  /// **'Enter the items in the right order. The teams get them shuffled.'**
  String get orderEditorText;

  /// No description provided for @matchEditorText.
  ///
  /// In en, this message translates to:
  /// **'Enter each pair. The teams get the right-hand side shuffled.'**
  String get matchEditorText;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get item;

  /// No description provided for @matchRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get matchRight;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// No description provided for @timerSummary.
  ///
  /// In en, this message translates to:
  /// **'timer {time}'**
  String timerSummary(String time);

  /// No description provided for @progressSummary.
  ///
  /// In en, this message translates to:
  /// **'progress: {style}'**
  String progressSummary(String style);

  /// No description provided for @mistakesAllowedSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} mistakes allowed'**
  String mistakesAllowedSummary(int count);

  /// No description provided for @outLoudNoBuzzer.
  ///
  /// In en, this message translates to:
  /// **'Out loud, no buzzer'**
  String get outLoudNoBuzzer;

  /// No description provided for @buzzerBoxesOnly.
  ///
  /// In en, this message translates to:
  /// **'Buzzer boxes only'**
  String get buzzerBoxesOnly;

  /// No description provided for @sliderSummary.
  ///
  /// In en, this message translates to:
  /// **'Slider {from}–{to}'**
  String sliderSummary(String from, String to);

  /// No description provided for @whiteboardSummary.
  ///
  /// In en, this message translates to:
  /// **'Whiteboard, {paper}'**
  String whiteboardSummary(String paper);

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Put {count} in order'**
  String orderSummary(int count);

  /// No description provided for @matchSummary.
  ///
  /// In en, this message translates to:
  /// **'Match {count} pairs'**
  String matchSummary(int count);

  /// No description provided for @listSummary.
  ///
  /// In en, this message translates to:
  /// **'Answer list, {count} rows'**
  String listSummary(int count);

  /// No description provided for @rightShort.
  ///
  /// In en, this message translates to:
  /// **'right'**
  String get rightShort;

  /// No description provided for @emptyCard.
  ///
  /// In en, this message translates to:
  /// **'Empty card'**
  String get emptyCard;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @moveCard.
  ///
  /// In en, this message translates to:
  /// **'Move card'**
  String get moveCard;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get off;

  /// No description provided for @offerInShow.
  ///
  /// In en, this message translates to:
  /// **'Offer it in the show'**
  String get offerInShow;

  /// No description provided for @keepOutOfShow.
  ///
  /// In en, this message translates to:
  /// **'Keep it out of the show'**
  String get keepOutOfShow;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @cardsDialogText.
  ///
  /// In en, this message translates to:
  /// **'What you can put over the screen during the show, offered in this order. Tap a card to change it, drag it by its handle to move it, or switch it off to keep it out of the show.'**
  String get cardsDialogText;

  /// No description provided for @newCard.
  ///
  /// In en, this message translates to:
  /// **'New card'**
  String get newCard;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploading;

  /// No description provided for @addPicture.
  ///
  /// In en, this message translates to:
  /// **'Add picture'**
  String get addPicture;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @videoClip.
  ///
  /// In en, this message translates to:
  /// **'Video clip'**
  String get videoClip;

  /// No description provided for @videoClipText.
  ///
  /// In en, this message translates to:
  /// **'A clip plays full screen on the big screen and the card goes when it ends.'**
  String get videoClipText;

  /// No description provided for @look.
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get look;

  /// No description provided for @removeCard.
  ///
  /// In en, this message translates to:
  /// **'Remove card'**
  String get removeCard;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @boardMusic.
  ///
  /// In en, this message translates to:
  /// **'Board music'**
  String get boardMusic;

  /// No description provided for @calmMusic.
  ///
  /// In en, this message translates to:
  /// **'Calm music'**
  String get calmMusic;

  /// No description provided for @thrillingMusic.
  ///
  /// In en, this message translates to:
  /// **'Thrilling music'**
  String get thrillingMusic;

  /// No description provided for @effectRightAnswer.
  ///
  /// In en, this message translates to:
  /// **'Right answer'**
  String get effectRightAnswer;

  /// No description provided for @effectWrongAnswer.
  ///
  /// In en, this message translates to:
  /// **'Wrong answer'**
  String get effectWrongAnswer;

  /// No description provided for @effectQuestionClosed.
  ///
  /// In en, this message translates to:
  /// **'Question closed'**
  String get effectQuestionClosed;

  /// No description provided for @effectReveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get effectReveal;

  /// No description provided for @effectQuestionOpens.
  ///
  /// In en, this message translates to:
  /// **'Question opens'**
  String get effectQuestionOpens;

  /// No description provided for @effectTeamLocksIn.
  ///
  /// In en, this message translates to:
  /// **'Team locks in'**
  String get effectTeamLocksIn;

  /// No description provided for @effectNextItem.
  ///
  /// In en, this message translates to:
  /// **'Next Fragenhagel item'**
  String get effectNextItem;

  /// No description provided for @effectLastTenSeconds.
  ///
  /// In en, this message translates to:
  /// **'Last 10 seconds'**
  String get effectLastTenSeconds;

  /// No description provided for @effectTimesUp.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up'**
  String get effectTimesUp;

  /// No description provided for @effectSteal.
  ///
  /// In en, this message translates to:
  /// **'Steal'**
  String get effectSteal;

  /// No description provided for @effectFullySolved.
  ///
  /// In en, this message translates to:
  /// **'Fully solved'**
  String get effectFullySolved;

  /// No description provided for @appDefault.
  ///
  /// In en, this message translates to:
  /// **'App default: {sound}'**
  String appDefault(String sound);

  /// No description provided for @asSetAbove.
  ///
  /// In en, this message translates to:
  /// **'As set above'**
  String get asSetAbove;

  /// No description provided for @silent.
  ///
  /// In en, this message translates to:
  /// **'Silent'**
  String get silent;

  /// No description provided for @ownFile.
  ///
  /// In en, this message translates to:
  /// **'Own file'**
  String get ownFile;

  /// No description provided for @ownFileMenu.
  ///
  /// In en, this message translates to:
  /// **'Own file…'**
  String get ownFileMenu;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @soundsGameText.
  ///
  /// In en, this message translates to:
  /// **'What plays during this game. Anything not set uses the sounds that come with the app.'**
  String get soundsGameText;

  /// No description provided for @soundsLevelText.
  ///
  /// In en, this message translates to:
  /// **'Anything left on \"As set above\" comes from the board or the game.'**
  String get soundsLevelText;

  /// No description provided for @soundsAtMoments.
  ///
  /// In en, this message translates to:
  /// **'Sounds at moments of the show'**
  String get soundsAtMoments;

  /// No description provided for @ownEffects.
  ///
  /// In en, this message translates to:
  /// **'Your own effects'**
  String get ownEffects;

  /// No description provided for @addEffect.
  ///
  /// In en, this message translates to:
  /// **'Add effect'**
  String get addEffect;

  /// No description provided for @oggNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Ogg sounds do not play on Windows. Please use MP3, WAV or M4A.'**
  String get oggNotSupported;

  /// No description provided for @fileTypeNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This file type is not supported.'**
  String get fileTypeNotSupported;

  /// No description provided for @couldNotUploadMedia.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, image{Could not upload the picture.} audio{Could not upload the sound.} other{Could not upload the video.}}'**
  String couldNotUploadMedia(String kind);

  /// No description provided for @addMedia.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, image{Add picture} audio{Add sound} other{Add video}}'**
  String addMedia(String kind);

  /// No description provided for @pictureTooltip.
  ///
  /// In en, this message translates to:
  /// **'Picture: tap to see it large, replace or remove it'**
  String get pictureTooltip;

  /// No description provided for @replaceOrRemoveSound.
  ///
  /// In en, this message translates to:
  /// **'Replace or remove the sound'**
  String get replaceOrRemoveSound;

  /// No description provided for @videoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Video: tap to watch, replace or remove it'**
  String get videoTooltip;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @enterRankerUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a ranker.com list URL, e.g. https://www.ranker.com/list/best-smells/jacob-shelton'**
  String get enterRankerUrl;

  /// No description provided for @rankerError.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, page{The page could not be loaded ({status}).} noList{No list was found on that page.} list{The list could not be loaded ({status}).} items{The list items could not be loaded ({status}).} other{The list has too few entries.}}'**
  String rankerError(String kind, Object status);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'The import failed.'**
  String get importFailed;

  /// No description provided for @rankerImportText.
  ///
  /// In en, this message translates to:
  /// **'The top ten entries of the list replace this question\'s answers.'**
  String get rankerImportText;

  /// No description provided for @rankerListUrl.
  ///
  /// In en, this message translates to:
  /// **'Ranker list URL'**
  String get rankerListUrl;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add title'**
  String get addTitle;

  /// No description provided for @arrowCircle.
  ///
  /// In en, this message translates to:
  /// **'That arrow would go round in a circle.'**
  String get arrowCircle;

  /// No description provided for @screensWide.
  ///
  /// In en, this message translates to:
  /// **'{count} screens wide'**
  String screensWide(String count);

  /// No description provided for @mapTapFirst.
  ///
  /// In en, this message translates to:
  /// **'Tap the bubble that comes first.'**
  String get mapTapFirst;

  /// No description provided for @mapTapNext.
  ///
  /// In en, this message translates to:
  /// **'Now tap the bubble it leads to: that adds an arrow, or removes the one already there. Tap the same bubble again to remove every arrow into it.'**
  String get mapTapNext;

  /// No description provided for @mapDragBubble.
  ///
  /// In en, this message translates to:
  /// **'Drag to move. Use − and + below to change this bubble\'s size.'**
  String get mapDragBubble;

  /// No description provided for @mapDragSelected.
  ///
  /// In en, this message translates to:
  /// **'Drag to move. Use the buttons below to change or remove it.'**
  String get mapDragSelected;

  /// No description provided for @mapDragAnything.
  ///
  /// In en, this message translates to:
  /// **'Drag things to place them. Tap a bubble, title, picture or line to select it.'**
  String get mapDragAnything;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @line.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get line;

  /// No description provided for @narrower.
  ///
  /// In en, this message translates to:
  /// **'Narrower'**
  String get narrower;

  /// No description provided for @wider.
  ///
  /// In en, this message translates to:
  /// **'Wider'**
  String get wider;

  /// No description provided for @tidyUp.
  ///
  /// In en, this message translates to:
  /// **'Tidy up'**
  String get tidyUp;

  /// No description provided for @smaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller'**
  String get smaller;

  /// No description provided for @larger.
  ///
  /// In en, this message translates to:
  /// **'Larger'**
  String get larger;

  /// No description provided for @editText.
  ///
  /// In en, this message translates to:
  /// **'Edit text'**
  String get editText;

  /// No description provided for @couldNotCreateInvite.
  ///
  /// In en, this message translates to:
  /// **'Could not create the invite link.'**
  String get couldNotCreateInvite;

  /// No description provided for @inviteLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite link copied'**
  String get inviteLinkCopied;

  /// No description provided for @removeFromGame.
  ///
  /// In en, this message translates to:
  /// **'Remove from game'**
  String get removeFromGame;

  /// No description provided for @removeFromGameText.
  ///
  /// In en, this message translates to:
  /// **'They lose access right away. Revoke any invite link they still have, or they can join again.'**
  String get removeFromGameText;

  /// No description provided for @access.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get access;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @accessExplanation.
  ///
  /// In en, this message translates to:
  /// **'Full access edits everything. Limited access only sees categories they created or were given, so they can write questions and still play along.'**
  String get accessExplanation;

  /// No description provided for @inviteLinks.
  ///
  /// In en, this message translates to:
  /// **'Invite links'**
  String get inviteLinks;

  /// No description provided for @noInviteLinksYet.
  ///
  /// In en, this message translates to:
  /// **'No invite links yet'**
  String get noInviteLinksYet;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @valid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get valid;

  /// No description provided for @validFor.
  ///
  /// In en, this message translates to:
  /// **'Valid for {time}'**
  String validFor(String time);

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @newRoleLink.
  ///
  /// In en, this message translates to:
  /// **'{role, select, admin{New admin link} full{New full access link} other{New limited access link}}'**
  String newRoleLink(String role);

  /// No description provided for @inviteLinksText.
  ///
  /// In en, this message translates to:
  /// **'Anyone with a link can join until it expires or you revoke it.'**
  String get inviteLinksText;

  /// No description provided for @hourCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String hourCount(int count);

  /// No description provided for @dayCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String dayCount(int count);

  /// No description provided for @notAnInviteLink.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like an invite link.'**
  String get notAnInviteLink;

  /// No description provided for @inviteGone.
  ///
  /// In en, this message translates to:
  /// **'This invite link no longer exists.'**
  String get inviteGone;

  /// No description provided for @inviteExpired.
  ///
  /// In en, this message translates to:
  /// **'This invite link has expired.'**
  String get inviteExpired;

  /// No description provided for @couldNotCheckInvite.
  ///
  /// In en, this message translates to:
  /// **'Could not check the invite link.'**
  String get couldNotCheckInvite;

  /// No description provided for @couldNotJoinGame.
  ///
  /// In en, this message translates to:
  /// **'Could not join. You may already be a member, or the link was revoked.'**
  String get couldNotJoinGame;

  /// No description provided for @joinAGame.
  ///
  /// In en, this message translates to:
  /// **'Join a game'**
  String get joinAGame;

  /// No description provided for @inviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get inviteLink;

  /// No description provided for @unnamedGame.
  ///
  /// In en, this message translates to:
  /// **'Unnamed game'**
  String get unnamedGame;

  /// No description provided for @youWillJoinWith.
  ///
  /// In en, this message translates to:
  /// **'{role, select, admin{You will join with admin.} full{You will join with full access.} other{You will join with limited access.}}'**
  String youWillJoinWith(String role);

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @couldNotCreateSession.
  ///
  /// In en, this message translates to:
  /// **'Could not create the session.'**
  String get couldNotCreateSession;

  /// No description provided for @presentHere.
  ///
  /// In en, this message translates to:
  /// **'Present here'**
  String get presentHere;

  /// No description provided for @presentHereText.
  ///
  /// In en, this message translates to:
  /// **'Another of your devices was presenting this session last. It stops if it is still running.'**
  String get presentHereText;

  /// No description provided for @deleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get deleteSession;

  /// No description provided for @deleteSessionText.
  ///
  /// In en, this message translates to:
  /// **'The session of \"{game}\" with its teams and points will be deleted.'**
  String deleteSessionText(String game);

  /// No description provided for @joinSessionScan.
  ///
  /// In en, this message translates to:
  /// **'Join a session: scan its code'**
  String get joinSessionScan;

  /// No description provided for @joinSessionLink.
  ///
  /// In en, this message translates to:
  /// **'Join a session with its link'**
  String get joinSessionLink;

  /// No description provided for @newSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get newSession;

  /// No description provided for @couldNotLoadSessions.
  ///
  /// In en, this message translates to:
  /// **'Could not load your sessions.'**
  String get couldNotLoadSessions;

  /// No description provided for @noSessionsText.
  ///
  /// In en, this message translates to:
  /// **'A session is one evening\'s show: its teams, points and progress. Create one, present it on the big screen and control it from your phone.'**
  String get noSessionsText;

  /// No description provided for @changeGame.
  ///
  /// In en, this message translates to:
  /// **'Change game'**
  String get changeGame;

  /// No description provided for @createdAt.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String createdAt(String date);

  /// No description provided for @present.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get present;

  /// No description provided for @control.
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get control;

  /// No description provided for @setUpTeamsAndBuzzers.
  ///
  /// In en, this message translates to:
  /// **'Set up teams and buzzers'**
  String get setUpTeamsAndBuzzers;

  /// No description provided for @chooseAGame.
  ///
  /// In en, this message translates to:
  /// **'Choose a game'**
  String get chooseAGame;

  /// No description provided for @gameYouCannotOpen.
  ///
  /// In en, this message translates to:
  /// **'A game you cannot open'**
  String get gameYouCannotOpen;

  /// No description provided for @noGamesForSession.
  ///
  /// In en, this message translates to:
  /// **'You have no games yet. Create one in the Games tab first.'**
  String get noGamesForSession;

  /// No description provided for @game.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get game;

  /// No description provided for @createWithoutGame.
  ///
  /// In en, this message translates to:
  /// **'Create without a game'**
  String get createWithoutGame;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @didNotReachPresenter.
  ///
  /// In en, this message translates to:
  /// **'That did not reach the presenter.'**
  String get didNotReachPresenter;

  /// No description provided for @noDevicePresenting.
  ///
  /// In en, this message translates to:
  /// **'No device is presenting this session. Nothing you do here happens until one presents it.'**
  String get noDevicePresenting;

  /// No description provided for @presentingElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Presenting elsewhere'**
  String get presentingElsewhere;

  /// No description provided for @presentingElsewhereText.
  ///
  /// In en, this message translates to:
  /// **'Another of your devices took over this session.'**
  String get presentingElsewhereText;

  /// No description provided for @couldNotOpenWindow.
  ///
  /// In en, this message translates to:
  /// **'Could not open a second window.'**
  String get couldNotOpenWindow;

  /// No description provided for @couldNotStartPresenting.
  ///
  /// In en, this message translates to:
  /// **'Could not start presenting this session.'**
  String get couldNotStartPresenting;

  /// No description provided for @controlling.
  ///
  /// In en, this message translates to:
  /// **'Controlling'**
  String get controlling;

  /// No description provided for @closePresenterWindow.
  ///
  /// In en, this message translates to:
  /// **'Close presenter window'**
  String get closePresenterWindow;

  /// No description provided for @stopPresenting.
  ///
  /// In en, this message translates to:
  /// **'Stop presenting'**
  String get stopPresenting;

  /// No description provided for @openInNewWindow.
  ///
  /// In en, this message translates to:
  /// **'Open in a new window, to drag onto another screen'**
  String get openInNewWindow;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullscreen;

  /// No description provided for @controls.
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get controls;

  /// No description provided for @buzzerBoxRetrying.
  ///
  /// In en, this message translates to:
  /// **'Buzzer box not connected · retrying'**
  String get buzzerBoxRetrying;

  /// No description provided for @mediaNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 media file could not be downloaded} other{{count} media files could not be downloaded}}'**
  String mediaNotDownloaded(int count);

  /// No description provided for @couldNotSaveChange.
  ///
  /// In en, this message translates to:
  /// **'Could not save the change.'**
  String get couldNotSaveChange;

  /// No description provided for @setUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up {title}'**
  String setUpTitle(String title);

  /// No description provided for @couldNotLoadSession.
  ///
  /// In en, this message translates to:
  /// **'Could not load the session.'**
  String get couldNotLoadSession;

  /// No description provided for @setUpFromControl.
  ///
  /// In en, this message translates to:
  /// **'If this session is on a screen right now, set it up from Control instead: the presenting device keeps its own teams.'**
  String get setUpFromControl;

  /// No description provided for @teams.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get teams;

  /// No description provided for @noTeamsYet.
  ///
  /// In en, this message translates to:
  /// **'No teams yet'**
  String get noTeamsYet;

  /// No description provided for @queueBuzzers.
  ///
  /// In en, this message translates to:
  /// **'Queue buzzers'**
  String get queueBuzzers;

  /// No description provided for @queueBuzzersText.
  ///
  /// In en, this message translates to:
  /// **'Later buzzes line up behind the first'**
  String get queueBuzzersText;

  /// No description provided for @buzzerTest.
  ///
  /// In en, this message translates to:
  /// **'Buzzer test'**
  String get buzzerTest;

  /// No description provided for @buzzerTestText.
  ///
  /// In en, this message translates to:
  /// **'Buzzers light up their team; only from the board'**
  String get buzzerTestText;

  /// No description provided for @buzzerBoxAndSounds.
  ///
  /// In en, this message translates to:
  /// **'Buzzer box and team sounds'**
  String get buzzerBoxAndSounds;

  /// No description provided for @buzzerBoxAndSoundsText.
  ///
  /// In en, this message translates to:
  /// **'The USB buzzer box, and the sound each team buzzes with'**
  String get buzzerBoxAndSoundsText;

  /// No description provided for @connectDevices.
  ///
  /// In en, this message translates to:
  /// **'Connect devices'**
  String get connectDevices;

  /// No description provided for @connectDevicesText.
  ///
  /// In en, this message translates to:
  /// **'Phones as buzzers, or another controller'**
  String get connectDevicesText;

  /// No description provided for @newTeam.
  ///
  /// In en, this message translates to:
  /// **'New team'**
  String get newTeam;

  /// No description provided for @renameTeam.
  ///
  /// In en, this message translates to:
  /// **'Rename team'**
  String get renameTeam;

  /// No description provided for @removeTeam.
  ///
  /// In en, this message translates to:
  /// **'Remove team'**
  String get removeTeam;

  /// No description provided for @removeTeamText.
  ///
  /// In en, this message translates to:
  /// **'\"{team}\" and its points will be removed.'**
  String removeTeamText(String team);

  /// No description provided for @addTeam.
  ///
  /// In en, this message translates to:
  /// **'Add team'**
  String get addTeam;

  /// No description provided for @noTeamsYetText.
  ///
  /// In en, this message translates to:
  /// **'No teams yet. Add them here, or let them join with a code.'**
  String get noTeamsYetText;

  /// No description provided for @couldNotCreateCodes.
  ///
  /// In en, this message translates to:
  /// **'Could not create the codes.'**
  String get couldNotCreateCodes;

  /// No description provided for @controller.
  ///
  /// In en, this message translates to:
  /// **'Controller'**
  String get controller;

  /// No description provided for @scanToControl.
  ///
  /// In en, this message translates to:
  /// **'Scan in Quiz Studio to control this session from another device. That device must be signed in with an account that can open the game.'**
  String get scanToControl;

  /// No description provided for @scanToBuzz.
  ///
  /// In en, this message translates to:
  /// **'Scan in Quiz Studio to use a phone as the buzzer of {team}.'**
  String scanToBuzz(String team);

  /// No description provided for @devicesViaInternet.
  ///
  /// In en, this message translates to:
  /// **'Devices connect through the internet.'**
  String get devicesViaInternet;

  /// No description provided for @devicesViaLan.
  ///
  /// In en, this message translates to:
  /// **'Devices on this network connect directly; others through the internet.'**
  String get devicesViaLan;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @copyLinkInstead.
  ///
  /// In en, this message translates to:
  /// **'Copy link instead'**
  String get copyLinkInstead;

  /// No description provided for @addTeamsFirst.
  ///
  /// In en, this message translates to:
  /// **'Add teams first to get a buzzer code for each.'**
  String get addTeamsFirst;

  /// No description provided for @teamRemoved.
  ///
  /// In en, this message translates to:
  /// **'This team was removed.'**
  String get teamRemoved;

  /// No description provided for @buzzForTeam.
  ///
  /// In en, this message translates to:
  /// **'Buzz for this team'**
  String get buzzForTeam;

  /// No description provided for @setPoints.
  ///
  /// In en, this message translates to:
  /// **'Set points'**
  String get setPoints;

  /// No description provided for @sessionHasNoGame.
  ///
  /// In en, this message translates to:
  /// **'This session has no game yet.'**
  String get sessionHasNoGame;

  /// No description provided for @statusBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get statusBoard;

  /// No description provided for @statusBetsShown.
  ///
  /// In en, this message translates to:
  /// **'The bets are on the big screen · start the question when ready'**
  String get statusBetsShown;

  /// No description provided for @statusBetting.
  ///
  /// In en, this message translates to:
  /// **'Teams are betting · {placed} of {total} bets in'**
  String statusBetting(int placed, int total);

  /// No description provided for @statusRapidDevices.
  ///
  /// In en, this message translates to:
  /// **'Teams pick right or wrong on their devices'**
  String get statusRapidDevices;

  /// No description provided for @statusAmountBet.
  ///
  /// In en, this message translates to:
  /// **'Teams go for the number they bet'**
  String get statusAmountBet;

  /// No description provided for @statusOpenNoBuzzers.
  ///
  /// In en, this message translates to:
  /// **'Question open · no buzzers'**
  String get statusOpenNoBuzzers;

  /// No description provided for @statusOpenWaiting.
  ///
  /// In en, this message translates to:
  /// **'Question open · waiting for a buzz'**
  String get statusOpenWaiting;

  /// No description provided for @statusAnswering.
  ///
  /// In en, this message translates to:
  /// **'{team} is answering'**
  String statusAnswering(String team);

  /// No description provided for @statusAnsweringThen.
  ///
  /// In en, this message translates to:
  /// **'{team} is answering · then {next}'**
  String statusAnsweringThen(String team, String next);

  /// No description provided for @statusAnswerRevealed.
  ///
  /// In en, this message translates to:
  /// **'Answer revealed'**
  String get statusAnswerRevealed;

  /// No description provided for @noGamePicked.
  ///
  /// In en, this message translates to:
  /// **'No game picked yet. Choose one for this session in the sessions list.'**
  String get noGamePicked;

  /// No description provided for @groupHasNoQuestions.
  ///
  /// In en, this message translates to:
  /// **'This group has no questions.'**
  String get groupHasNoQuestions;

  /// No description provided for @questionsPlayed.
  ///
  /// In en, this message translates to:
  /// **'{played} of {total} questions played'**
  String questionsPlayed(int played, int total);

  /// No description provided for @teamsBetTheirPoints.
  ///
  /// In en, this message translates to:
  /// **'teams bet their points'**
  String get teamsBetTheirPoints;

  /// No description provided for @betQuestionShown.
  ///
  /// In en, this message translates to:
  /// **'Bet question: {prompt}'**
  String betQuestionShown(String prompt);

  /// No description provided for @enlargedImage.
  ///
  /// In en, this message translates to:
  /// **'Enlarged image'**
  String get enlargedImage;

  /// No description provided for @noStrikes.
  ///
  /// In en, this message translates to:
  /// **'No strikes'**
  String get noStrikes;

  /// No description provided for @strikes.
  ///
  /// In en, this message translates to:
  /// **'Strikes'**
  String get strikes;

  /// No description provided for @resetStrikes.
  ///
  /// In en, this message translates to:
  /// **'Reset strikes'**
  String get resetStrikes;

  /// No description provided for @buzzBeforeUncover.
  ///
  /// In en, this message translates to:
  /// **'A team has to buzz before answers can be uncovered.'**
  String get buzzBeforeUncover;

  /// No description provided for @betFor.
  ///
  /// In en, this message translates to:
  /// **'Bet for {team}'**
  String betFor(String team);

  /// No description provided for @betRange.
  ///
  /// In en, this message translates to:
  /// **'0 to {limit} points'**
  String betRange(int limit);

  /// No description provided for @betsTapTeam.
  ///
  /// In en, this message translates to:
  /// **'Bets · tap a team to enter its bet'**
  String get betsTapTeam;

  /// No description provided for @bets.
  ///
  /// In en, this message translates to:
  /// **'Bets'**
  String get bets;

  /// No description provided for @upTo.
  ///
  /// In en, this message translates to:
  /// **'up to {limit}'**
  String upTo(int limit);

  /// No description provided for @noBet.
  ///
  /// In en, this message translates to:
  /// **'no bet'**
  String get noBet;

  /// No description provided for @allPointsGiven.
  ///
  /// In en, this message translates to:
  /// **'All points given'**
  String get allPointsGiven;

  /// No description provided for @givePoints.
  ///
  /// In en, this message translates to:
  /// **'Give points'**
  String get givePoints;

  /// No description provided for @givePointsToTeams.
  ///
  /// In en, this message translates to:
  /// **'Give points to {count} teams'**
  String givePointsToTeams(int count);

  /// No description provided for @given.
  ///
  /// In en, this message translates to:
  /// **'Given'**
  String get given;

  /// No description provided for @notGivenYet.
  ///
  /// In en, this message translates to:
  /// **'Not given yet'**
  String get notGivenYet;

  /// No description provided for @givenSoFar.
  ///
  /// In en, this message translates to:
  /// **'Given {points} so far'**
  String givenSoFar(String points);

  /// No description provided for @takeOutOfOrder.
  ///
  /// In en, this message translates to:
  /// **'Take out of the order'**
  String get takeOutOfOrder;

  /// No description provided for @putNextInOrder.
  ///
  /// In en, this message translates to:
  /// **'Put next in order'**
  String get putNextInOrder;

  /// No description provided for @pointsFor.
  ///
  /// In en, this message translates to:
  /// **'Points for {team}'**
  String pointsFor(String team);

  /// No description provided for @pointsForQuestion.
  ///
  /// In en, this message translates to:
  /// **'Points for this question'**
  String get pointsForQuestion;

  /// No description provided for @didTeamsReach.
  ///
  /// In en, this message translates to:
  /// **'Did each team reach its number?'**
  String get didTeamsReach;

  /// No description provided for @tapInOrder.
  ///
  /// In en, this message translates to:
  /// **'Tap the teams in order as they finish · {points}, then {step} less each'**
  String tapInOrder(String points, int step);

  /// No description provided for @rateEachTeam.
  ///
  /// In en, this message translates to:
  /// **'Rate each team'**
  String get rateEachTeam;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'goal {goal}'**
  String goal(int goal);

  /// No description provided for @otherPoints.
  ///
  /// In en, this message translates to:
  /// **'Other points'**
  String get otherPoints;

  /// No description provided for @otherPointsMenu.
  ///
  /// In en, this message translates to:
  /// **'Other points…'**
  String get otherPointsMenu;

  /// No description provided for @reached.
  ///
  /// In en, this message translates to:
  /// **'Reached'**
  String get reached;

  /// No description provided for @missed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get missed;

  /// No description provided for @pointsForAnswer.
  ///
  /// In en, this message translates to:
  /// **'Points for this answer'**
  String get pointsForAnswer;

  /// No description provided for @teamWins.
  ///
  /// In en, this message translates to:
  /// **'{team} wins · +{points}'**
  String teamWins(String team, int points);

  /// No description provided for @teamsTurn.
  ///
  /// In en, this message translates to:
  /// **'{team}\'s turn'**
  String teamsTurn(String team);

  /// No description provided for @nobodyLeft.
  ///
  /// In en, this message translates to:
  /// **'Nobody left'**
  String get nobodyLeft;

  /// No description provided for @noPromptsLeft.
  ///
  /// In en, this message translates to:
  /// **'No prompts left'**
  String get noPromptsLeft;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @rapidNoItems.
  ///
  /// In en, this message translates to:
  /// **'This Fragenhagel has no items yet.'**
  String get rapidNoItems;

  /// No description provided for @answerShown.
  ///
  /// In en, this message translates to:
  /// **'Answer: {answer}'**
  String answerShown(String answer);

  /// No description provided for @allDone.
  ///
  /// In en, this message translates to:
  /// **'All {count} done'**
  String allDone(int count);

  /// No description provided for @itemOf.
  ///
  /// In en, this message translates to:
  /// **'Item {item} of {count}'**
  String itemOf(int item, int count);

  /// No description provided for @topAnswersEmpty.
  ///
  /// In en, this message translates to:
  /// **'This question has no answers on its list yet.'**
  String get topAnswersEmpty;

  /// No description provided for @topTapToUncover.
  ///
  /// In en, this message translates to:
  /// **'Tap an answer to uncover it on the big screen.'**
  String get topTapToUncover;

  /// No description provided for @topTapNamed.
  ///
  /// In en, this message translates to:
  /// **'Tap the answer {team} named. Wrong if it is not on the list.'**
  String topTapNamed(String team);

  /// No description provided for @topWhenBuzz.
  ///
  /// In en, this message translates to:
  /// **'When a team buzzes, tap the answer it names.'**
  String get topWhenBuzz;

  /// No description provided for @revealGroupNow.
  ///
  /// In en, this message translates to:
  /// **'Reveal a group now?'**
  String get revealGroupNow;

  /// No description provided for @revealGroupNowText.
  ///
  /// In en, this message translates to:
  /// **'The teams are still playing and will see this group on their devices too. Their time keeps running.'**
  String get revealGroupNowText;

  /// No description provided for @reveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get reveal;

  /// No description provided for @stealWorked.
  ///
  /// In en, this message translates to:
  /// **'Steal worked'**
  String get stealWorked;

  /// No description provided for @stealFailed.
  ///
  /// In en, this message translates to:
  /// **'Steal failed'**
  String get stealFailed;

  /// No description provided for @strike.
  ///
  /// In en, this message translates to:
  /// **'Strike'**
  String get strike;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @betsAreIn.
  ///
  /// In en, this message translates to:
  /// **'Bets are in'**
  String get betsAreIn;

  /// No description provided for @startQuestion.
  ///
  /// In en, this message translates to:
  /// **'Start question'**
  String get startQuestion;

  /// No description provided for @showAnswer.
  ///
  /// In en, this message translates to:
  /// **'Show answer'**
  String get showAnswer;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @nextItem.
  ///
  /// In en, this message translates to:
  /// **'Next item'**
  String get nextItem;

  /// No description provided for @solution.
  ///
  /// In en, this message translates to:
  /// **'Solution'**
  String get solution;

  /// No description provided for @revealGroup.
  ///
  /// In en, this message translates to:
  /// **'Reveal group'**
  String get revealGroup;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @nextTeam.
  ///
  /// In en, this message translates to:
  /// **'Next team'**
  String get nextTeam;

  /// No description provided for @reopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get reopen;

  /// No description provided for @tabBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get tabBoard;

  /// No description provided for @tabEffects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get tabEffects;

  /// No description provided for @tabAnswers.
  ///
  /// In en, this message translates to:
  /// **'Answers'**
  String get tabAnswers;

  /// No description provided for @tabSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get tabSetup;

  /// No description provided for @ungrouped.
  ///
  /// In en, this message translates to:
  /// **'Ungrouped'**
  String get ungrouped;

  /// No description provided for @groupHasNoCategories.
  ///
  /// In en, this message translates to:
  /// **'This group has no categories.'**
  String get groupHasNoCategories;

  /// No description provided for @showCategoryInMiddle.
  ///
  /// In en, this message translates to:
  /// **'Show this category in the middle'**
  String get showCategoryInMiddle;

  /// No description provided for @tapFieldToRead.
  ///
  /// In en, this message translates to:
  /// **'Tap a field to read its question.'**
  String get tapFieldToRead;

  /// No description provided for @onScreen.
  ///
  /// In en, this message translates to:
  /// **'on screen'**
  String get onScreen;

  /// No description provided for @played.
  ///
  /// In en, this message translates to:
  /// **'played'**
  String get played;

  /// No description provided for @takeOffKeepPlayable.
  ///
  /// In en, this message translates to:
  /// **'Take off screen, keep playable'**
  String get takeOffKeepPlayable;

  /// No description provided for @markNotPlayed.
  ///
  /// In en, this message translates to:
  /// **'Mark as not played'**
  String get markNotPlayed;

  /// No description provided for @openQuestion.
  ///
  /// In en, this message translates to:
  /// **'Open question'**
  String get openQuestion;

  /// No description provided for @slotBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get slotBoard;

  /// No description provided for @slotCalm.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get slotCalm;

  /// No description provided for @slotThrilling.
  ///
  /// In en, this message translates to:
  /// **'Thrilling'**
  String get slotThrilling;

  /// No description provided for @effectClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get effectClosed;

  /// No description provided for @effectLockedIn.
  ///
  /// In en, this message translates to:
  /// **'Locked in'**
  String get effectLockedIn;

  /// No description provided for @effectCountdown.
  ///
  /// In en, this message translates to:
  /// **'Countdown'**
  String get effectCountdown;

  /// No description provided for @effectFanfare.
  ///
  /// In en, this message translates to:
  /// **'Fanfare'**
  String get effectFanfare;

  /// No description provided for @onScreenHeader.
  ///
  /// In en, this message translates to:
  /// **'On screen'**
  String get onScreenHeader;

  /// No description provided for @animation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get animation;

  /// No description provided for @noCardsPrepare.
  ///
  /// In en, this message translates to:
  /// **'No cards. Prepare some in the editor.'**
  String get noCardsPrepare;

  /// No description provided for @textToShow.
  ///
  /// In en, this message translates to:
  /// **'Text to show'**
  String get textToShow;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @noCardOnScreen.
  ///
  /// In en, this message translates to:
  /// **'No card on screen'**
  String get noCardOnScreen;

  /// No description provided for @takeCardOff.
  ///
  /// In en, this message translates to:
  /// **'Take card off screen'**
  String get takeCardOff;

  /// No description provided for @keepSpeakersAwake.
  ///
  /// In en, this message translates to:
  /// **'Keep speakers awake'**
  String get keepSpeakersAwake;

  /// No description provided for @fewerDetails.
  ///
  /// In en, this message translates to:
  /// **'Fewer details'**
  String get fewerDetails;

  /// No description provided for @whatIsThis.
  ///
  /// In en, this message translates to:
  /// **'What is this?'**
  String get whatIsThis;

  /// No description provided for @keepSpeakersAwakeText.
  ///
  /// In en, this message translates to:
  /// **'Many speakers switch themselves off after a few minutes of silence and miss the start of the next sound. This plays a very quiet noise whenever nothing else plays; music and question sounds take over as they start.'**
  String get keepSpeakersAwakeText;

  /// No description provided for @softNoise.
  ///
  /// In en, this message translates to:
  /// **'Soft noise'**
  String get softNoise;

  /// No description provided for @whiteNoise.
  ///
  /// In en, this message translates to:
  /// **'White noise'**
  String get whiteNoise;

  /// No description provided for @noiseVolume.
  ///
  /// In en, this message translates to:
  /// **'Noise {volume} %'**
  String noiseVolume(int volume);

  /// No description provided for @soundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get soundEffects;

  /// No description provided for @questionSound.
  ///
  /// In en, this message translates to:
  /// **'Question sound'**
  String get questionSound;

  /// No description provided for @answersOnDevices.
  ///
  /// In en, this message translates to:
  /// **'Answers on the teams\' devices'**
  String get answersOnDevices;

  /// No description provided for @openAQuestionFirst.
  ///
  /// In en, this message translates to:
  /// **'Open a question first.'**
  String get openAQuestionFirst;

  /// No description provided for @answersOnDevicesText.
  ///
  /// In en, this message translates to:
  /// **'Every team answers on its own device. You see the answers as they come in; the audience only when you show them.'**
  String get answersOnDevicesText;

  /// No description provided for @preparedScreensText.
  ///
  /// In en, this message translates to:
  /// **'Sliders, sorting, matching and prepared whiteboards are set up per question in the editor and start by themselves.'**
  String get preparedScreensText;

  /// No description provided for @roundOpen.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get roundOpen;

  /// No description provided for @roundLocked.
  ///
  /// In en, this message translates to:
  /// **'locked'**
  String get roundLocked;

  /// No description provided for @answersIn.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} in'**
  String answersIn(int count, int total);

  /// No description provided for @lockAll.
  ///
  /// In en, this message translates to:
  /// **'Lock all'**
  String get lockAll;

  /// No description provided for @letThemEditAgain.
  ///
  /// In en, this message translates to:
  /// **'Let them edit again'**
  String get letThemEditAgain;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @rateAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Rate automatically'**
  String get rateAutomatically;

  /// No description provided for @givePointsForGroups.
  ///
  /// In en, this message translates to:
  /// **'Give points for groups'**
  String get givePointsForGroups;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @solutionShown.
  ///
  /// In en, this message translates to:
  /// **'Solution: {solution}'**
  String solutionShown(String solution);

  /// No description provided for @partialRight.
  ///
  /// In en, this message translates to:
  /// **'{right} of {total} right'**
  String partialRight(int right, int total);

  /// No description provided for @looksRight.
  ///
  /// In en, this message translates to:
  /// **'Looks right'**
  String get looksRight;

  /// No description provided for @looksWrong.
  ///
  /// In en, this message translates to:
  /// **'Looks wrong'**
  String get looksWrong;

  /// No description provided for @takeOffScreen.
  ///
  /// In en, this message translates to:
  /// **'Take off screen'**
  String get takeOffScreen;

  /// No description provided for @showOnScreen.
  ///
  /// In en, this message translates to:
  /// **'Show on screen'**
  String get showOnScreen;

  /// No description provided for @halfPoints.
  ///
  /// In en, this message translates to:
  /// **'Half points (+{points})'**
  String halfPoints(int points);

  /// No description provided for @outPlaceLabel.
  ///
  /// In en, this message translates to:
  /// **'{place} out'**
  String outPlaceLabel(String place);

  /// No description provided for @waitingForGame.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a game…'**
  String get waitingForGame;

  /// No description provided for @betValue.
  ///
  /// In en, this message translates to:
  /// **'Bet {bet}'**
  String betValue(int bet);

  /// No description provided for @goalValue.
  ///
  /// In en, this message translates to:
  /// **'Goal {goal}'**
  String goalValue(int goal);

  /// No description provided for @howManyCanYouDo.
  ///
  /// In en, this message translates to:
  /// **'How many can you do?'**
  String get howManyCanYouDo;

  /// No description provided for @theBets.
  ///
  /// In en, this message translates to:
  /// **'The bets'**
  String get theBets;

  /// No description provided for @placeYourBets.
  ///
  /// In en, this message translates to:
  /// **'Place your bets'**
  String get placeYourBets;

  /// No description provided for @betRule.
  ///
  /// In en, this message translates to:
  /// **'Right wins your bet, wrong loses it'**
  String get betRule;

  /// No description provided for @amountRuleWithMinus.
  ///
  /// In en, this message translates to:
  /// **'Reach your number: {plus} points for each one · miss it: −{minus} for each'**
  String amountRuleWithMinus(int plus, int minus);

  /// No description provided for @amountRule.
  ///
  /// In en, this message translates to:
  /// **'Reach your number: {plus} points for each one'**
  String amountRule(int plus);

  /// No description provided for @findFourGroups.
  ///
  /// In en, this message translates to:
  /// **'Find four groups of four'**
  String get findFourGroups;

  /// No description provided for @isLastTeamStanding.
  ///
  /// In en, this message translates to:
  /// **'is the last team standing'**
  String get isLastTeamStanding;

  /// No description provided for @thatWasTheLastOne.
  ///
  /// In en, this message translates to:
  /// **'That was the last one!'**
  String get thatWasTheLastOne;

  /// No description provided for @thenTeams.
  ///
  /// In en, this message translates to:
  /// **'then {teams}'**
  String thenTeams(String teams);

  /// No description provided for @noColour.
  ///
  /// In en, this message translates to:
  /// **'No colour'**
  String get noColour;

  /// No description provided for @useThisColour.
  ///
  /// In en, this message translates to:
  /// **'Use this colour'**
  String get useThisColour;

  /// No description provided for @presenterWindowTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz Studio · Presenter'**
  String get presenterWindowTitle;

  /// No description provided for @reconnectingMainWindow.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to the main window…'**
  String get reconnectingMainWindow;

  /// No description provided for @connectingMainWindow.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the main window…'**
  String get connectingMainWindow;

  /// No description provided for @leaveFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Leave full screen (Esc)'**
  String get leaveFullScreen;

  /// No description provided for @fullScreenF11.
  ///
  /// In en, this message translates to:
  /// **'Full screen (F11)'**
  String get fullScreenF11;

  /// No description provided for @dragToProjector.
  ///
  /// In en, this message translates to:
  /// **'Drag this window to the projector, then double-click it or press F11 for full screen.'**
  String get dragToProjector;

  /// No description provided for @pictureLabel.
  ///
  /// In en, this message translates to:
  /// **'Picture {label}'**
  String pictureLabel(String label);

  /// No description provided for @yourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get yourAnswer;

  /// No description provided for @slideToAnswer.
  ///
  /// In en, this message translates to:
  /// **'Slide to answer'**
  String get slideToAnswer;

  /// No description provided for @dragIntoOrder.
  ///
  /// In en, this message translates to:
  /// **'Drag into the right order'**
  String get dragIntoOrder;

  /// No description provided for @foundOfFour.
  ///
  /// In en, this message translates to:
  /// **'{count} of 4 found'**
  String foundOfFour(int count);

  /// No description provided for @mistakeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 mistake} other{{count} mistakes}}'**
  String mistakeCount(int count);

  /// No description provided for @yourPairs.
  ///
  /// In en, this message translates to:
  /// **'Your pairs'**
  String get yourPairs;

  /// No description provided for @tapWhereItGoes.
  ///
  /// In en, this message translates to:
  /// **'Now tap where “{item}” goes'**
  String tapWhereItGoes(String item);

  /// No description provided for @allPlacedSwap.
  ///
  /// In en, this message translates to:
  /// **'All placed · drag to swap'**
  String get allPlacedSwap;

  /// No description provided for @dragOntoPartner.
  ///
  /// In en, this message translates to:
  /// **'Drag each answer onto its partner'**
  String get dragOntoPartner;

  /// No description provided for @dropToTakeBack.
  ///
  /// In en, this message translates to:
  /// **'Drop here to take it back'**
  String get dropToTakeBack;

  /// No description provided for @allPlaced.
  ///
  /// In en, this message translates to:
  /// **'All placed'**
  String get allPlaced;

  /// No description provided for @praisePerfect.
  ///
  /// In en, this message translates to:
  /// **'Perfect!'**
  String get praisePerfect;

  /// No description provided for @praiseGreat.
  ///
  /// In en, this message translates to:
  /// **'Great!'**
  String get praiseGreat;

  /// No description provided for @praiseNice.
  ///
  /// In en, this message translates to:
  /// **'Nice!'**
  String get praiseNice;

  /// No description provided for @praiseSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid!'**
  String get praiseSolid;

  /// No description provided for @allFourFound.
  ///
  /// In en, this message translates to:
  /// **'All four found!'**
  String get allFourFound;

  /// No description provided for @noTriesLeft.
  ///
  /// In en, this message translates to:
  /// **'No tries left'**
  String get noTriesLeft;

  /// No description provided for @oneAway.
  ///
  /// In en, this message translates to:
  /// **'One away…'**
  String get oneAway;

  /// No description provided for @notAGroup.
  ///
  /// In en, this message translates to:
  /// **'Not a group'**
  String get notAGroup;

  /// No description provided for @alreadyGuessed.
  ///
  /// In en, this message translates to:
  /// **'Already guessed'**
  String get alreadyGuessed;

  /// No description provided for @allFourGroupsFound.
  ///
  /// In en, this message translates to:
  /// **'All four groups found'**
  String get allFourGroupsFound;

  /// No description provided for @noTriesLeftWait.
  ///
  /// In en, this message translates to:
  /// **'No tries left. Wait for the solution'**
  String get noTriesLeftWait;

  /// No description provided for @lockedInWith.
  ///
  /// In en, this message translates to:
  /// **'Locked in with {count} of 4'**
  String lockedInWith(int count);

  /// No description provided for @timeIsUp.
  ///
  /// In en, this message translates to:
  /// **'Time is up'**
  String get timeIsUp;

  /// No description provided for @mistakesRemaining.
  ///
  /// In en, this message translates to:
  /// **'Mistakes remaining:'**
  String get mistakesRemaining;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get deselectAll;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @wereDone.
  ///
  /// In en, this message translates to:
  /// **'We\'re done'**
  String get wereDone;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @notASessionCode.
  ///
  /// In en, this message translates to:
  /// **'That is not a Quiz Studio session code.'**
  String get notASessionCode;

  /// No description provided for @couldNotJoinSession.
  ///
  /// In en, this message translates to:
  /// **'Could not join. The code may no longer be valid.'**
  String get couldNotJoinSession;

  /// No description provided for @session.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get session;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String daysAgo(int count);

  /// No description provided for @rejoinAsTeam.
  ///
  /// In en, this message translates to:
  /// **'Rejoin as a team\'s device'**
  String get rejoinAsTeam;

  /// No description provided for @rejoinAsController.
  ///
  /// In en, this message translates to:
  /// **'Rejoin as controller'**
  String get rejoinAsController;

  /// No description provided for @joinedAgo.
  ///
  /// In en, this message translates to:
  /// **'Joined {ago}'**
  String joinedAgo(String ago);

  /// No description provided for @joinLink.
  ///
  /// In en, this message translates to:
  /// **'Join link'**
  String get joinLink;

  /// No description provided for @orPasteLink.
  ///
  /// In en, this message translates to:
  /// **'Or paste the link'**
  String get orPasteLink;

  /// No description provided for @joinTerms.
  ///
  /// In en, this message translates to:
  /// **'By joining you agree to the terms and privacy policy. No account or name needed.'**
  String get joinTerms;

  /// No description provided for @joinASession.
  ///
  /// In en, this message translates to:
  /// **'Join a session'**
  String get joinASession;

  /// No description provided for @pasteJoinLinkHelp.
  ///
  /// In en, this message translates to:
  /// **'Open \"Connect devices\" on the presenting device, copy the join link there and paste it here.'**
  String get pasteJoinLinkHelp;

  /// No description provided for @didNotGetThrough.
  ///
  /// In en, this message translates to:
  /// **'That did not get through.'**
  String get didNotGetThrough;

  /// No description provided for @couldNotReachSession.
  ///
  /// In en, this message translates to:
  /// **'Could not reach this session.'**
  String get couldNotReachSession;

  /// No description provided for @waitingForShow.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the show to start…'**
  String get waitingForShow;

  /// No description provided for @teamRemovedFromSession.
  ///
  /// In en, this message translates to:
  /// **'Your team was removed from the session.'**
  String get teamRemovedFromSession;

  /// No description provided for @youAreLastTeam.
  ///
  /// In en, this message translates to:
  /// **'You are the last team standing!'**
  String get youAreLastTeam;

  /// No description provided for @teamWinsShort.
  ///
  /// In en, this message translates to:
  /// **'{team} wins'**
  String teamWinsShort(String team);

  /// No description provided for @youAreOut.
  ///
  /// In en, this message translates to:
  /// **'You are out'**
  String get youAreOut;

  /// No description provided for @yourTurn.
  ///
  /// In en, this message translates to:
  /// **'Your turn!'**
  String get yourTurn;

  /// No description provided for @buzzerTestPress.
  ///
  /// In en, this message translates to:
  /// **'Buzzer test: press to check'**
  String get buzzerTestPress;

  /// No description provided for @waitingForNextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the next question'**
  String get waitingForNextQuestion;

  /// No description provided for @yourGoal.
  ///
  /// In en, this message translates to:
  /// **'Your goal: {goal}'**
  String yourGoal(int goal);

  /// No description provided for @goalReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached!'**
  String get goalReached;

  /// No description provided for @goalMissed.
  ///
  /// In en, this message translates to:
  /// **'Goal missed'**
  String get goalMissed;

  /// No description provided for @buzzOnBox.
  ///
  /// In en, this message translates to:
  /// **'Buzz on the buzzer box'**
  String get buzzOnBox;

  /// No description provided for @buzzWhenYouKnow.
  ///
  /// In en, this message translates to:
  /// **'Buzz when you know it!'**
  String get buzzWhenYouKnow;

  /// No description provided for @noBuzzersForQuestion.
  ///
  /// In en, this message translates to:
  /// **'No buzzers for this question'**
  String get noBuzzersForQuestion;

  /// No description provided for @numberInLine.
  ///
  /// In en, this message translates to:
  /// **'You are number {n} in line'**
  String numberInLine(int n);

  /// No description provided for @anotherTeam.
  ///
  /// In en, this message translates to:
  /// **'Another team'**
  String get anotherTeam;

  /// No description provided for @needsNewerVersion.
  ///
  /// In en, this message translates to:
  /// **'This question needs a newer version of Quiz Studio. Please update the app.'**
  String get needsNewerVersion;

  /// No description provided for @answerHere.
  ///
  /// In en, this message translates to:
  /// **'Answer here'**
  String get answerHere;

  /// No description provided for @answerBeingShown.
  ///
  /// In en, this message translates to:
  /// **'Your answer is being shown'**
  String get answerBeingShown;

  /// No description provided for @lockedInWaiting.
  ///
  /// In en, this message translates to:
  /// **'Locked in, waiting for the others'**
  String get lockedInWaiting;

  /// No description provided for @answersAreIn.
  ///
  /// In en, this message translates to:
  /// **'Answers are in'**
  String get answersAreIn;

  /// No description provided for @pointsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point} other{{count} points}}'**
  String pointsCount(int count);

  /// No description provided for @betShort.
  ///
  /// In en, this message translates to:
  /// **'bet {bet}'**
  String betShort(int bet);

  /// No description provided for @rightExclaim.
  ///
  /// In en, this message translates to:
  /// **'Right!'**
  String get rightExclaim;

  /// No description provided for @notThisTime.
  ///
  /// In en, this message translates to:
  /// **'Not this time'**
  String get notThisTime;

  /// No description provided for @answerCountsWhenEnded.
  ///
  /// In en, this message translates to:
  /// **'Your answer counts as it stands when the gamemaster ends the round.'**
  String get answerCountsWhenEnded;

  /// No description provided for @answerCountsWhenTimeUp.
  ///
  /// In en, this message translates to:
  /// **'Your answer counts as it stands when the time is up.'**
  String get answerCountsWhenTimeUp;

  /// No description provided for @lockedIn.
  ///
  /// In en, this message translates to:
  /// **'Locked in'**
  String get lockedIn;

  /// No description provided for @lockedInAfter.
  ///
  /// In en, this message translates to:
  /// **'Locked in after {seconds} s'**
  String lockedInAfter(String seconds);

  /// No description provided for @lockInAnswer.
  ///
  /// In en, this message translates to:
  /// **'Lock in answer'**
  String get lockInAnswer;

  /// No description provided for @answerFirst.
  ///
  /// In en, this message translates to:
  /// **'Answer first'**
  String get answerFirst;

  /// No description provided for @answerOnBigScreen.
  ///
  /// In en, this message translates to:
  /// **'Your answer is on the big screen.'**
  String get answerOnBigScreen;

  /// No description provided for @gettingPicture.
  ///
  /// In en, this message translates to:
  /// **'Getting the picture…'**
  String get gettingPicture;

  /// No description provided for @connectedLan.
  ///
  /// In en, this message translates to:
  /// **'Connected over the local network'**
  String get connectedLan;

  /// No description provided for @connectedInternet.
  ///
  /// In en, this message translates to:
  /// **'Connected through the internet'**
  String get connectedInternet;

  /// No description provided for @yourBetOn.
  ///
  /// In en, this message translates to:
  /// **'Your bet on {category}'**
  String yourBetOn(String category);

  /// No description provided for @placeYourBet.
  ///
  /// In en, this message translates to:
  /// **'Place your bet'**
  String get placeYourBet;

  /// No description provided for @theGoals.
  ///
  /// In en, this message translates to:
  /// **'The goals'**
  String get theGoals;

  /// No description provided for @betOutcome.
  ///
  /// In en, this message translates to:
  /// **'Right: +{value} · Wrong: −{value}'**
  String betOutcome(int value);

  /// No description provided for @amountOutcomeWithMinus.
  ///
  /// In en, this message translates to:
  /// **'If successful: +{win} · Missed: −{lose}'**
  String amountOutcomeWithMinus(int win, int lose);

  /// No description provided for @amountOutcome.
  ///
  /// In en, this message translates to:
  /// **'If successful: +{win}'**
  String amountOutcome(int win);

  /// No description provided for @betNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get betNothing;

  /// No description provided for @betHalf.
  ///
  /// In en, this message translates to:
  /// **'Half'**
  String get betHalf;

  /// No description provided for @allIn.
  ///
  /// In en, this message translates to:
  /// **'All in'**
  String get allIn;

  /// No description provided for @questionStartsSoon.
  ///
  /// In en, this message translates to:
  /// **'The question starts in a moment'**
  String get questionStartsSoon;

  /// No description provided for @betPlaced.
  ///
  /// In en, this message translates to:
  /// **'Bet placed'**
  String get betPlaced;

  /// No description provided for @changeTo.
  ///
  /// In en, this message translates to:
  /// **'Change to {value}'**
  String changeTo(int value);

  /// No description provided for @betAction.
  ///
  /// In en, this message translates to:
  /// **'Bet {value}'**
  String betAction(int value);

  /// No description provided for @buzzerSoundTooBig.
  ///
  /// In en, this message translates to:
  /// **'This file is too big; a buzzer sound can be up to 5 MB.'**
  String get buzzerSoundTooBig;

  /// No description provided for @notASoundFile.
  ///
  /// In en, this message translates to:
  /// **'This is not a sound file the app can play.'**
  String get notASoundFile;

  /// No description provided for @couldNotUploadBuzzerSound.
  ///
  /// In en, this message translates to:
  /// **'Could not upload the sound. The team keeps the one it had.'**
  String get couldNotUploadBuzzerSound;

  /// No description provided for @buzzers.
  ///
  /// In en, this message translates to:
  /// **'Buzzers'**
  String get buzzers;

  /// No description provided for @useUsbBox.
  ///
  /// In en, this message translates to:
  /// **'Use a USB buzzer box'**
  String get useUsbBox;

  /// No description provided for @useUsbBoxText.
  ///
  /// In en, this message translates to:
  /// **'Off: teams buzz with their phones only, and the big screen does not look for a box.'**
  String get useUsbBoxText;

  /// No description provided for @usbBoxPlatforms.
  ///
  /// In en, this message translates to:
  /// **'A USB buzzer box works on Windows, macOS and Linux. Phones and tablets can still be buzzers: see Connect devices.'**
  String get usbBoxPlatforms;

  /// No description provided for @buzzerSounds.
  ///
  /// In en, this message translates to:
  /// **'Buzzer sounds'**
  String get buzzerSounds;

  /// No description provided for @buzzerSoundsText.
  ///
  /// In en, this message translates to:
  /// **'Saved with the session and played by whichever device presents. Until that device has fetched a sound, and for teams without one, the built-in buzzer plays.'**
  String get buzzerSoundsText;

  /// No description provided for @ownSound.
  ///
  /// In en, this message translates to:
  /// **'Own sound'**
  String get ownSound;

  /// No description provided for @chooseBuzzerSound.
  ///
  /// In en, this message translates to:
  /// **'Choose a buzzer sound'**
  String get chooseBuzzerSound;

  /// No description provided for @uploadOwnSound.
  ///
  /// In en, this message translates to:
  /// **'Upload own sound…'**
  String get uploadOwnSound;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @backToBuiltinBuzzer.
  ///
  /// In en, this message translates to:
  /// **'Back to the built-in buzzer'**
  String get backToBuiltinBuzzer;

  /// No description provided for @addTeamsFirstShort.
  ///
  /// In en, this message translates to:
  /// **'Add teams first.'**
  String get addTeamsFirstShort;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @clearOrder.
  ///
  /// In en, this message translates to:
  /// **'Clear order'**
  String get clearOrder;

  /// No description provided for @calibrate.
  ///
  /// In en, this message translates to:
  /// **'Calibrate'**
  String get calibrate;

  /// No description provided for @buzzersAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Buzzers appear here as soon as the box sends readings.'**
  String get buzzersAppearHere;

  /// No description provided for @pressTheBuzzers.
  ///
  /// In en, this message translates to:
  /// **'Press the buzzers. Each lights up while it is held, and the numbers show who was first. Tap one to change its team or sensitivity.'**
  String get pressTheBuzzers;

  /// No description provided for @assignAllByPressing.
  ///
  /// In en, this message translates to:
  /// **'Assign all by pressing'**
  String get assignAllByPressing;

  /// No description provided for @pressBuzzerOf.
  ///
  /// In en, this message translates to:
  /// **'Press the buzzer of {team} now'**
  String pressBuzzerOf(String team);

  /// No description provided for @moreToGo.
  ///
  /// In en, this message translates to:
  /// **'{count} more to go'**
  String moreToGo(int count);

  /// No description provided for @defaultAssignment.
  ///
  /// In en, this message translates to:
  /// **'Without anything assigned, buzzer 1 is the first team, buzzer 2 the second, and so on.'**
  String get defaultAssignment;

  /// No description provided for @noBuzzer.
  ///
  /// In en, this message translates to:
  /// **'No buzzer'**
  String get noBuzzer;

  /// No description provided for @buzzerN.
  ///
  /// In en, this message translates to:
  /// **'Buzzer {n}'**
  String buzzerN(int n);

  /// No description provided for @assignByPressing.
  ///
  /// In en, this message translates to:
  /// **'Assign by pressing'**
  String get assignByPressing;

  /// No description provided for @addTeamsInSessionFirst.
  ///
  /// In en, this message translates to:
  /// **'Add teams in the session first.'**
  String get addTeamsInSessionFirst;

  /// No description provided for @rawData.
  ///
  /// In en, this message translates to:
  /// **'Raw data'**
  String get rawData;

  /// No description provided for @rawDataText.
  ///
  /// In en, this message translates to:
  /// **'Exactly what the box sends, for finding faults'**
  String get rawDataText;

  /// No description provided for @nothingReceivedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing received yet.'**
  String get nothingReceivedYet;

  /// No description provided for @notConnectedDot.
  ///
  /// In en, this message translates to:
  /// **'Not connected.'**
  String get notConnectedDot;

  /// No description provided for @team.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get team;

  /// No description provided for @byPosition.
  ///
  /// In en, this message translates to:
  /// **'By position'**
  String get byPosition;

  /// No description provided for @howHardPressed.
  ///
  /// In en, this message translates to:
  /// **'How hard it has to be pressed'**
  String get howHardPressed;

  /// No description provided for @readingThreshold.
  ///
  /// In en, this message translates to:
  /// **'Reading {value} · counts as pressed above {threshold}'**
  String readingThreshold(int value, int threshold);

  /// No description provided for @noBuzzerPressedClearly.
  ///
  /// In en, this message translates to:
  /// **'No buzzer was pressed clearly.'**
  String get noBuzzerPressedClearly;

  /// No description provided for @calibratedBuzzers.
  ///
  /// In en, this message translates to:
  /// **'Calibrated {count} buzzers.'**
  String calibratedBuzzers(int count);

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @readingsPerSecond.
  ///
  /// In en, this message translates to:
  /// **'{rate} readings per second · up {uptime}'**
  String readingsPerSecond(int rate, String uptime);

  /// No description provided for @reconnectedTimes.
  ///
  /// In en, this message translates to:
  /// **'reconnected {count}×'**
  String reconnectedTimes(int count);

  /// No description provided for @boxSilent.
  ///
  /// In en, this message translates to:
  /// **'Open, but the box is not sending'**
  String get boxSilent;

  /// No description provided for @boxSilentText.
  ///
  /// In en, this message translates to:
  /// **'Trying again every few seconds. Is it the right port, and is the box powered?'**
  String get boxSilentText;

  /// No description provided for @notConnectedShort.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnectedShort;

  /// No description provided for @boxDisconnectedText.
  ///
  /// In en, this message translates to:
  /// **'Trying again every few seconds. Plug the box in; nothing needs to be pressed here.'**
  String get boxDisconnectedText;

  /// No description provided for @choosePort.
  ///
  /// In en, this message translates to:
  /// **'Choose the port of the buzzer box'**
  String get choosePort;

  /// No description provided for @rememberedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'It is remembered on this device.'**
  String get rememberedOnDevice;

  /// No description provided for @noSerialPorts.
  ///
  /// In en, this message translates to:
  /// **'No serial ports on this device'**
  String get noSerialPorts;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @reconnectNow.
  ///
  /// In en, this message translates to:
  /// **'Reconnect now'**
  String get reconnectNow;

  /// No description provided for @noTeam.
  ///
  /// In en, this message translates to:
  /// **'No team'**
  String get noTeam;

  /// No description provided for @pressEveryBuzzer.
  ///
  /// In en, this message translates to:
  /// **'Now press every buzzer once, as hard as a player would.'**
  String get pressEveryBuzzer;

  /// No description provided for @handsOff.
  ///
  /// In en, this message translates to:
  /// **'Hands off all buzzers for a moment…'**
  String get handsOff;

  /// No description provided for @waitingFirstPress.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first press.'**
  String get waitingFirstPress;

  /// No description provided for @gotBuzzers.
  ///
  /// In en, this message translates to:
  /// **'Got buzzer {buzzers}.'**
  String gotBuzzers(String buzzers);

  /// No description provided for @yourNumber.
  ///
  /// In en, this message translates to:
  /// **'Your number'**
  String get yourNumber;

  /// No description provided for @confetti.
  ///
  /// In en, this message translates to:
  /// **'Confetti'**
  String get confetti;

  /// No description provided for @flash.
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get flash;

  /// No description provided for @fireworks.
  ///
  /// In en, this message translates to:
  /// **'Fireworks'**
  String get fireworks;

  /// No description provided for @balloons.
  ///
  /// In en, this message translates to:
  /// **'Balloons'**
  String get balloons;

  /// No description provided for @stars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get stars;

  /// No description provided for @spotlight.
  ///
  /// In en, this message translates to:
  /// **'Spotlight'**
  String get spotlight;

  /// No description provided for @editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit title'**
  String get editTitle;

  /// No description provided for @noPicture.
  ///
  /// In en, this message translates to:
  /// **'No picture'**
  String get noPicture;

  /// No description provided for @noMusic.
  ///
  /// In en, this message translates to:
  /// **'No music'**
  String get noMusic;

  /// No description provided for @firstItem.
  ///
  /// In en, this message translates to:
  /// **'First item'**
  String get firstItem;

  /// No description provided for @rapidIntro.
  ///
  /// In en, this message translates to:
  /// **'The question first: read it out, then Next brings up item 1'**
  String get rapidIntro;

  /// No description provided for @hintShown.
  ///
  /// In en, this message translates to:
  /// **'Hint: {hint}'**
  String hintShown(String hint);

  /// No description provided for @byClosenessShort.
  ///
  /// In en, this message translates to:
  /// **'by closeness'**
  String get byClosenessShort;

  /// No description provided for @byClosenessSummary.
  ///
  /// In en, this message translates to:
  /// **'By closeness · {plus}, then −{step} per place'**
  String byClosenessSummary(int plus, int step);

  /// No description provided for @scoringClosenessText.
  ///
  /// In en, this message translates to:
  /// **'The team whose number is nearest the right value gets the most points, each place after it a bit less. Teams equally near share a place. The places count once the answering is closed, and the big screen shows them with the answers.'**
  String get scoringClosenessText;

  /// No description provided for @scoringClosenessNoSolution.
  ///
  /// In en, this message translates to:
  /// **'Places go by how near each number is to the solution, so give the slider or number a right value under How teams answer.'**
  String get scoringClosenessNoSolution;

  /// No description provided for @placeN.
  ///
  /// In en, this message translates to:
  /// **'{place} place'**
  String placeN(String place);

  /// No description provided for @statusRapidIntro.
  ///
  /// In en, this message translates to:
  /// **'Question open · read it out first'**
  String get statusRapidIntro;

  /// No description provided for @pickSeveral.
  ///
  /// In en, this message translates to:
  /// **'Teams can pick several'**
  String get pickSeveral;

  /// No description provided for @pickSeveralText.
  ///
  /// In en, this message translates to:
  /// **'For questions with more than one right answer: right only when a team picks exactly the right ones'**
  String get pickSeveralText;

  /// No description provided for @explainOrdering.
  ///
  /// In en, this message translates to:
  /// **'Put in order: entries such as inventions, films or cities that every team sorts on its device, e.g. by year. The big screen shows them mixed up, then puts them in place one by one.'**
  String get explainOrdering;

  /// No description provided for @orderingEditorText.
  ///
  /// In en, this message translates to:
  /// **'Write the entries in the right order, first to last; drag them to change it. Each can be a text, a picture or both, plus what it\'s sorted by (a year, a size), which appears as the entry is put in place.'**
  String get orderingEditorText;

  /// No description provided for @orderEntry.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get orderEntry;

  /// No description provided for @orderValue.
  ///
  /// In en, this message translates to:
  /// **'Sorted by (optional)'**
  String get orderValue;

  /// No description provided for @orderValueHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1969'**
  String get orderValueHint;

  /// No description provided for @removeEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove entry'**
  String get removeEntry;

  /// No description provided for @addEntry.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get addEntry;

  /// No description provided for @orderScoringTitle.
  ///
  /// In en, this message translates to:
  /// **'Points for'**
  String get orderScoringTitle;

  /// No description provided for @orderScoring.
  ///
  /// In en, this message translates to:
  /// **'{rule, select, exact{Exact order} pairs{Per pair} other{Per place}}'**
  String orderScoring(String rule);

  /// No description provided for @orderScoringText.
  ///
  /// In en, this message translates to:
  /// **'{rule, select, exact{All points for the exact order, none otherwise.} pairs{A share for every two entries the right way round. One entry in the wrong spot costs only a little.} other{A share for every entry in its right place.}}'**
  String orderScoringText(String rule);

  /// No description provided for @rightOrder.
  ///
  /// In en, this message translates to:
  /// **'Right order'**
  String get rightOrder;

  /// No description provided for @placeNext.
  ///
  /// In en, this message translates to:
  /// **'Place next'**
  String get placeNext;

  /// No description provided for @partialPairs.
  ///
  /// In en, this message translates to:
  /// **'{right} of {total} pairs right'**
  String partialPairs(int right, int total);

  /// No description provided for @testOnThisComputer.
  ///
  /// In en, this message translates to:
  /// **'Test on this computer'**
  String get testOnThisComputer;

  /// No description provided for @testDevices.
  ///
  /// In en, this message translates to:
  /// **'Test devices'**
  String get testDevices;

  /// No description provided for @bot.
  ///
  /// In en, this message translates to:
  /// **'Bot'**
  String get bot;

  /// No description provided for @allBots.
  ///
  /// In en, this message translates to:
  /// **'All bots'**
  String get allBots;

  /// No description provided for @noBots.
  ///
  /// In en, this message translates to:
  /// **'No bots'**
  String get noBots;

  /// No description provided for @whoAnswers.
  ///
  /// In en, this message translates to:
  /// **'Who answers'**
  String get whoAnswers;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @roundForOtherTeams.
  ///
  /// In en, this message translates to:
  /// **'This round is for other teams'**
  String get roundForOtherTeams;

  /// No description provided for @nextPair.
  ///
  /// In en, this message translates to:
  /// **'Next pair'**
  String get nextPair;

  /// No description provided for @moreTime.
  ///
  /// In en, this message translates to:
  /// **'More time'**
  String get moreTime;

  /// No description provided for @noTimeLimit.
  ///
  /// In en, this message translates to:
  /// **'No time limit'**
  String get noTimeLimit;

  /// No description provided for @notesText.
  ///
  /// In en, this message translates to:
  /// **'Chosen teams get a notes field on their devices, next to whatever they answer, e.g. to estimate for a bonus. You read the notes here.'**
  String get notesText;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
