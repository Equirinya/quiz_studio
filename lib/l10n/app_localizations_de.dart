// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Quiz Studio';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get done => 'Fertig';

  @override
  String get close => 'Schließen';

  @override
  String get ok => 'OK';

  @override
  String get thatDidntWork => 'Das hat nicht geklappt.';

  @override
  String get account => 'Konto';

  @override
  String get navGames => 'Spiele';

  @override
  String get navSessions => 'Sessions';

  @override
  String get couldNotOpenStore => 'Der Store ließ sich nicht öffnen';

  @override
  String get downloadPage => 'Download-Seite';

  @override
  String get updateRequired => 'Update nötig';

  @override
  String get updateRequiredText =>
      'Diese Version der App wird nicht mehr unterstützt. Bitte aktualisiere sie, um weiterzumachen.';

  @override
  String installedAndRequired(String installed, String required) {
    return 'Installiert $installed · nötig $required';
  }

  @override
  String openStore(String store) {
    return '$store öffnen';
  }

  @override
  String get yourName => 'Dein Name';

  @override
  String get theNameOthersSee => 'Der Name, den andere sehen';

  @override
  String nameLength(int min, int max) {
    return 'Ein Name braucht $min bis $max Zeichen.';
  }

  @override
  String get addEmailAndPassword => 'E-Mail und Passwort hinzufügen';

  @override
  String get upgradeSubtitle =>
      'Deine Spiele bleiben bei diesem Konto. Danach kannst du dich auf deinen anderen Geräten damit anmelden.';

  @override
  String get upgradeDone =>
      'Fertig. Dieses Konto hat jetzt eine E-Mail-Adresse.';

  @override
  String get signOut => 'Abmelden';

  @override
  String get signOutGuestWarning =>
      'Du bist als Gast angemeldet. Beim Abmelden gehen dieses Konto und die Spiele verloren, auf die nur es Zugriff hat. Füge zuerst eine E-Mail-Adresse hinzu, um sie zu behalten.';

  @override
  String get signOutInfo =>
      'Du kannst dich mit deiner E-Mail-Adresse und deinem Passwort wieder anmelden.';

  @override
  String get deletingAccount => 'Dein Konto wird gelöscht …';

  @override
  String get accountDeleted => 'Dein Konto und seine Daten sind gelöscht.';

  @override
  String get accountNotDeletedConnection =>
      'Das Konto ließ sich nicht löschen. Prüfe die Verbindung und versuch es noch mal.';

  @override
  String get nameSubtitle =>
      'Der Name, den andere Spieler und Mitautoren sehen';

  @override
  String get guestAccount => 'Gastkonto';

  @override
  String get guestAccountText =>
      'Deine Spiele gibt es nur im Konto dieses Geräts. Füge E-Mail-Adresse und Passwort hinzu, damit sie sicher sind und du dich auf deinen anderen Geräten anmelden kannst, zum Beispiel am PC, der präsentiert, und am Handy, das steuert.';

  @override
  String get emailSubtitle =>
      'Melde dich mit dieser Adresse auf deinen anderen Geräten an';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountSubtitle =>
      'Dein Profil, deine eigenen Spiele und deine Sessions';

  @override
  String get contact => 'Kontakt';

  @override
  String get contactSubtitle => 'Feedback, Fehlerberichte und Wünsche';

  @override
  String get terms => 'Nutzungsbedingungen';

  @override
  String get privacy => 'Datenschutz';

  @override
  String get aboutAndLicences => 'Über die App und Lizenzen';

  @override
  String get soundCredits => 'Sound-Quellen';

  @override
  String get soundCreditsSubtitle => 'Woher die eingebauten Sounds stammen';

  @override
  String get deleteAccountQuestion => 'Konto löschen?';

  @override
  String get deleteAccountText =>
      'Das löscht dein Profil, die Spiele, in denen nur du bist, mit ihren Bildern und Sounds, und die Sessions, die du leitest. Geteilte Spiele bleiben bei den anderen; bist du dort der einzige Admin, wird ein Mitautor Admin. Das lässt sich nicht rückgängig machen.';

  @override
  String get password => 'Passwort';

  @override
  String get wrongPassword => 'Das Passwort stimmt nicht.';

  @override
  String get tooManyTries =>
      'Zu viele Versuche. Warte kurz und versuch es noch mal.';

  @override
  String get requiresRecentLogin =>
      'Melde dich ab, wieder an und lösche dann das Konto.';

  @override
  String get noConnectionTryOnline =>
      'Keine Verbindung. Versuch es noch mal, wenn du online bist.';

  @override
  String get accountNotDeleted =>
      'Das Konto ließ sich nicht löschen. Versuch es noch mal.';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Systemsprache';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get notSignedIn => 'Du bist nicht angemeldet.';

  @override
  String get emailInUse =>
      'Mit dieser E-Mail-Adresse gibt es schon ein Konto. Melde dich stattdessen dort an.';

  @override
  String get invalidEmail => 'Das ist keine gültige E-Mail-Adresse.';

  @override
  String get weakPassword => 'Bitte wähle ein stärkeres Passwort.';

  @override
  String get alreadyHasEmail => 'Dieses Konto hat schon eine E-Mail-Adresse.';

  @override
  String get restartAndRetry =>
      'Starte die App zur Sicherheit neu und versuch es noch mal.';

  @override
  String get notConnected => 'Du bist nicht mit dem Internet verbunden.';

  @override
  String get emailSignInOff =>
      'Die Anmeldung per E-Mail ist für diese App ausgeschaltet.';

  @override
  String get didNotWorkTryAgain =>
      'Das hat nicht geklappt. Bitte versuch es noch mal.';

  @override
  String get unknownUser => 'Unbekannt';

  @override
  String get passwordMinLength => 'Mindestens 8 Zeichen';

  @override
  String get passwordUppercase => 'Ein Großbuchstabe';

  @override
  String get passwordLowercase => 'Ein Kleinbuchstabe';

  @override
  String get passwordNumber => 'Eine Ziffer';

  @override
  String get email => 'E-Mail';

  @override
  String get hidePassword => 'Passwort verbergen';

  @override
  String get showPassword => 'Passwort zeigen';

  @override
  String get confirmPassword => 'Passwort wiederholen';

  @override
  String get passwordsDontMatch => 'Die Passwörter stimmen nicht überein.';

  @override
  String get featureBuildTitle => 'Gemeinsam Quizze bauen';

  @override
  String get featureBuildText =>
      'Schreib Kategorien und Fragen mit Freunden, ohne euch etwas zu verraten.';

  @override
  String get featurePresentTitle => 'Auf dem großen Bildschirm zeigen';

  @override
  String get featurePresentText =>
      'Zeig die Show auf dem Fernseher oder Beamer und steuere sie vom Handy aus.';

  @override
  String get featureBuzzersTitle => 'Handys als Buzzer';

  @override
  String get featureBuzzersText =>
      'Mitspieler scannen einen Code und sind dabei. Arduino-Buzzer gehen auch.';

  @override
  String get featureMusicTitle => 'Musik und Soundeffekte';

  @override
  String get featureMusicText =>
      'Hintergrundmusik, Sounds beim Aufdecken und ein Buzzer-Sound pro Team.';

  @override
  String get enterValidEmail => 'Bitte gib eine gültige E-Mail-Adresse ein.';

  @override
  String get enterPassword => 'Bitte gib dein Passwort ein.';

  @override
  String get noAccountForEmail =>
      'Zu dieser E-Mail-Adresse gibt es kein Konto.';

  @override
  String get wrongEmailOrPassword => 'E-Mail-Adresse oder Passwort falsch.';

  @override
  String get invalidEmailShort => 'Ungültige E-Mail-Adresse.';

  @override
  String get accountDisabled => 'Dieses Konto wurde gesperrt.';

  @override
  String get tooManyAttempts =>
      'Zu viele Versuche. Bitte versuch es später noch mal.';

  @override
  String get signInFailed =>
      'Anmeldung fehlgeschlagen. Bitte versuch es noch mal.';

  @override
  String get anonymousSignInDisabled =>
      'Die anonyme Anmeldung ist ausgeschaltet. Bitte versuch es später noch mal.';

  @override
  String get couldNotStart =>
      'Der Start hat nicht geklappt. Bitte versuch es noch mal.';

  @override
  String get unknownError => 'Ein unbekannter Fehler ist aufgetreten.';

  @override
  String get couldNotSaveName =>
      'Dein Name ließ sich nicht speichern. Bitte versuch es noch mal.';

  @override
  String get login => 'Anmelden';

  @override
  String get chooseYourName =>
      'Wähle den Namen, den andere Spieler und Mitautoren sehen:';

  @override
  String get theNameOthersWillSee => 'Der Name, den andere sehen';

  @override
  String get justJoinAShow => 'Nur bei einer Show mitspielen';

  @override
  String get useDifferentAccount => 'Anderes Konto verwenden';

  @override
  String get haveAnAccount => 'Ich habe schon ein Konto';

  @override
  String get termsBefore => 'Mit dem Fortfahren stimmst du den ';

  @override
  String get termsLink => 'Nutzungsbedingungen';

  @override
  String get termsBetween => ' und der ';

  @override
  String get privacyLink => 'Datenschutzerklärung';

  @override
  String get termsAfter => ' zu.';

  @override
  String get back => 'Zurück';

  @override
  String get letsPlay => 'Los geht\'s';

  @override
  String get joinAShow => 'Bei einer Show mitspielen';

  @override
  String get createOwnQuizzes => 'Eigene Quizze erstellen';

  @override
  String get creditsMadeForApp => 'Für Quiz Studio gemacht';

  @override
  String creditsMadeBy(String name) {
    return 'Gemacht von $name';
  }

  @override
  String get creditsPartOfApp => 'Teil der App';

  @override
  String get creditsPublicDomain => '(gemeinfrei)';

  @override
  String get creditsIntro =>
      'Die Sounds von Quiz Studio wurden dafür gemacht oder sind für jedes Projekt frei nutzbar (CC0). Tippe auf eine Quelle, um zu sehen, woher sie stammt.';

  @override
  String questionTypeName(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'free': 'Freie Frage',
      'abcd': 'ABCD',
      'progressingReveal': 'Stück für Stück',
      'feud': 'Umfrage-Duell',
      'connections': 'Wortgruppen',
      'rapidFire': 'Fragenhagel',
      'matching': 'Zuordnen',
      'topAnswers': 'Top-Antworten',
      'lastStanding': 'Wer bleibt übrig',
      'other': 'Nicht unterstützt',
    });
    return '$_temp0';
  }

  @override
  String boardTypeName(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'display': 'Fragentafel',
      'wheel': 'Glücksrad',
      'other': 'Spielplan',
    });
    return '$_temp0';
  }

  @override
  String gameRoleName(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'admin': 'Admin',
      'full': 'Voller Zugriff',
      'other': 'Eingeschränkter Zugriff',
    });
    return '$_temp0';
  }

  @override
  String companionKindName(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'whiteboard': 'Whiteboard',
      'text': 'Text',
      'number': 'Zahl',
      'slider': 'Schieberegler',
      'choice': 'Eins auswählen',
      'order': 'Reihenfolge',
      'match': 'Paare zuordnen',
      'connections': 'Wortgruppen',
      'other': 'Antwortliste',
    });
    return '$_temp0';
  }

  @override
  String estimateScoringName(String scoring) {
    String _temp0 = intl.Intl.selectLogic(scoring, {
      'closest': 'Am nächsten gewinnt',
      'podium': '1., 2., 3.',
      'other': 'Nach Abstand',
    });
    return '$_temp0';
  }

  @override
  String turnOrderName(String order) {
    String _temp0 = intl.Intl.selectLogic(order, {
      'teams': 'In der Reihenfolge der Teams',
      'mostPoints': 'Meiste Punkte zuerst',
      'other': 'Wenigste Punkte zuerst',
    });
    return '$_temp0';
  }

  @override
  String standingResultName(String result) {
    String _temp0 = intl.Intl.selectLogic(result, {
      'right': 'Richtig',
      'out': 'Falsch, raus',
      'other': 'Falsch, bleibt drin',
    });
    return '$_temp0';
  }

  @override
  String rapidModeName(String mode) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'buzzer': 'Teams buzzern',
      'other': 'Richtig oder falsch auf den Geräten der Teams',
    });
    return '$_temp0';
  }

  @override
  String progressStyleName(String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'off': 'Keine Fortschrittsanzeige',
      'bar': 'Balken',
      'dots': 'Punkte',
      'battery': 'Batterie',
      'thermometer': 'Thermometer',
      'other': 'Fluxkompensator',
    });
    return '$_temp0';
  }

  @override
  String topAnswersModeName(String mode) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'buzzer': 'Teams buzzern',
      'typed': 'Auf den Geräten der Teams getippt',
      'other': 'Auf ein Whiteboard geschrieben',
    });
    return '$_temp0';
  }

  @override
  String cardAnimationName(String animation) {
    String _temp0 = intl.Intl.selectLogic(animation, {
      'off': 'Aus',
      'fade': 'Einblenden',
      'slideUp': 'Von unten hereinschieben',
      'slideDown': 'Von oben hereinschieben',
      'bounce': 'Hereinhüpfen',
      'zoom': 'Zoomen',
      'spin': 'Hereindrehen',
      'other': 'Umklappen',
    });
    return '$_temp0';
  }

  @override
  String cardStyleName(String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'standard': 'Standard',
      'silentFilm': 'Stummfilm',
      'poster': 'Plakat',
      'other': 'Nur die Worte',
    });
    return '$_temp0';
  }

  @override
  String builtinImageName(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'correct': 'Richtig!',
      'wrong': 'Falsch!',
      'times_up': 'Zeit ist um!',
      'get_ready': 'Macht euch bereit',
      'thinking': 'Bedenkzeit',
      'bonus': 'Bonusfrage',
      'drumroll': 'Trommelwirbel …',
      'applause': 'Applaus!',
      'quiet': 'Ruhe bitte',
      'break': 'Pause',
      'final_round': 'Finalrunde',
      'winner': 'Und der Sieg geht an …',
      'other': 'Bild',
    });
    return '$_temp0';
  }

  @override
  String get rapidRight => 'Richtig';

  @override
  String get rapidWrong => 'Falsch';

  @override
  String get newGame => 'Neues Spiel';

  @override
  String get name => 'Name';

  @override
  String get couldNotCreateGame => 'Das Spiel ließ sich nicht erstellen.';

  @override
  String get joinWithInviteLink => 'Mit einem Einladungslink beitreten';

  @override
  String get couldNotLoadGames => 'Deine Spiele ließen sich nicht laden.';

  @override
  String get noGamesYet => 'Noch keine Spiele';

  @override
  String get noGamesYetText =>
      'Erstell dein erstes Quiz oder lass dich von Freunden zu ihrem einladen.';

  @override
  String get unnamed => 'Ohne Namen';

  @override
  String get couldNotUploadPicture => 'Das Bild ließ sich nicht hochladen.';

  @override
  String get map => 'Spielplan';

  @override
  String get groupNotAvailable => 'Diese Gruppe ist nicht verfügbar.';

  @override
  String newBoard(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'display': 'Neue Fragentafel',
      'wheel': 'Neues Glücksrad',
      'other': 'Neuer Spielplan',
    });
    return '$_temp0';
  }

  @override
  String addBoard(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'display': 'Fragentafel hinzufügen',
      'wheel': 'Glücksrad hinzufügen',
      'other': 'Spielplan hinzufügen',
    });
    return '$_temp0';
  }

  @override
  String get newCategory => 'Neue Kategorie';

  @override
  String get hideOne => 'Eins verbergen';

  @override
  String revealedOf(int revealed, int steps) {
    return '$revealed von $steps aufgedeckt';
  }

  @override
  String get revealNext => 'Nächstes aufdecken';

  @override
  String get boardColours => 'Farben des Spielbretts';

  @override
  String get primaryColour => 'Hauptfarbe';

  @override
  String get accentColour => 'Akzent';

  @override
  String get useAppColours => 'App-Farben verwenden';

  @override
  String get noTimer => 'Kein Timer';

  @override
  String get timer => 'Timer';

  @override
  String get teamsCanLockIn => 'Teams können früher einloggen';

  @override
  String get lockInOnText =>
      'Einloggen beendet die Zeit eines Teams, und wie lange es gebraucht hat, wird festgehalten';

  @override
  String get lockInOffText =>
      'Jede Antwort zählt so, wie sie steht, wenn die Zeit um ist oder du die Runde beendest';

  @override
  String musicCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Musikstücke',
      one: '1 Musikstück',
    );
    return '$_temp0';
  }

  @override
  String effectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Effekte',
      one: '1 Effekt',
    );
    return '$_temp0';
  }

  @override
  String get none => 'Keine';

  @override
  String cardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Karten',
      one: '1 Karte',
    );
    return '$_temp0';
  }

  @override
  String cardsOfferedOff(int on, int off) {
    return '$on angeboten, $off aus';
  }

  @override
  String get gameNotAvailable => 'Dieses Spiel ist nicht verfügbar.';

  @override
  String get copiedGame => 'Spiel mit Antworten kopiert.';

  @override
  String get renameGame => 'Spiel umbenennen';

  @override
  String get deleteGame => 'Spiel löschen';

  @override
  String deleteGameText(String name) {
    return '„$name“ und alle seine Fragen werden für alle gelöscht.';
  }

  @override
  String get leaveGame => 'Spiel verlassen';

  @override
  String leaveGameText(String name) {
    return 'Du verlierst den Zugriff auf „$name“, bis dich jemand wieder einlädt.';
  }

  @override
  String get leave => 'Verlassen';

  @override
  String get musicAndSounds => 'Musik & Sounds';

  @override
  String get noneYet => 'Noch keine';

  @override
  String get soundsForGame => 'Sounds für das ganze Spiel';

  @override
  String get cards => 'Karten';

  @override
  String get cardsForGame => 'Karten für das ganze Spiel';

  @override
  String get people => 'Personen';

  @override
  String get more => 'Mehr';

  @override
  String get rename => 'Umbenennen';

  @override
  String get copyAsText => 'Als Text kopieren';

  @override
  String get nothingSharedYet =>
      'Hier ist noch nichts. Bitte einen Admin, eine Kategorie mit dir zu teilen.';

  @override
  String get onlyYou => 'Nur du';

  @override
  String memberCount(int count) {
    return '$count Mitglieder';
  }

  @override
  String get renameGroup => 'Gruppe umbenennen';

  @override
  String get displayText => 'Anzeigetext';

  @override
  String get shownOnBoard => 'Wird auf dem Spielbrett gezeigt';

  @override
  String categoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kategorien',
      one: '1 Kategorie',
    );
    return '$_temp0';
  }

  @override
  String get ownSounds => 'eigene Sounds';

  @override
  String get usesGames => 'Die des Spiels';

  @override
  String get soundsForBoard => 'Sounds für dieses Spielbrett';

  @override
  String get onlyGames => 'Nur die des Spiels';

  @override
  String get cardsForBoard => 'Karten für dieses Spielbrett';

  @override
  String get colours => 'Farben';

  @override
  String get appsColours => 'Die Farben der App';

  @override
  String get ownColours => 'Eigene Farben';

  @override
  String get textOnBoard => 'Text auf dem Spielbrett';

  @override
  String get splitPointFields => 'Punktefelder teilen';

  @override
  String get splitPointFieldsText =>
      'Wenn ein Wert in einem Ring mehrmals vorkommt';

  @override
  String get arrangeMap => 'Spielplan anordnen';

  @override
  String get arrangeMapShort => 'Blasen, Pfeile, Titel, Bilder und Linien';

  @override
  String get arrangeMapLong =>
      'Blasen platzieren, verbinden, Titel, Bilder und Linien hinzufügen';

  @override
  String get labelsInsteadOfPoints => 'Beschriftungen statt Punkte';

  @override
  String get labelsInsteadOfPointsText =>
      'Fragen ohne Beschriftung zeigen weiter ihre Punkte';

  @override
  String get deleteBoard => 'Spielbrett löschen';

  @override
  String get deleteBoardFirst => 'Verschieb oder lösch zuerst seine Kategorien';

  @override
  String get ungroupedCategories => 'Kategorien ohne Gruppe';

  @override
  String get boardSettings => 'Spielbrett-Einstellungen';

  @override
  String get moveBoard => 'Spielbrett verschieben';

  @override
  String get addCategory => 'Kategorie hinzufügen';

  @override
  String get moveToAnotherBoard => 'Auf ein anderes Spielbrett verschieben';

  @override
  String comesAfterTitle(String name) {
    return '„$name“ kommt nach';
  }

  @override
  String get categoryBeforeIt => 'Der Kategorie davor (Standard)';

  @override
  String get startsNewChain => 'Nichts: Sie beginnt eine neue Kette';

  @override
  String get deleteCategory => 'Kategorie löschen';

  @override
  String deleteCategoryText(String name, int count) {
    return '„$name“ und ihre $count Fragen werden gelöscht.';
  }

  @override
  String get inPlayTip => 'Im Spiel: Tippen nimmt sie aus dem Spiel';

  @override
  String get notInPlayTip => 'Nicht im Spiel: Tippen nimmt sie wieder auf';

  @override
  String get moveCategory => 'Kategorie verschieben';

  @override
  String questionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fragen',
      one: '1 Frage',
    );
    return '$_temp0';
  }

  @override
  String get notInPlay => 'nicht im Spiel';

  @override
  String get moveUp => 'Nach oben';

  @override
  String get moveDown => 'Nach unten';

  @override
  String get moveToAnotherBoardMenu => 'Auf anderes Spielbrett …';

  @override
  String get comesAfterMenu => 'Kommt nach …';

  @override
  String get renameCategory => 'Kategorie umbenennen';

  @override
  String get shareCategory => 'Kategorie teilen';

  @override
  String get shareCategoryText =>
      'Mitglieder mit eingeschränktem Zugriff sehen nur die Kategorien, die hier eingeschaltet sind.';

  @override
  String get createdThisCategory => 'Hat diese Kategorie erstellt';

  @override
  String get notShared => 'Nicht geteilt';

  @override
  String sharedWith(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mit $count Personen',
      one: 'Mit 1 Person',
    );
    return '$_temp0';
  }

  @override
  String get categoryNotAvailable => 'Diese Kategorie ist nicht verfügbar.';

  @override
  String get addQuestion => 'Frage hinzufügen';

  @override
  String get usesBoards => 'Die des Spielbretts';

  @override
  String get soundsForCategory => 'Sounds für diese Kategorie';

  @override
  String get onlyBoardsAndGames => 'Nur die des Spielbretts und Spiels';

  @override
  String get cardsForCategory => 'Karten für diese Kategorie';

  @override
  String get share => 'Teilen';

  @override
  String get noQuestionsYet => 'Noch keine Fragen.';

  @override
  String get couldNotSave => 'Speichern fehlgeschlagen.';

  @override
  String get deleteQuestion => 'Frage löschen';

  @override
  String get deleteQuestionText => 'Diese Frage wird gelöscht.';

  @override
  String get onTheDevices => 'auf den Geräten';

  @override
  String kindOnTheDevices(String kind) {
    return '$kind auf den Geräten';
  }

  @override
  String get teamsBetShort => 'Teams wetten';

  @override
  String get teamsBetHowManyShort => 'Teams wetten auf Anzahl';

  @override
  String get byOrderShort => 'nach Reihenfolge';

  @override
  String get fixed => 'Fest';

  @override
  String pointsBetSummary(int limit) {
    return 'Teams setzen ihre Punkte · mindestens $limit zum Setzen';
  }

  @override
  String get betOnHowMany => 'Wette auf die Anzahl';

  @override
  String plusEach(int plus) {
    return 'je +$plus';
  }

  @override
  String plusMinusEach(int plus, int minus) {
    return 'je +$plus / −$minus';
  }

  @override
  String byOrderSummary(int plus, int step) {
    return 'Nach Reihenfolge · $plus, dann −$step pro Platz';
  }

  @override
  String wrongMinus(int minus) {
    return 'falsch −$minus';
  }

  @override
  String get picture => 'Bild';

  @override
  String get music => 'Musik';

  @override
  String get noOwnMedia => 'Kein eigenes Bild, keine Musik, keine Sounds';

  @override
  String get rule => 'Regel';

  @override
  String scoringRuleName(String rule) {
    String _temp0 = intl.Intl.selectLogic(rule, {
      'fixed': 'Feste Punkte',
      'points': 'Teams setzen ihre Punkte',
      'amount': 'Teams wetten, wie viele sie schaffen',
      'closest': 'Nach Nähe: Nächste zuerst',
      'other': 'Nach Reihenfolge: Schnellste zuerst',
    });
    return '$_temp0';
  }

  @override
  String get scoringFixedText => 'Jedes Team spielt um dieselben Punkte.';

  @override
  String get scoringRankedText =>
      'Das erste Team bekommt die meisten Punkte, jedes danach etwas weniger. Die Reihenfolge ist die, in der die Teams eine richtige Antwort auf ihren Geräten eingeloggt haben, oder die, in der du sie antippst, z. B. wenn sie auf der Bühne fertig werden. Falsche Antworten kosten die Minuspunkte.';

  @override
  String scoringPointsText(int limit) {
    return 'Vor der Frage setzt jedes Team einen Teil seiner Punkte: Eine richtige Antwort gewinnt den Einsatz, eine falsche verliert ihn. Teams dürfen bis zu ihrem Punktestand setzen, oder bis zu $limit, wenn sie weniger haben.';
  }

  @override
  String get scoringAmountText =>
      'Zuerst wird nur die Wettfrage gezeigt und jedes Team sagt, wie viele es schafft. Dann läuft die Frage; du entscheidest pro Team, ob es seine Zahl erreicht hat. Erreicht: die Punkte für jedes. Verfehlt: die Minuspunkte für jedes.';

  @override
  String get betQuestion => 'Wettfrage';

  @override
  String get betQuestionHint =>
      'Wie viele Science-Fiction-Filme kannst du nennen?';

  @override
  String get points => 'Punkte';

  @override
  String get eachPlus => 'Je +';

  @override
  String get firstPlacePlus => '1. Platz +';

  @override
  String get eachItemPlus => 'Je Frage +';

  @override
  String get winnerPlus => 'Sieger +';

  @override
  String get eachAnswerPlus => 'Je Antwort +';

  @override
  String get ifRightPlus => 'Richtig +';

  @override
  String onTheBoard(int points) {
    return '$points auf dem Spielbrett';
  }

  @override
  String get eachMinus => 'Je −';

  @override
  String get ifWrongMinus => 'Falsch −';

  @override
  String get lessPerPlace => 'Weniger pro Platz';

  @override
  String get highestBet => 'Höchster Einsatz';

  @override
  String get musicAndEffects => 'Musik & Effekte';

  @override
  String get theCategorys => 'Die der Kategorie';

  @override
  String get soundsForQuestion => 'Sounds für diese Frage';

  @override
  String get type => 'Typ';

  @override
  String get question => 'Frage';

  @override
  String get answerHint => 'Antworthinweis';

  @override
  String get onlyGamemasterSees => 'Nur die Spielleitung sieht das';

  @override
  String get label => 'Beschriftung';

  @override
  String get labelHelper => 'Kleines Abzeichen auf der Fragenkarte';

  @override
  String get labelTooltip => 'Ein kleines Abzeichen auf der Fragenkarte';

  @override
  String get howTeamsAnswer => 'Wie Teams antworten';

  @override
  String get scoring => 'Punktevergabe';

  @override
  String get mediaAndSound => 'Medien & Sound';

  @override
  String get moveQuestion => 'Frage verschieben';

  @override
  String get newQuestion => 'Neue Frage';

  @override
  String get preview => 'Vorschau';

  @override
  String get explainFree =>
      'Die einfachste Frage: keine Antwortmöglichkeiten und nichts aufzudecken. Unter „Wie Teams antworten“ lassen sich die Buzzer ausschalten, z. B. für Schätzfragen.';

  @override
  String get explainAbcd =>
      'Zeigt richtige und falsche Antwortvorschläge, die die Spielleitung nacheinander aufdeckt.';

  @override
  String get explainProgressingReveal =>
      'Die Spielleitung deckt Stück für Stück mehr Hinweise auf.';

  @override
  String get explainFeud =>
      'Ein Duell um eine Umfrage: Das Team, das gebuzzert hat, deckt Antworten auf, bis es dreimal daneben liegt; dann darf das andere Team alle Punkte klauen.';

  @override
  String get explainTopAnswers =>
      'Nenne die beliebtesten Antworten: Teams finden Antworten einer Liste, per Buzzer oder auf ihren Geräten, und bekommen die Punkte jeder einzelnen.';

  @override
  String get explainConnections =>
      'Sechzehn Wörter in vier Vierergruppen. Jedes Team löst sie auf seinem Gerät; jede gefundene Gruppe bringt ein Viertel der Punkte.';

  @override
  String get explainRapidFire =>
      'Fragenhagel: viele kurze Fragen direkt hintereinander. Teams buzzern oder bewerten Aussagen auf ihren Geräten als richtig oder falsch; jede Frage kann ein Bild und einen Sound haben.';

  @override
  String get explainMatching =>
      'Zuordnen: Paare aus Texten oder Bildern, z. B. Filme und ihre Jahre. Jedes Team setzt sie auf seinem Gerät wieder zusammen; der große Bildschirm zeigt die Bilder.';

  @override
  String get explainLastStanding =>
      'Wer bleibt übrig: Je ein Spieler pro Team ist abwechselnd dran, nennt z. B. Filme oder sagt, ob es über einen Star ein Biopic gibt. Eine falsche Antwort wirft das Team raus; das letzte Team bekommt die Punkte.';

  @override
  String get explainUnsupported =>
      'Diese Version der App unterstützt diesen Fragetyp nicht.';

  @override
  String groupsNeedNameAndWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Gruppen brauchen einen Namen und vier Wörter.',
      one: '1 Gruppe braucht einen Namen und vier Wörter.',
    );
    return '$_temp0';
  }

  @override
  String wordTwice(String word) {
    return '„$word“ kommt zweimal im Rätsel vor.';
  }

  @override
  String groupInCommon(int group) {
    String _temp0 = intl.Intl.pluralLogic(
      group,
      locale: localeName,
      other: 'Lila',
      two: 'Blau',
      one: 'Grün',
      zero: 'Gelb',
    );
    return '$_temp0: was sie gemeinsam haben';
  }

  @override
  String wordN(int n) {
    return 'Wort $n';
  }

  @override
  String get connectionsReady =>
      'Fertig. Gelb soll die leichteste Gruppe sein und Lila die schwerste.';

  @override
  String answerLetter(String letter) {
    return 'Antwort $letter';
  }

  @override
  String get removeAnswer => 'Antwort entfernen';

  @override
  String get addAnswer => 'Antwort hinzufügen';

  @override
  String get absoluteValues => 'Absolute Werte statt Prozent zeigen';

  @override
  String get value => 'Wert';

  @override
  String answerN(int n) {
    return 'Antwort $n';
  }

  @override
  String informationN(int n) {
    return 'Hinweis $n';
  }

  @override
  String get addInformation => 'Hinweis hinzufügen';

  @override
  String get importFromRanker => 'Von Ranker importieren';

  @override
  String get pictureStrip => 'Bilderleiste';

  @override
  String get pictureStripText =>
      'Kleine Bilder unter der Frage, „?“ für die noch verborgenen';

  @override
  String get teamsBuzz => 'Teams buzzern';

  @override
  String get onTheDevicesShort => 'Auf den Geräten';

  @override
  String get progressOnBigScreen => 'Fortschritt auf dem großen Bildschirm';

  @override
  String get rapidDevicesText =>
      'Jede Frage ist eine Aussage. Jedes Team wählt auf seinem Gerät richtig oder falsch; wenn du weitergehst, bekommt eine richtige Wahl die Punkte.';

  @override
  String get rapidBuzzText =>
      'Teams buzzern bei jeder Frage. Eine richtige Antwort bekommt die Punkte und es geht direkt zur nächsten.';

  @override
  String statementN(int n) {
    return 'Aussage $n';
  }

  @override
  String questionN(int n) {
    return 'Frage $n';
  }

  @override
  String get answer => 'Antwort';

  @override
  String get remove => 'Entfernen';

  @override
  String get addStatement => 'Aussage hinzufügen';

  @override
  String get turnOrderLabel => 'Reihenfolge';

  @override
  String get lastStandingText =>
      'Je ein Spieler pro Team ist abwechselnd dran. Du bewertest jeden Zug: richtig, falsch (das Team ist raus) oder falsch, bleibt aber drin. Das letzte Team bekommt die Punkte.';

  @override
  String get noPrompts =>
      'Keine Vorgaben: Jeder Zug beantwortet die Frage selbst.';

  @override
  String get onePromptPerTurn => 'Eine Vorgabe pro Zug, in dieser Reihenfolge.';

  @override
  String promptN(int n) {
    return 'Vorgabe $n';
  }

  @override
  String get addPrompt => 'Vorgabe hinzufügen';

  @override
  String get onlyWithDevices =>
      'Nur mit den eigenen Geräten der Teams spielbar: Jedes Team braucht ein verbundenes Handy oder Tablet (Einrichten, dann Geräte verbinden). Ohne sie gibt es nichts zum Antworten.';

  @override
  String get matchingEditorText =>
      'Schreib jedes Paar so, wie es zusammengehört; die Teams bekommen die rechte Seite durcheinander. Eine Seite kann Text, Bild oder beides sein. Bilder erscheinen auf dem großen Bildschirm mit einem Buchstaben oder einer Zahl, die die Geräte zeigen.';

  @override
  String get matchLeft => 'Links';

  @override
  String get matchBelongsTo => 'Gehört zu';

  @override
  String get removePair => 'Paar entfernen';

  @override
  String get addPair => 'Paar hinzufügen';

  @override
  String get buzz => 'Buzzer';

  @override
  String get typed => 'Getippt';

  @override
  String get whiteboard => 'Whiteboard';

  @override
  String get topAnswersBuzzText =>
      'Ein Team buzzert und nennt eine Antwort. Tippe die genannte an: Sie wird aufgedeckt und das Team bekommt ihre Punkte. Dann dürfen alle wieder buzzern.';

  @override
  String get topAnswersTypedText =>
      'Jedes Team tippt seine Antworten in eine Liste auf seinem Gerät. Du hakst die gefundenen ab, mit Vorschlägen zu dem, was es getippt hat.';

  @override
  String get topAnswersWhiteboardText =>
      'Jedes Team schreibt seine Antworten auf ein nummeriertes Whiteboard. Du hakst die gefundenen ab.';

  @override
  String get topAnswersListText =>
      'Die beliebteste zuerst. Ohne eigene Punkte ist eine Antwort die Punkte der Frage wert. Weitere erlaubte Schreibweisen kommen nach einem /.';

  @override
  String paperName(String paper) {
    String _temp0 = intl.Intl.selectLogic(paper, {
      'lines': 'Liniert',
      'grid': 'Kariert',
      'list': 'Nummerierte Liste',
      'image': 'Bild',
      'other': 'Leer',
    });
    return '$_temp0';
  }

  @override
  String get connectionsDevicesText =>
      'Jedes Team löst das Rätsel auf seinem Gerät. Du siehst live, welche Gruppen jedes Team gefunden hat.';

  @override
  String get chooseDeviceScreenText =>
      'Wähle, was sich mit der Frage auf jedem Gerät der Teams öffnet. Du siehst die Antworten, während sie geschrieben werden, und entscheidest, wann sie gezeigt werden.';

  @override
  String get deviceScreenText =>
      'Öffnet sich mit der Frage auf jedem Gerät der Teams. Du siehst die Antworten, während sie geschrieben werden, und entscheidest, wann sie gezeigt werden.';

  @override
  String get buzzer => 'Buzzer';

  @override
  String get nothing => 'Nichts';

  @override
  String get recommended => 'Empfohlen';

  @override
  String get mistakesAllowed => 'Erlaubte Fehler';

  @override
  String get paper => 'Papier';

  @override
  String get rows => 'Zeilen';

  @override
  String get choosePictureToDrawOn => 'Wähle das Bild, auf das gemalt wird';

  @override
  String get pictureSet => 'Bild gewählt';

  @override
  String get from => 'Von';

  @override
  String get to => 'Bis';

  @override
  String get step => 'Schritt';

  @override
  String get unit => 'Einheit';

  @override
  String get rightValue => 'Richtiger Wert';

  @override
  String get rightWithin => 'Richtig innerhalb ±';

  @override
  String get noBuzzingAtAll => 'Gar kein Buzzern';

  @override
  String get noBuzzingAtAllText =>
      'Auch Buzzer-Boxen bleiben aus, z. B. für Schätzfragen';

  @override
  String get teamsCanStopEarly => 'Teams können früher aufhören';

  @override
  String get orderEditorText =>
      'Gib die Einträge in der richtigen Reihenfolge ein. Die Teams bekommen sie gemischt.';

  @override
  String get matchEditorText =>
      'Gib jedes Paar ein. Die Teams bekommen die rechte Seite gemischt.';

  @override
  String get item => 'Eintrag';

  @override
  String get matchRight => 'Rechts';

  @override
  String get addItem => 'Eintrag hinzufügen';

  @override
  String timerSummary(String time) {
    return 'Timer $time';
  }

  @override
  String progressSummary(String style) {
    return 'Fortschritt: $style';
  }

  @override
  String mistakesAllowedSummary(int count) {
    return '$count Fehler erlaubt';
  }

  @override
  String get outLoudNoBuzzer => 'Laut sagen, kein Buzzer';

  @override
  String get buzzerBoxesOnly => 'Nur Buzzer-Boxen';

  @override
  String sliderSummary(String from, String to) {
    return 'Schieberegler $from–$to';
  }

  @override
  String whiteboardSummary(String paper) {
    return 'Whiteboard, $paper';
  }

  @override
  String orderSummary(int count) {
    return '$count in Reihenfolge bringen';
  }

  @override
  String matchSummary(int count) {
    return '$count Paare zuordnen';
  }

  @override
  String listSummary(int count) {
    return 'Antwortliste, $count Zeilen';
  }

  @override
  String get rightShort => 'richtig';

  @override
  String get emptyCard => 'Leere Karte';

  @override
  String get card => 'Karte';

  @override
  String get moveCard => 'Karte verschieben';

  @override
  String get off => 'aus';

  @override
  String get offerInShow => 'In der Show anbieten';

  @override
  String get keepOutOfShow => 'Aus der Show heraushalten';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get cardsDialogText =>
      'Was du während der Show über den Bildschirm legen kannst, in dieser Reihenfolge angeboten. Tippe eine Karte an, um sie zu ändern, zieh sie am Griff, um sie zu verschieben, oder schalte sie aus, um sie aus der Show herauszuhalten.';

  @override
  String get newCard => 'Neue Karte';

  @override
  String get uploading => 'Wird hochgeladen …';

  @override
  String get addPicture => 'Bild hinzufügen';

  @override
  String get title => 'Titel';

  @override
  String get text => 'Text';

  @override
  String get videoClip => 'Videoclip';

  @override
  String get videoClipText =>
      'Ein Clip läuft im Vollbild auf dem großen Bildschirm, und die Karte verschwindet, wenn er endet.';

  @override
  String get look => 'Aussehen';

  @override
  String get removeCard => 'Karte entfernen';

  @override
  String get add => 'Hinzufügen';

  @override
  String get boardMusic => 'Musik am Spielbrett';

  @override
  String get calmMusic => 'Ruhige Musik';

  @override
  String get thrillingMusic => 'Spannende Musik';

  @override
  String get effectRightAnswer => 'Richtige Antwort';

  @override
  String get effectWrongAnswer => 'Falsche Antwort';

  @override
  String get effectQuestionClosed => 'Frage beendet';

  @override
  String get effectReveal => 'Aufdecken';

  @override
  String get effectQuestionOpens => 'Frage öffnet sich';

  @override
  String get effectTeamLocksIn => 'Team loggt ein';

  @override
  String get effectNextItem => 'Nächste Fragenhagel-Frage';

  @override
  String get effectLastTenSeconds => 'Letzte 10 Sekunden';

  @override
  String get effectTimesUp => 'Zeit ist um';

  @override
  String get effectSteal => 'Klauen';

  @override
  String get effectFullySolved => 'Ganz gelöst';

  @override
  String appDefault(String sound) {
    return 'Standard der App: $sound';
  }

  @override
  String get asSetAbove => 'Wie oben eingestellt';

  @override
  String get silent => 'Stumm';

  @override
  String get ownFile => 'Eigene Datei';

  @override
  String get ownFileMenu => 'Eigene Datei …';

  @override
  String get stop => 'Stopp';

  @override
  String get listen => 'Anhören';

  @override
  String get soundsGameText =>
      'Was in diesem Spiel läuft. Alles, was nicht eingestellt ist, nutzt die Sounds der App.';

  @override
  String get soundsLevelText =>
      'Alles auf „Wie oben eingestellt“ kommt vom Spielbrett oder vom Spiel.';

  @override
  String get soundsAtMoments => 'Sounds an Momenten der Show';

  @override
  String get ownEffects => 'Deine eigenen Effekte';

  @override
  String get addEffect => 'Effekt hinzufügen';

  @override
  String get oggNotSupported =>
      'Ogg-Sounds laufen unter Windows nicht. Bitte nimm MP3, WAV oder M4A.';

  @override
  String get fileTypeNotSupported => 'Dieser Dateityp wird nicht unterstützt.';

  @override
  String couldNotUploadMedia(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'image': 'Das Bild ließ sich nicht hochladen.',
      'audio': 'Der Sound ließ sich nicht hochladen.',
      'other': 'Das Video ließ sich nicht hochladen.',
    });
    return '$_temp0';
  }

  @override
  String addMedia(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'image': 'Bild hinzufügen',
      'audio': 'Sound hinzufügen',
      'other': 'Video hinzufügen',
    });
    return '$_temp0';
  }

  @override
  String get pictureTooltip =>
      'Bild: Tippen zum Vergrößern, Ersetzen oder Entfernen';

  @override
  String get replaceOrRemoveSound => 'Sound ersetzen oder entfernen';

  @override
  String get videoTooltip =>
      'Video: Tippen zum Ansehen, Ersetzen oder Entfernen';

  @override
  String get sound => 'Sound';

  @override
  String get video => 'Video';

  @override
  String get replace => 'Ersetzen';

  @override
  String get enterRankerUrl =>
      'Gib die URL einer ranker.com-Liste ein, z. B. https://www.ranker.com/list/best-smells/jacob-shelton';

  @override
  String rankerError(String kind, Object status) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'page': 'Die Seite ließ sich nicht laden ($status).',
      'noList': 'Auf dieser Seite wurde keine Liste gefunden.',
      'list': 'Die Liste ließ sich nicht laden ($status).',
      'items': 'Die Einträge der Liste ließen sich nicht laden ($status).',
      'other': 'Die Liste hat zu wenige Einträge.',
    });
    return '$_temp0';
  }

  @override
  String get importFailed => 'Der Import ist fehlgeschlagen.';

  @override
  String get rankerImportText =>
      'Die ersten zehn Einträge der Liste ersetzen die Antworten dieser Frage.';

  @override
  String get rankerListUrl => 'URL der Ranker-Liste';

  @override
  String get import => 'Importieren';

  @override
  String get addTitle => 'Titel hinzufügen';

  @override
  String get arrowCircle => 'Dieser Pfeil würde im Kreis führen.';

  @override
  String screensWide(String count) {
    return '$count Bildschirme breit';
  }

  @override
  String get mapTapFirst => 'Tippe die Blase an, die zuerst kommt.';

  @override
  String get mapTapNext =>
      'Tippe jetzt die Blase an, zu der es geht: Das fügt einen Pfeil hinzu oder entfernt den vorhandenen. Tippe dieselbe Blase noch mal an, um alle Pfeile zu ihr zu entfernen.';

  @override
  String get mapDragBubble =>
      'Ziehen zum Verschieben. Mit − und + unten änderst du die Größe der Blase.';

  @override
  String get mapDragSelected =>
      'Ziehen zum Verschieben. Mit den Knöpfen unten änderst oder entfernst du es.';

  @override
  String get mapDragAnything =>
      'Zieh Dinge, um sie zu platzieren. Tippe eine Blase, einen Titel, ein Bild oder eine Linie an, um sie auszuwählen.';

  @override
  String get connect => 'Verbinden';

  @override
  String get line => 'Linie';

  @override
  String get narrower => 'Schmaler';

  @override
  String get wider => 'Breiter';

  @override
  String get tidyUp => 'Aufräumen';

  @override
  String get smaller => 'Kleiner';

  @override
  String get larger => 'Größer';

  @override
  String get editText => 'Text bearbeiten';

  @override
  String get couldNotCreateInvite =>
      'Der Einladungslink ließ sich nicht erstellen.';

  @override
  String get inviteLinkCopied => 'Einladungslink kopiert';

  @override
  String get removeFromGame => 'Aus dem Spiel entfernen';

  @override
  String get removeFromGameText =>
      'Der Zugriff endet sofort. Widerrufe Einladungslinks, die die Person noch hat, sonst kann sie wieder beitreten.';

  @override
  String get access => 'Zugriff';

  @override
  String get members => 'Mitglieder';

  @override
  String get you => 'Du';

  @override
  String get accessExplanation =>
      'Voller Zugriff bearbeitet alles. Eingeschränkter Zugriff sieht nur selbst erstellte oder geteilte Kategorien, so kann man Fragen schreiben und trotzdem mitspielen.';

  @override
  String get inviteLinks => 'Einladungslinks';

  @override
  String get noInviteLinksYet => 'Noch keine Einladungslinks';

  @override
  String get expired => 'Abgelaufen';

  @override
  String get valid => 'Gültig';

  @override
  String validFor(String time) {
    return 'Noch $time gültig';
  }

  @override
  String get copyLink => 'Link kopieren';

  @override
  String get revoke => 'Widerrufen';

  @override
  String newRoleLink(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'admin': 'Neuer Admin-Link',
      'full': 'Neuer Link mit vollem Zugriff',
      'other': 'Neuer Link mit eingeschränktem Zugriff',
    });
    return '$_temp0';
  }

  @override
  String get inviteLinksText =>
      'Wer einen Link hat, kann beitreten, bis er abläuft oder du ihn widerrufst.';

  @override
  String hourCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String dayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get notAnInviteLink =>
      'Das sieht nicht nach einem Einladungslink aus.';

  @override
  String get inviteGone => 'Diesen Einladungslink gibt es nicht mehr.';

  @override
  String get inviteExpired => 'Dieser Einladungslink ist abgelaufen.';

  @override
  String get couldNotCheckInvite =>
      'Der Einladungslink ließ sich nicht prüfen.';

  @override
  String get couldNotJoinGame =>
      'Beitreten hat nicht geklappt. Vielleicht bist du schon Mitglied oder der Link wurde widerrufen.';

  @override
  String get joinAGame => 'Einem Spiel beitreten';

  @override
  String get inviteLink => 'Einladungslink';

  @override
  String get unnamedGame => 'Spiel ohne Namen';

  @override
  String youWillJoinWith(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'admin': 'Du trittst als Admin bei.',
      'full': 'Du trittst mit vollem Zugriff bei.',
      'other': 'Du trittst mit eingeschränktem Zugriff bei.',
    });
    return '$_temp0';
  }

  @override
  String get continueLabel => 'Weiter';

  @override
  String get join => 'Beitreten';

  @override
  String get couldNotCreateSession => 'Die Session ließ sich nicht erstellen.';

  @override
  String get presentHere => 'Hier präsentieren';

  @override
  String get presentHereText =>
      'Ein anderes deiner Geräte hat diese Session zuletzt präsentiert. Es hört auf, falls es noch läuft.';

  @override
  String get deleteSession => 'Session löschen';

  @override
  String deleteSessionText(String game) {
    return 'Die Session von „$game“ wird mit ihren Teams und Punkten gelöscht.';
  }

  @override
  String get joinSessionScan => 'Einer Session beitreten: Code scannen';

  @override
  String get joinSessionLink => 'Einer Session mit ihrem Link beitreten';

  @override
  String get newSession => 'Neue Session';

  @override
  String get couldNotLoadSessions => 'Deine Sessions ließen sich nicht laden.';

  @override
  String get noSessionsText =>
      'Eine Session ist die Show eines Abends: ihre Teams, Punkte und ihr Fortschritt. Erstell eine, zeig sie auf dem großen Bildschirm und steuere sie vom Handy aus.';

  @override
  String get changeGame => 'Spiel ändern';

  @override
  String createdAt(String date) {
    return 'Erstellt am $date';
  }

  @override
  String get present => 'Vorführen';

  @override
  String get control => 'Steuern';

  @override
  String get setUpTeamsAndBuzzers => 'Teams und Buzzer einrichten';

  @override
  String get chooseAGame => 'Wähle ein Spiel';

  @override
  String get gameYouCannotOpen => 'Ein Spiel, das du nicht öffnen kannst';

  @override
  String get noGamesForSession =>
      'Du hast noch keine Spiele. Erstell zuerst eins im Tab „Spiele“.';

  @override
  String get game => 'Spiel';

  @override
  String get createWithoutGame => 'Ohne Spiel erstellen';

  @override
  String get create => 'Erstellen';

  @override
  String get didNotReachPresenter =>
      'Das kam beim präsentierenden Gerät nicht an.';

  @override
  String get noDevicePresenting =>
      'Kein Gerät präsentiert diese Session. Nichts, was du hier tust, passiert, bis eines sie präsentiert.';

  @override
  String get presentingElsewhere => 'Wird woanders präsentiert';

  @override
  String get presentingElsewhereText =>
      'Ein anderes deiner Geräte hat diese Session übernommen.';

  @override
  String get couldNotOpenWindow =>
      'Ein zweites Fenster ließ sich nicht öffnen.';

  @override
  String get couldNotStartPresenting =>
      'Diese Session ließ sich nicht präsentieren.';

  @override
  String get controlling => 'Steuerung';

  @override
  String get closePresenterWindow => 'Präsentationsfenster schließen';

  @override
  String get stopPresenting => 'Präsentation beenden';

  @override
  String get openInNewWindow =>
      'In neuem Fenster öffnen, um es auf einen anderen Bildschirm zu ziehen';

  @override
  String get fullscreen => 'Vollbild';

  @override
  String get controls => 'Steuerung';

  @override
  String get buzzerBoxRetrying =>
      'Buzzer-Box nicht verbunden · neuer Versuch läuft';

  @override
  String mediaNotDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mediendateien ließen sich nicht laden',
      one: '1 Mediendatei ließ sich nicht laden',
    );
    return '$_temp0';
  }

  @override
  String get couldNotSaveChange => 'Die Änderung ließ sich nicht speichern.';

  @override
  String setUpTitle(String title) {
    return '$title einrichten';
  }

  @override
  String get couldNotLoadSession => 'Die Session ließ sich nicht laden.';

  @override
  String get setUpFromControl =>
      'Wenn diese Session gerade auf einem Bildschirm läuft, richte sie lieber über „Steuern“ ein: Das präsentierende Gerät behält seine eigenen Teams.';

  @override
  String get teams => 'Teams';

  @override
  String get noTeamsYet => 'Noch keine Teams';

  @override
  String get queueBuzzers => 'Buzzer-Warteschlange';

  @override
  String get queueBuzzersText =>
      'Spätere Buzzer reihen sich hinter dem ersten ein';

  @override
  String get buzzerTest => 'Buzzer-Test';

  @override
  String get buzzerTestText =>
      'Buzzer lassen ihr Team aufleuchten; nur auf dem Spielbrett';

  @override
  String get buzzerBoxAndSounds => 'Buzzer-Box und Team-Sounds';

  @override
  String get buzzerBoxAndSoundsText =>
      'Die USB-Buzzer-Box und der Sound, mit dem jedes Team buzzert';

  @override
  String get connectDevices => 'Geräte verbinden';

  @override
  String get connectDevicesText =>
      'Handys als Buzzer oder eine weitere Steuerung';

  @override
  String get newTeam => 'Neues Team';

  @override
  String get renameTeam => 'Team umbenennen';

  @override
  String get removeTeam => 'Team entfernen';

  @override
  String removeTeamText(String team) {
    return '„$team“ und seine Punkte werden entfernt.';
  }

  @override
  String get addTeam => 'Team hinzufügen';

  @override
  String get noTeamsYetText =>
      'Noch keine Teams. Füg sie hier hinzu oder lass sie mit einem Code beitreten.';

  @override
  String get couldNotCreateCodes => 'Die Codes ließen sich nicht erstellen.';

  @override
  String get controller => 'Steuerung';

  @override
  String get scanToControl =>
      'In Quiz Studio scannen, um diese Session von einem anderen Gerät aus zu steuern. Das Gerät muss mit einem Konto angemeldet sein, das das Spiel öffnen kann.';

  @override
  String scanToBuzz(String team) {
    return 'In Quiz Studio scannen, um ein Handy als Buzzer von $team zu nutzen.';
  }

  @override
  String get devicesViaInternet => 'Geräte verbinden sich über das Internet.';

  @override
  String get devicesViaLan =>
      'Geräte in diesem Netzwerk verbinden sich direkt, andere über das Internet.';

  @override
  String get linkCopied => 'Link kopiert';

  @override
  String get copyLinkInstead => 'Stattdessen Link kopieren';

  @override
  String get addTeamsFirst =>
      'Füg zuerst Teams hinzu, um für jedes einen Buzzer-Code zu bekommen.';

  @override
  String get teamRemoved => 'Dieses Team wurde entfernt.';

  @override
  String get buzzForTeam => 'Für dieses Team buzzern';

  @override
  String get setPoints => 'Punkte setzen';

  @override
  String get sessionHasNoGame => 'Diese Session hat noch kein Spiel.';

  @override
  String get statusBoard => 'Spielbrett';

  @override
  String get statusBetsShown =>
      'Die Einsätze sind auf dem großen Bildschirm · starte die Frage, wenn ihr bereit seid';

  @override
  String statusBetting(int placed, int total) {
    return 'Teams setzen · $placed von $total Einsätzen da';
  }

  @override
  String get statusRapidDevices =>
      'Teams wählen auf ihren Geräten richtig oder falsch';

  @override
  String get statusAmountBet =>
      'Teams versuchen, ihre gewettete Zahl zu schaffen';

  @override
  String get statusOpenNoBuzzers => 'Frage offen · keine Buzzer';

  @override
  String get statusOpenWaiting => 'Frage offen · warte auf einen Buzzer';

  @override
  String statusAnswering(String team) {
    return '$team antwortet';
  }

  @override
  String statusAnsweringThen(String team, String next) {
    return '$team antwortet · danach $next';
  }

  @override
  String get statusAnswerRevealed => 'Antwort aufgedeckt';

  @override
  String get noGamePicked =>
      'Noch kein Spiel gewählt. Wähle eins für diese Session in der Liste der Sessions.';

  @override
  String get groupHasNoQuestions => 'Diese Gruppe hat keine Fragen.';

  @override
  String questionsPlayed(int played, int total) {
    return '$played von $total Fragen gespielt';
  }

  @override
  String get teamsBetTheirPoints => 'Teams setzen ihre Punkte';

  @override
  String betQuestionShown(String prompt) {
    return 'Wettfrage: $prompt';
  }

  @override
  String get enlargedImage => 'Vergrößertes Bild';

  @override
  String get noStrikes => 'Keine Fehler';

  @override
  String get strikes => 'Fehler';

  @override
  String get resetStrikes => 'Fehler zurücksetzen';

  @override
  String get buzzBeforeUncover =>
      'Ein Team muss buzzern, bevor Antworten aufgedeckt werden können.';

  @override
  String betFor(String team) {
    return 'Einsatz von $team';
  }

  @override
  String betRange(int limit) {
    return '0 bis $limit Punkte';
  }

  @override
  String get betsTapTeam =>
      'Einsätze · tippe ein Team an, um seinen Einsatz einzutragen';

  @override
  String get bets => 'Einsätze';

  @override
  String upTo(int limit) {
    return 'bis $limit';
  }

  @override
  String get noBet => 'kein Einsatz';

  @override
  String get allPointsGiven => 'Alle Punkte vergeben';

  @override
  String get givePoints => 'Punkte vergeben';

  @override
  String givePointsToTeams(int count) {
    return 'Punkte an $count Teams vergeben';
  }

  @override
  String get given => 'Vergeben';

  @override
  String get notGivenYet => 'Noch nicht vergeben';

  @override
  String givenSoFar(String points) {
    return 'Bisher $points vergeben';
  }

  @override
  String get takeOutOfOrder => 'Aus der Reihenfolge nehmen';

  @override
  String get putNextInOrder => 'Als Nächstes einreihen';

  @override
  String pointsFor(String team) {
    return 'Punkte für $team';
  }

  @override
  String get pointsForQuestion => 'Punkte für diese Frage';

  @override
  String get didTeamsReach => 'Hat jedes Team seine Zahl geschafft?';

  @override
  String tapInOrder(String points, int step) {
    return 'Tippe die Teams in der Reihenfolge an, in der sie fertig werden · $points, dann je $step weniger';
  }

  @override
  String get rateEachTeam => 'Bewerte jedes Team';

  @override
  String goal(int goal) {
    return 'Ziel $goal';
  }

  @override
  String get otherPoints => 'Andere Punkte';

  @override
  String get otherPointsMenu => 'Andere Punkte …';

  @override
  String get reached => 'Geschafft';

  @override
  String get missed => 'Verfehlt';

  @override
  String get pointsForAnswer => 'Punkte für diese Antwort';

  @override
  String teamWins(String team, int points) {
    return '$team gewinnt · +$points';
  }

  @override
  String teamsTurn(String team) {
    return '$team ist dran';
  }

  @override
  String get nobodyLeft => 'Niemand mehr übrig';

  @override
  String get noPromptsLeft => 'Keine Vorgaben mehr';

  @override
  String get undo => 'Rückgängig';

  @override
  String get rapidNoItems => 'Dieser Fragenhagel hat noch keine Fragen.';

  @override
  String answerShown(String answer) {
    return 'Antwort: $answer';
  }

  @override
  String allDone(int count) {
    return 'Alle $count geschafft';
  }

  @override
  String itemOf(int item, int count) {
    return 'Frage $item von $count';
  }

  @override
  String get topAnswersEmpty =>
      'Diese Frage hat noch keine Antworten auf ihrer Liste.';

  @override
  String get topTapToUncover =>
      'Tippe eine Antwort an, um sie auf dem großen Bildschirm aufzudecken.';

  @override
  String topTapNamed(String team) {
    return 'Tippe die Antwort an, die $team genannt hat. Falsch, wenn sie nicht auf der Liste steht.';
  }

  @override
  String get topWhenBuzz =>
      'Wenn ein Team buzzert, tippe die Antwort an, die es nennt.';

  @override
  String get revealGroupNow => 'Jetzt eine Gruppe aufdecken?';

  @override
  String get revealGroupNowText =>
      'Die Teams spielen noch und sehen diese Gruppe dann auch auf ihren Geräten. Ihre Zeit läuft weiter.';

  @override
  String get reveal => 'Aufdecken';

  @override
  String get stealWorked => 'Klauen geklappt';

  @override
  String get stealFailed => 'Klauen gescheitert';

  @override
  String get strike => 'Fehler';

  @override
  String get hide => 'Verbergen';

  @override
  String get betsAreIn => 'Einsätze stehen';

  @override
  String get startQuestion => 'Frage starten';

  @override
  String get showAnswer => 'Antwort zeigen';

  @override
  String get finish => 'Beenden';

  @override
  String get nextItem => 'Nächste Frage';

  @override
  String get solution => 'Lösung';

  @override
  String get revealGroup => 'Gruppe zeigen';

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Abspielen';

  @override
  String get nextTeam => 'Nächstes Team';

  @override
  String get reopen => 'Wieder öffnen';

  @override
  String get tabBoard => 'Spielbrett';

  @override
  String get tabEffects => 'Effekte';

  @override
  String get tabAnswers => 'Antworten';

  @override
  String get tabSetup => 'Einrichten';

  @override
  String get ungrouped => 'Ohne Gruppe';

  @override
  String get groupHasNoCategories => 'Diese Gruppe hat keine Kategorien.';

  @override
  String get showCategoryInMiddle => 'Diese Kategorie in der Mitte zeigen';

  @override
  String get tapFieldToRead => 'Tippe ein Feld an, um seine Frage zu lesen.';

  @override
  String get onScreen => 'auf dem Bildschirm';

  @override
  String get played => 'gespielt';

  @override
  String get takeOffKeepPlayable => 'Vom Bildschirm nehmen, spielbar lassen';

  @override
  String get markNotPlayed => 'Als nicht gespielt markieren';

  @override
  String get openQuestion => 'Frage öffnen';

  @override
  String get slotBoard => 'Spielbrett';

  @override
  String get slotCalm => 'Ruhig';

  @override
  String get slotThrilling => 'Spannend';

  @override
  String get effectClosed => 'Beendet';

  @override
  String get effectLockedIn => 'Eingeloggt';

  @override
  String get effectCountdown => 'Countdown';

  @override
  String get effectFanfare => 'Fanfare';

  @override
  String get onScreenHeader => 'Auf dem Bildschirm';

  @override
  String get animation => 'Animation';

  @override
  String get noCardsPrepare => 'Keine Karten. Bereite welche im Editor vor.';

  @override
  String get textToShow => 'Text zum Zeigen';

  @override
  String get show => 'Zeigen';

  @override
  String get noCardOnScreen => 'Keine Karte auf dem Bildschirm';

  @override
  String get takeCardOff => 'Karte vom Bildschirm nehmen';

  @override
  String get keepSpeakersAwake => 'Lautsprecher wach halten';

  @override
  String get fewerDetails => 'Weniger Details';

  @override
  String get whatIsThis => 'Was ist das?';

  @override
  String get keepSpeakersAwakeText =>
      'Viele Lautsprecher schalten sich nach ein paar Minuten Stille aus und verpassen dann den Anfang des nächsten Sounds. Das spielt ein ganz leises Rauschen, wenn sonst nichts läuft; Musik und Fragen-Sounds übernehmen, sobald sie starten.';

  @override
  String get softNoise => 'Sanftes Rauschen';

  @override
  String get whiteNoise => 'Weißes Rauschen';

  @override
  String noiseVolume(int volume) {
    return 'Rauschen $volume %';
  }

  @override
  String get soundEffects => 'Soundeffekte';

  @override
  String get questionSound => 'Sound der Frage';

  @override
  String get answersOnDevices => 'Antworten auf den Geräten der Teams';

  @override
  String get openAQuestionFirst => 'Öffne zuerst eine Frage.';

  @override
  String get answersOnDevicesText =>
      'Jedes Team antwortet auf seinem eigenen Gerät. Du siehst die Antworten, sobald sie kommen; das Publikum erst, wenn du sie zeigst.';

  @override
  String get preparedScreensText =>
      'Schieberegler, Sortieren, Zuordnen und vorbereitete Whiteboards werden pro Frage im Editor eingerichtet und starten von selbst.';

  @override
  String get roundOpen => 'offen';

  @override
  String get roundLocked => 'gesperrt';

  @override
  String answersIn(int count, int total) {
    return '$count von $total da';
  }

  @override
  String get lockAll => 'Alle sperren';

  @override
  String get letThemEditAgain => 'Wieder bearbeiten lassen';

  @override
  String get showAll => 'Alle zeigen';

  @override
  String get rateAutomatically => 'Automatisch bewerten';

  @override
  String get givePointsForGroups => 'Punkte für Gruppen vergeben';

  @override
  String get discard => 'Verwerfen';

  @override
  String solutionShown(String solution) {
    return 'Lösung: $solution';
  }

  @override
  String partialRight(int right, int total) {
    return '$right von $total richtig';
  }

  @override
  String get looksRight => 'Sieht richtig aus';

  @override
  String get looksWrong => 'Sieht falsch aus';

  @override
  String get takeOffScreen => 'Vom Bildschirm nehmen';

  @override
  String get showOnScreen => 'Auf dem Bildschirm zeigen';

  @override
  String halfPoints(int points) {
    return 'Halbe Punkte (+$points)';
  }

  @override
  String outPlaceLabel(String place) {
    return '$place raus';
  }

  @override
  String get waitingForGame => 'Warte auf ein Spiel …';

  @override
  String betValue(int bet) {
    return 'Einsatz $bet';
  }

  @override
  String goalValue(int goal) {
    return 'Ziel $goal';
  }

  @override
  String get howManyCanYouDo => 'Wie viele schafft ihr?';

  @override
  String get theBets => 'Die Einsätze';

  @override
  String get placeYourBets => 'Macht eure Einsätze';

  @override
  String get betRule => 'Richtig gewinnt euren Einsatz, falsch verliert ihn';

  @override
  String amountRuleWithMinus(int plus, int minus) {
    return 'Schafft eure Zahl: $plus Punkte für jedes · verfehlt: −$minus für jedes';
  }

  @override
  String amountRule(int plus) {
    return 'Schafft eure Zahl: $plus Punkte für jedes';
  }

  @override
  String get findFourGroups => 'Findet vier Vierergruppen';

  @override
  String get isLastTeamStanding => 'bleibt als letztes Team übrig';

  @override
  String get thatWasTheLastOne => 'Das war die letzte!';

  @override
  String thenTeams(String teams) {
    return 'danach $teams';
  }

  @override
  String get noColour => 'Keine Farbe';

  @override
  String get useThisColour => 'Diese Farbe verwenden';

  @override
  String get presenterWindowTitle => 'Quiz Studio · Präsentation';

  @override
  String get reconnectingMainWindow => 'Verbinde erneut mit dem Hauptfenster …';

  @override
  String get connectingMainWindow => 'Verbinde mit dem Hauptfenster …';

  @override
  String get leaveFullScreen => 'Vollbild verlassen (Esc)';

  @override
  String get fullScreenF11 => 'Vollbild (F11)';

  @override
  String get dragToProjector =>
      'Zieh dieses Fenster auf den Beamer, dann doppelklicke darauf oder drück F11 für Vollbild.';

  @override
  String pictureLabel(String label) {
    return 'Bild $label';
  }

  @override
  String get yourAnswer => 'Eure Antwort';

  @override
  String get slideToAnswer => 'Schieb zum Antworten';

  @override
  String get dragIntoOrder => 'In die richtige Reihenfolge ziehen';

  @override
  String get thisOrderIsRight => 'Diese Reihenfolge stimmt';

  @override
  String foundOfFour(int count) {
    return '$count von 4 gefunden';
  }

  @override
  String mistakeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fehler',
      one: '1 Fehler',
    );
    return '$_temp0';
  }

  @override
  String get yourPairs => 'Eure Paare';

  @override
  String tapWhereItGoes(String item) {
    return 'Tippe jetzt, wohin „$item“ gehört';
  }

  @override
  String get allPlacedSwap => 'Alles zugeordnet · ziehen zum Tauschen';

  @override
  String get dragOntoPartner => 'Zieh jede Antwort auf ihren Partner';

  @override
  String get dropToTakeBack => 'Hier ablegen, um es zurückzunehmen';

  @override
  String get allPlaced => 'Alles zugeordnet';

  @override
  String get praisePerfect => 'Perfekt!';

  @override
  String get praiseGreat => 'Super!';

  @override
  String get praiseNice => 'Schön!';

  @override
  String get praiseSolid => 'Solide!';

  @override
  String get allFourFound => 'Alle vier gefunden!';

  @override
  String get noTriesLeft => 'Keine Versuche mehr';

  @override
  String get oneAway => 'Eins daneben …';

  @override
  String get notAGroup => 'Keine Gruppe';

  @override
  String get alreadyGuessed => 'Schon versucht';

  @override
  String get allFourGroupsFound => 'Alle vier Gruppen gefunden';

  @override
  String get noTriesLeftWait => 'Keine Versuche mehr. Wartet auf die Lösung';

  @override
  String lockedInWith(int count) {
    return 'Eingeloggt mit $count von 4';
  }

  @override
  String get timeIsUp => 'Die Zeit ist um';

  @override
  String get mistakesRemaining => 'Verbleibende Fehler:';

  @override
  String get shuffle => 'Mischen';

  @override
  String get deselectAll => 'Auswahl aufheben';

  @override
  String get submit => 'Abschicken';

  @override
  String get wereDone => 'Wir sind fertig';

  @override
  String get clear => 'Löschen';

  @override
  String get notASessionCode => 'Das ist kein Session-Code von Quiz Studio.';

  @override
  String get couldNotJoinSession =>
      'Beitreten hat nicht geklappt. Der Code ist vielleicht nicht mehr gültig.';

  @override
  String get session => 'Session';

  @override
  String get justNow => 'gerade eben';

  @override
  String minutesAgo(int count) {
    return 'vor $count Minuten';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Stunden',
      one: 'vor 1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Tagen',
      one: 'vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get rejoinAsTeam => 'Wieder als Gerät eines Teams beitreten';

  @override
  String get rejoinAsController => 'Wieder als Steuerung beitreten';

  @override
  String joinedAgo(String ago) {
    return 'Beigetreten $ago';
  }

  @override
  String get joinLink => 'Beitrittslink';

  @override
  String get orPasteLink => 'Oder füg den Link ein';

  @override
  String get joinTerms =>
      'Mit dem Beitreten stimmst du den Nutzungsbedingungen und der Datenschutzerklärung zu. Kein Konto und kein Name nötig.';

  @override
  String get joinASession => 'Einer Session beitreten';

  @override
  String get pasteJoinLinkHelp =>
      'Öffne „Geräte verbinden“ auf dem präsentierenden Gerät, kopier dort den Beitrittslink und füg ihn hier ein.';

  @override
  String get didNotGetThrough => 'Das kam nicht an.';

  @override
  String get couldNotReachSession => 'Diese Session ist nicht erreichbar.';

  @override
  String get waitingForShow => 'Warte, bis die Show beginnt …';

  @override
  String get teamRemovedFromSession =>
      'Euer Team wurde aus der Session entfernt.';

  @override
  String get youAreLastTeam => 'Ihr seid als letztes Team übrig!';

  @override
  String teamWinsShort(String team) {
    return '$team gewinnt';
  }

  @override
  String get youAreOut => 'Ihr seid raus';

  @override
  String get yourTurn => 'Ihr seid dran!';

  @override
  String get buzzerTestPress => 'Buzzer-Test: zum Prüfen drücken';

  @override
  String get waitingForNextQuestion => 'Warte auf die nächste Frage';

  @override
  String yourGoal(int goal) {
    return 'Euer Ziel: $goal';
  }

  @override
  String get goalReached => 'Ziel erreicht!';

  @override
  String get goalMissed => 'Ziel verfehlt';

  @override
  String get buzzOnBox => 'Buzzert an der Buzzer-Box';

  @override
  String get buzzWhenYouKnow => 'Buzzert, wenn ihr es wisst!';

  @override
  String get noBuzzersForQuestion => 'Keine Buzzer bei dieser Frage';

  @override
  String numberInLine(int n) {
    return 'Ihr seid Nummer $n in der Reihe';
  }

  @override
  String get anotherTeam => 'Ein anderes Team';

  @override
  String get needsNewerVersion =>
      'Diese Frage braucht eine neuere Version von Quiz Studio. Bitte aktualisiere die App.';

  @override
  String get answerHere => 'Hier antworten';

  @override
  String get answerBeingShown => 'Eure Antwort wird gezeigt';

  @override
  String get lockedInWaiting => 'Eingeloggt, warte auf die anderen';

  @override
  String get answersAreIn => 'Die Antworten sind da';

  @override
  String pointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Punkte',
      one: '1 Punkt',
    );
    return '$_temp0';
  }

  @override
  String betShort(int bet) {
    return 'Einsatz $bet';
  }

  @override
  String get rightExclaim => 'Richtig!';

  @override
  String get notThisTime => 'Diesmal nicht';

  @override
  String get answerCountsWhenEnded =>
      'Eure Antwort zählt so, wie sie steht, wenn die Spielleitung die Runde beendet.';

  @override
  String get answerCountsWhenTimeUp =>
      'Eure Antwort zählt so, wie sie steht, wenn die Zeit um ist.';

  @override
  String get lockedIn => 'Eingeloggt';

  @override
  String lockedInAfter(String seconds) {
    return 'Eingeloggt nach $seconds s';
  }

  @override
  String get lockInAnswer => 'Antwort einloggen';

  @override
  String get answerFirst => 'Erst antworten';

  @override
  String get answerOnBigScreen => 'Eure Antwort ist auf dem großen Bildschirm.';

  @override
  String get gettingPicture => 'Bild wird geladen …';

  @override
  String get connectedLan => 'Über das lokale Netzwerk verbunden';

  @override
  String get connectedInternet => 'Über das Internet verbunden';

  @override
  String yourBetOn(String category) {
    return 'Euer Einsatz auf $category';
  }

  @override
  String get placeYourBet => 'Macht euren Einsatz';

  @override
  String get theGoals => 'Die Ziele';

  @override
  String betOutcome(int value) {
    return 'Richtig: +$value · Falsch: −$value';
  }

  @override
  String amountOutcomeWithMinus(int win, int lose) {
    return 'Geschafft: +$win · Verfehlt: −$lose';
  }

  @override
  String amountOutcome(int win) {
    return 'Geschafft: +$win';
  }

  @override
  String get betNothing => 'Nichts';

  @override
  String get betHalf => 'Halb';

  @override
  String get allIn => 'Alles';

  @override
  String get questionStartsSoon => 'Die Frage startet gleich';

  @override
  String get betPlaced => 'Einsatz steht';

  @override
  String changeTo(int value) {
    return 'Auf $value ändern';
  }

  @override
  String betAction(int value) {
    return '$value setzen';
  }

  @override
  String get buzzerSoundTooBig =>
      'Diese Datei ist zu groß; ein Buzzer-Sound darf bis zu 5 MB haben.';

  @override
  String get notASoundFile =>
      'Das ist keine Sounddatei, die die App abspielen kann.';

  @override
  String get couldNotUploadBuzzerSound =>
      'Der Sound ließ sich nicht hochladen. Das Team behält seinen bisherigen.';

  @override
  String get buzzers => 'Buzzer';

  @override
  String get useUsbBox => 'USB-Buzzer-Box verwenden';

  @override
  String get useUsbBoxText =>
      'Aus: Teams buzzern nur mit ihren Handys, und der große Bildschirm sucht nach keiner Box.';

  @override
  String get usbBoxPlatforms =>
      'Eine USB-Buzzer-Box funktioniert unter Windows, macOS und Linux. Handys und Tablets können trotzdem Buzzer sein: siehe „Geräte verbinden“.';

  @override
  String get buzzerSounds => 'Buzzer-Sounds';

  @override
  String get buzzerSoundsText =>
      'Wird mit der Session gespeichert und vom präsentierenden Gerät abgespielt. Bis das Gerät einen Sound geladen hat, und für Teams ohne eigenen, ertönt der eingebaute Buzzer.';

  @override
  String get ownSound => 'Eigener Sound';

  @override
  String get chooseBuzzerSound => 'Buzzer-Sound wählen';

  @override
  String get uploadOwnSound => 'Eigenen Sound hochladen …';

  @override
  String get choose => 'Wählen';

  @override
  String get backToBuiltinBuzzer => 'Zurück zum eingebauten Buzzer';

  @override
  String get addTeamsFirstShort => 'Füg zuerst Teams hinzu.';

  @override
  String get test => 'Test';

  @override
  String get clearOrder => 'Reihenfolge löschen';

  @override
  String get calibrate => 'Kalibrieren';

  @override
  String get buzzersAppearHere =>
      'Die Buzzer erscheinen hier, sobald die Box Werte sendet.';

  @override
  String get pressTheBuzzers =>
      'Drück die Buzzer. Jeder leuchtet, solange er gedrückt ist, und die Zahlen zeigen, wer zuerst war. Tippe einen an, um sein Team oder seine Empfindlichkeit zu ändern.';

  @override
  String get assignAllByPressing => 'Alle per Drücken zuordnen';

  @override
  String pressBuzzerOf(String team) {
    return 'Drück jetzt den Buzzer von $team';
  }

  @override
  String moreToGo(int count) {
    return 'noch $count';
  }

  @override
  String get defaultAssignment =>
      'Ohne Zuordnung ist Buzzer 1 das erste Team, Buzzer 2 das zweite und so weiter.';

  @override
  String get noBuzzer => 'Kein Buzzer';

  @override
  String buzzerN(int n) {
    return 'Buzzer $n';
  }

  @override
  String get assignByPressing => 'Per Drücken zuordnen';

  @override
  String get addTeamsInSessionFirst => 'Füg zuerst Teams in der Session hinzu.';

  @override
  String get rawData => 'Rohdaten';

  @override
  String get rawDataText => 'Genau das, was die Box sendet, zur Fehlersuche';

  @override
  String get nothingReceivedYet => 'Noch nichts empfangen.';

  @override
  String get notConnectedDot => 'Nicht verbunden.';

  @override
  String get team => 'Team';

  @override
  String get byPosition => 'Nach Position';

  @override
  String get howHardPressed => 'Wie fest gedrückt werden muss';

  @override
  String readingThreshold(int value, int threshold) {
    return 'Wert $value · zählt als gedrückt über $threshold';
  }

  @override
  String get noBuzzerPressedClearly => 'Kein Buzzer wurde eindeutig gedrückt.';

  @override
  String calibratedBuzzers(int count) {
    return '$count Buzzer kalibriert.';
  }

  @override
  String get connected => 'Verbunden';

  @override
  String readingsPerSecond(int rate, String uptime) {
    return '$rate Werte pro Sekunde · seit $uptime';
  }

  @override
  String reconnectedTimes(int count) {
    return '$count× neu verbunden';
  }

  @override
  String get boxSilent => 'Offen, aber die Box sendet nichts';

  @override
  String get boxSilentText =>
      'Neuer Versuch alle paar Sekunden. Ist es der richtige Port und hat die Box Strom?';

  @override
  String get notConnectedShort => 'Nicht verbunden';

  @override
  String get boxDisconnectedText =>
      'Neuer Versuch alle paar Sekunden. Steck die Box ein; hier muss nichts gedrückt werden.';

  @override
  String get choosePort => 'Wähle den Port der Buzzer-Box';

  @override
  String get rememberedOnDevice => 'Er wird auf diesem Gerät gespeichert.';

  @override
  String get noSerialPorts => 'Keine seriellen Ports auf diesem Gerät';

  @override
  String get port => 'Port';

  @override
  String get reconnectNow => 'Jetzt neu verbinden';

  @override
  String get noTeam => 'Kein Team';

  @override
  String get pressEveryBuzzer =>
      'Drück jetzt jeden Buzzer einmal, so fest wie ein Spieler.';

  @override
  String get handsOff => 'Kurz alle Buzzer loslassen …';

  @override
  String get waitingFirstPress => 'Warte auf den ersten Druck.';

  @override
  String gotBuzzers(String buzzers) {
    return 'Erkannt: Buzzer $buzzers.';
  }

  @override
  String get yourNumber => 'Eure Zahl';

  @override
  String get confetti => 'Konfetti';

  @override
  String get flash => 'Blitz';

  @override
  String get fireworks => 'Feuerwerk';

  @override
  String get balloons => 'Luftballons';

  @override
  String get stars => 'Sterne';

  @override
  String get spotlight => 'Spotlight';

  @override
  String get editTitle => 'Titel bearbeiten';

  @override
  String get noPicture => 'Kein Bild';

  @override
  String get noMusic => 'Keine Musik';

  @override
  String get firstItem => 'Erste Frage';

  @override
  String get rapidIntro =>
      'Erst die Frage selbst: vorlesen, dann zeigt Weiter Frage 1';

  @override
  String get closeAnswering => 'Abgabeschluss';

  @override
  String hintShown(String hint) {
    return 'Hinweis: $hint';
  }

  @override
  String get byClosenessShort => 'nach Nähe';

  @override
  String byClosenessSummary(int plus, int step) {
    return 'Nach Nähe · $plus, dann −$step pro Platz';
  }

  @override
  String get scoringClosenessText =>
      'Das Team, dessen Zahl dem richtigen Wert am nächsten ist, bekommt die meisten Punkte, jeder Platz danach etwas weniger. Gleich nahe Teams teilen sich einen Platz. Die Plätze zählen, sobald die Antworten beendet sind, und der große Bildschirm zeigt sie mit den Antworten.';

  @override
  String get scoringClosenessNoSolution =>
      'Die Plätze richten sich danach, wie nah jede Zahl am richtigen Wert ist. Gib dafür unter Wie Teams antworten einen richtigen Wert an.';

  @override
  String placeN(String place) {
    return '$place Platz';
  }

  @override
  String get statusRapidIntro => 'Frage offen · erst vorlesen';
}
