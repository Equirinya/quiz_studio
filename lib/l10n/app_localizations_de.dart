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
  String get couldNotOpenStore => 'Store lässt sich nicht öffnen';

  @override
  String get downloadPage => 'Download-Seite';

  @override
  String get updateRequired => 'Update nötig';

  @override
  String get updateRequiredText =>
      'Diese Version wird nicht mehr unterstützt. Bitte aktualisiere die App.';

  @override
  String installedAndRequired(String installed, String required) {
    return 'Installiert: $installed · nötig: $required';
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
      'Deine Spiele bleiben erhalten. Danach kannst du dich auch auf deinen anderen Geräten anmelden.';

  @override
  String get upgradeDone => 'Fertig. Dein Konto hat jetzt eine E-Mail-Adresse.';

  @override
  String get signOut => 'Abmelden';

  @override
  String get signOutGuestWarning =>
      'Du bist als Gast angemeldet. Wenn du dich abmeldest, sind dieses Konto und alle Spiele weg, die nur darin liegen. Füg vorher eine E-Mail-Adresse hinzu, um sie zu behalten.';

  @override
  String get signOutInfo =>
      'Du kannst dich jederzeit mit E-Mail und Passwort wieder anmelden.';

  @override
  String get deletingAccount => 'Konto wird gelöscht …';

  @override
  String get accountDeleted => 'Dein Konto und deine Daten sind gelöscht.';

  @override
  String get accountNotDeletedConnection =>
      'Konto konnte nicht gelöscht werden. Prüf deine Verbindung und versuch es noch mal.';

  @override
  String get nameSubtitle => 'So sehen dich Mitspieler und Mitautoren';

  @override
  String get guestAccount => 'Gastkonto';

  @override
  String get guestAccountText =>
      'Deine Spiele liegen nur im Konto auf diesem Gerät. Füg E-Mail und Passwort hinzu, damit sie sicher sind und du dich auch auf anderen Geräten anmelden kannst, z. B. am PC für die Show und am Handy zum Steuern.';

  @override
  String get emailSubtitle =>
      'Damit meldest du dich auf deinen anderen Geräten an';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountSubtitle => 'Profil, eigene Spiele und Sessions';

  @override
  String get contact => 'Kontakt';

  @override
  String get contactSubtitle => 'Feedback, Bugs und Wünsche';

  @override
  String get terms => 'Nutzungsbedingungen';

  @override
  String get privacy => 'Datenschutz';

  @override
  String get aboutAndLicences => 'Über & Lizenzen';

  @override
  String get soundCredits => 'Sound-Quellen';

  @override
  String get soundCreditsSubtitle => 'Woher die Sounds kommen';

  @override
  String get deleteAccountQuestion => 'Konto löschen?';

  @override
  String get deleteAccountText =>
      'Gelöscht werden dein Profil, die Spiele, in denen nur du bist (mit Bildern und Sounds), und die Sessions, die du leitest. Geteilte Spiele bleiben für die anderen erhalten; bist du dort der einzige Admin, wird ein Mitautor Admin. Das kann nicht rückgängig gemacht werden.';

  @override
  String get password => 'Passwort';

  @override
  String get wrongPassword => 'Falsches Passwort.';

  @override
  String get tooManyTries =>
      'Zu viele Versuche. Warte kurz und versuch es dann noch mal.';

  @override
  String get requiresRecentLogin =>
      'Bitte melde dich einmal ab und wieder an, dann klappt das Löschen.';

  @override
  String get noConnectionTryOnline =>
      'Keine Verbindung. Versuch es noch mal, sobald du online bist.';

  @override
  String get accountNotDeleted =>
      'Konto konnte nicht gelöscht werden. Versuch es noch mal.';

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
      'Diese E-Mail-Adresse hat schon ein Konto. Melde dich lieber damit an.';

  @override
  String get invalidEmail => 'Ungültige E-Mail-Adresse.';

  @override
  String get weakPassword => 'Bitte nimm ein sichereres Passwort.';

  @override
  String get alreadyHasEmail => 'Dieses Konto hat schon eine E-Mail-Adresse.';

  @override
  String get restartAndRetry => 'Starte die App neu und versuch es noch mal.';

  @override
  String get notConnected => 'Du bist offline.';

  @override
  String get emailSignInOff =>
      'Anmeldung per E-Mail ist für diese App deaktiviert.';

  @override
  String get didNotWorkTryAgain => 'Hat nicht geklappt. Versuch es noch mal.';

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
  String get passwordsDontMatch => 'Die Passwörter sind nicht gleich.';

  @override
  String get featureBuildTitle => 'Quizze zusammen bauen';

  @override
  String get featureBuildText =>
      'Schreib Kategorien und Fragen mit Freunden, ohne euch die Antworten zu spoilern.';

  @override
  String get featurePresentTitle => 'Ab auf den großen Bildschirm';

  @override
  String get featurePresentText =>
      'Zeig die Show auf dem Fernseher oder Beamer und steuer sie vom Handy.';

  @override
  String get featureBuzzersTitle => 'Handys als Buzzer';

  @override
  String get featureBuzzersText =>
      'Code scannen und mitspielen. Arduino-Buzzer gehen auch.';

  @override
  String get featureMusicTitle => 'Musik und Soundeffekte';

  @override
  String get featureMusicText =>
      'Hintergrundmusik, Sounds beim Aufdecken und ein eigener Buzzer-Sound pro Team.';

  @override
  String get enterValidEmail => 'Bitte gib eine gültige E-Mail-Adresse ein.';

  @override
  String get enterPassword => 'Bitte gib dein Passwort ein.';

  @override
  String get noAccountForEmail =>
      'Für diese E-Mail-Adresse gibt es kein Konto.';

  @override
  String get wrongEmailOrPassword => 'E-Mail-Adresse oder Passwort falsch.';

  @override
  String get invalidEmailShort => 'Ungültige E-Mail-Adresse.';

  @override
  String get accountDisabled => 'Dieses Konto ist gesperrt.';

  @override
  String get tooManyAttempts =>
      'Zu viele Versuche. Versuch es später noch mal.';

  @override
  String get signInFailed =>
      'Anmeldung hat nicht geklappt. Versuch es noch mal.';

  @override
  String get anonymousSignInDisabled =>
      'Anmeldung ohne Konto ist gerade deaktiviert. Versuch es später noch mal.';

  @override
  String get couldNotStart => 'Hat nicht geklappt. Versuch es noch mal.';

  @override
  String get unknownError => 'Unbekannter Fehler.';

  @override
  String get couldNotSaveName =>
      'Name konnte nicht gespeichert werden. Versuch es noch mal.';

  @override
  String get login => 'Anmelden';

  @override
  String get chooseYourName =>
      'Wähl den Namen, den Mitspieler und Mitautoren sehen:';

  @override
  String get theNameOthersWillSee => 'Der Name, den andere sehen';

  @override
  String get justJoinAShow => 'Nur mitspielen';

  @override
  String get useDifferentAccount => 'Anderes Konto';

  @override
  String get haveAnAccount => 'Ich hab schon ein Konto';

  @override
  String get termsBefore => 'Wenn du weitermachst, stimmst du den ';

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
  String get createOwnQuizzes => 'Eigene Quizze bauen';

  @override
  String get creditsMadeForApp => 'Extra für Quiz Studio gemacht';

  @override
  String creditsMadeBy(String name) {
    return 'Von $name';
  }

  @override
  String get creditsPartOfApp => 'Teil der App';

  @override
  String get creditsPublicDomain => '(gemeinfrei)';

  @override
  String get creditsIntro =>
      'Die Sounds in Quiz Studio wurden extra dafür gemacht oder sind frei nutzbar (CC0). Tippe auf eine Quelle, um zu sehen, woher ein Sound kommt.';

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
      'ordering': 'Sortieren',
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
      'slider': 'Slider',
      'choice': 'Auswahl',
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
      'teams': 'Wie die Teams sortiert sind',
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
      'whiteboard': 'Whiteboard auf den Geräten',
      'other': 'Richtig/falsch auf den Geräten',
    });
    return '$_temp0';
  }

  @override
  String progressStyleName(String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'off': 'Keine Fortschrittsanzeige',
      'bar': 'Balken',
      'dots': 'Punkte',
      'battery': 'Akku',
      'thermometer': 'Thermometer',
      'other': 'Fluxkompensator',
    });
    return '$_temp0';
  }

  @override
  String topAnswersModeName(String mode) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'buzzer': 'Teams buzzern',
      'typed': 'Auf den Geräten tippen',
      'other': 'Aufs Whiteboard schreiben',
    });
    return '$_temp0';
  }

  @override
  String cardAnimationName(String animation) {
    String _temp0 = intl.Intl.selectLogic(animation, {
      'off': 'Aus',
      'fade': 'Einblenden',
      'slideUp': 'Von unten',
      'slideDown': 'Von oben',
      'bounce': 'Reinhüpfen',
      'zoom': 'Zoom',
      'spin': 'Reindrehen',
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
      'final_round': 'Finale',
      'winner': 'Und gewonnen hat …',
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
  String get couldNotCreateGame => 'Spiel konnte nicht erstellt werden.';

  @override
  String get joinWithInviteLink => 'Per Einladungslink beitreten';

  @override
  String get couldNotLoadGames => 'Deine Spiele konnten nicht geladen werden.';

  @override
  String get noGamesYet => 'Noch keine Spiele';

  @override
  String get noGamesYetText =>
      'Bau dein erstes Quiz oder lass dich von Freunden zu ihrem einladen.';

  @override
  String get unnamed => 'Ohne Namen';

  @override
  String get couldNotUploadPicture => 'Bild konnte nicht hochgeladen werden.';

  @override
  String get map => 'Spielplan';

  @override
  String get groupNotAvailable => 'Diese Gruppe gibt es nicht mehr.';

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
  String get hideOne => 'Eins zudecken';

  @override
  String revealedOf(int revealed, int steps) {
    return '$revealed von $steps aufgedeckt';
  }

  @override
  String get revealNext => 'Nächstes aufdecken';

  @override
  String get boardColours => 'Board-Farben';

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
  String get teamsCanLockIn => 'Teams dürfen früher einloggen';

  @override
  String get lockInOnText =>
      'Einloggen stoppt die Zeit des Teams; die gebrauchte Zeit wird gemerkt. Nur bei Wertung nach Reihenfolge, Schnellste zuerst';

  @override
  String get lockInOffText =>
      'Jede Antwort zählt so, wie sie ist, wenn die Zeit um ist oder du die Runde beendest';

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
  String get gameNotAvailable => 'Dieses Spiel gibt es nicht mehr.';

  @override
  String get copiedGame => 'Spiel mit Antworten kopiert.';

  @override
  String get renameGame => 'Spiel umbenennen';

  @override
  String get deleteGame => 'Spiel löschen';

  @override
  String deleteGameText(String name) {
    return '„$name“ und alle Fragen darin werden für alle gelöscht.';
  }

  @override
  String get leaveGame => 'Spiel verlassen';

  @override
  String leaveGameText(String name) {
    return 'Du hast keinen Zugriff mehr auf „$name“, bis dich jemand wieder einlädt.';
  }

  @override
  String get leave => 'Verlassen';

  @override
  String get musicAndSounds => 'Musik & Sounds';

  @override
  String get noneYet => 'Noch keine';

  @override
  String get soundsForGame => 'Sounds fürs ganze Spiel';

  @override
  String get cards => 'Karten';

  @override
  String get cardsForGame => 'Karten fürs ganze Spiel';

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
      'Hier ist noch nichts. Frag einen Admin, ob er eine Kategorie mit dir teilt.';

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
  String get shownOnBoard => 'Steht auf dem Board';

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
  String get usesGames => 'Vom Spiel';

  @override
  String get soundsForBoard => 'Sounds für dieses Board';

  @override
  String get onlyGames => 'Nur vom Spiel';

  @override
  String get cardsForBoard => 'Karten für dieses Board';

  @override
  String get colours => 'Farben';

  @override
  String get appsColours => 'App-Farben';

  @override
  String get ownColours => 'Eigene Farben';

  @override
  String get boardsColours => 'Farben vom Board';

  @override
  String get useBoardsColours => 'Farben vom Board verwenden';

  @override
  String get textOnBoard => 'Text auf dem Board';

  @override
  String get splitPointFields => 'Punktefelder teilen';

  @override
  String get splitPointFieldsText =>
      'Wenn ein Wert in einem Ring öfter vorkommt';

  @override
  String get arrangeMap => 'Spielplan anordnen';

  @override
  String get arrangeMapShort => 'Blasen, Pfeile, Titel, Bilder und Linien';

  @override
  String get arrangeMapLong =>
      'Blasen setzen und verbinden, Titel, Bilder und Linien hinzufügen';

  @override
  String get labelsInsteadOfPoints => 'Beschriftungen statt Punkte';

  @override
  String get labelsInsteadOfPointsText =>
      'Fragen ohne Beschriftung zeigen weiter ihre Punkte';

  @override
  String get deleteBoard => 'Board löschen';

  @override
  String get deleteBoardFirst => 'Verschieb oder lösch zuerst die Kategorien';

  @override
  String get ungroupedCategories => 'Kategorien ohne Gruppe';

  @override
  String get boardSettings => 'Board-Einstellungen';

  @override
  String get moveBoard => 'Board verschieben';

  @override
  String get addCategory => 'Kategorie hinzufügen';

  @override
  String get moveToAnotherBoard => 'Auf anderes Board verschieben';

  @override
  String comesAfterTitle(String name) {
    return '„$name“ kommt nach';
  }

  @override
  String get categoryBeforeIt => 'Die Kategorie davor (Standard)';

  @override
  String get startsNewChain => 'Keine: Sie startet eine neue Kette';

  @override
  String get deleteCategory => 'Kategorie löschen';

  @override
  String deleteCategoryText(String name, int count) {
    return '„$name“ und ihre $count Fragen werden gelöscht.';
  }

  @override
  String get inPlayTip => 'Im Spiel: Tippen nimmt sie raus';

  @override
  String get notInPlayTip => 'Nicht im Spiel: Tippen holt sie zurück';

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
  String get moveToAnotherBoardMenu => 'Auf anderes Board …';

  @override
  String get comesAfterMenu => 'Kommt nach …';

  @override
  String get renameCategory => 'Kategorie umbenennen';

  @override
  String get shareCategory => 'Kategorie teilen';

  @override
  String get shareCategoryText =>
      'Mitglieder mit eingeschränktem Zugriff sehen nur die Kategorien, die hier an sind.';

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
  String get categoryNotAvailable => 'Diese Kategorie gibt es nicht mehr.';

  @override
  String get addQuestion => 'Frage hinzufügen';

  @override
  String get usesBoards => 'Vom Board';

  @override
  String get soundsForCategory => 'Sounds für diese Kategorie';

  @override
  String get onlyBoardsAndGames => 'Nur von Board und Spiel';

  @override
  String get cardsForCategory => 'Karten für diese Kategorie';

  @override
  String get share => 'Teilen';

  @override
  String get noQuestionsYet => 'Noch keine Fragen.';

  @override
  String get couldNotSave => 'Speichern hat nicht geklappt.';

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
    return 'Teams setzen ihre Punkte · bis $limit immer möglich';
  }

  @override
  String get betOnHowMany => 'Wetten, wie viele';

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
      'Das erste Team bekommt die meisten Punkte, jedes weitere etwas weniger. Die Reihenfolge ergibt sich daraus, wann die Teams eine richtige Antwort eingeloggt haben, oder wie du sie antippst, z. B. wenn sie auf der Bühne fertig werden. Falsche Antworten kosten die Minuspunkte.';

  @override
  String scoringPointsText(int limit) {
    return 'Vor der Frage setzt jedes Team einen Teil seiner Punkte: Richtig gewinnt den Einsatz, falsch verliert ihn. Gesetzt werden darf bis zum eigenen Punktestand oder bis $limit, wenn das Team weniger hat.';
  }

  @override
  String get scoringAmountText =>
      'Zuerst kommt nur die Wettfrage, und jedes Team sagt, wie viele es schafft. Dann läuft die Frage, und du entscheidest pro Team, ob es seine Zahl geschafft hat. Geschafft: die Punkte für jedes. Verfehlt: die Minuspunkte für jedes.';

  @override
  String get betQuestion => 'Wettfrage';

  @override
  String get betQuestionHint =>
      'Wie viele Science-Fiction-Filme könnt ihr nennen?';

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
    return '$points auf dem Board';
  }

  @override
  String get eachMinus => 'Je −';

  @override
  String get ifWrongMinus => 'Falsch −';

  @override
  String get lessPerPlace => 'Minus pro Platz';

  @override
  String get pointsByPlace => 'Punkte pro Platz';

  @override
  String get pointsByPlaceHint => 'z. B. 400, 200, 100, 100 – statt der Regel';

  @override
  String get byTimeTitle => 'Nach Zeit';

  @override
  String get byTimeText =>
      'Das schnellste richtige Team bekommt die Punkte für Platz 1, die anderen einen Anteil danach, wie lange sie gebraucht haben: doppelt so lange, halbe Punkte. Teams knapp hintereinander bekommen fast gleich viel. Geht nur mit den Geräten der Teams; Teams, die du von Hand in Reihenfolge bringst, zählen nach Platz.';

  @override
  String get winnerTakesAll => 'Sieger bekommt alles';

  @override
  String get betOwnPoints => 'Höchstens die eigenen Punkte';

  @override
  String get betOwnPointsText =>
      'Ein Team kann alles setzen, was es hat, aber nicht mehr; ein Team ohne Punkte setzt nichts.';

  @override
  String get standingIntro =>
      'Auf dem großen Bildschirm steht nur die Frage: lies sie vor, dann geht\'s mit dem ersten Team los.';

  @override
  String get startTurns => 'Runde starten';

  @override
  String get byPlaces => 'Nach Plätzen';

  @override
  String get standingPlacesText =>
      'Der Sieger bekommt die Punkte für Platz 1, danach die Teams in umgekehrter Reihenfolge, in der sie rausgeflogen sind.';

  @override
  String get highestBet => 'Höchster Einsatz';

  @override
  String get musicAndEffects => 'Musik & Effekte';

  @override
  String get theCategorys => 'Von der Kategorie';

  @override
  String get soundsForQuestion => 'Sounds für diese Frage';

  @override
  String get type => 'Typ';

  @override
  String get question => 'Frage';

  @override
  String get answerHint => 'Hinweis zur Antwort';

  @override
  String get onlyGamemasterSees => 'Nur die Spielleitung sieht das';

  @override
  String get label => 'Beschriftung';

  @override
  String get labelHelper => 'Kleines Badge auf der Fragenkarte';

  @override
  String get labelTooltip => 'Ein kleines Badge auf der Fragenkarte';

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
      'Die einfachste Frage: keine Antwortoptionen, nichts zum Aufdecken. Unter „Wie Teams antworten“ kannst du die Buzzer ausschalten, z. B. für Schätzfragen.';

  @override
  String get explainAbcd =>
      'Zeigt richtige und falsche Antworten, die die Spielleitung nach und nach aufdeckt.';

  @override
  String get explainProgressingReveal =>
      'Die Spielleitung deckt Stück für Stück mehr Hinweise auf.';

  @override
  String get explainFeud =>
      'Duell um eine Umfrage: Das Team, das gebuzzert hat, deckt Antworten auf, bis es drei Fehler hat. Dann darf das andere Team alle Punkte klauen.';

  @override
  String get explainTopAnswers =>
      'Die beliebtesten Antworten finden: Teams nennen Antworten von einer Liste, per Buzzer oder auf ihren Geräten, und kassieren die Punkte jeder Antwort.';

  @override
  String get explainConnections =>
      'Sechzehn Wörter, vier Vierergruppen. Jedes Team rätselt auf seinem Gerät; jede gefundene Gruppe bringt ein Viertel der Punkte.';

  @override
  String get explainRapidFire =>
      'Fragenhagel: viele kurze Fragen Schlag auf Schlag. Teams buzzern, tippen auf ihren Geräten richtig oder falsch oder antworten auf einem Whiteboard; jede Frage kann ein Bild und einen Sound haben.';

  @override
  String get explainMatching =>
      'Zuordnen: Paare aus Texten oder Bildern, z. B. Filme und ihre Jahre. Jedes Team setzt sie auf seinem Gerät wieder zusammen; der große Bildschirm zeigt die Bilder.';

  @override
  String get explainLastStanding =>
      'Wer bleibt übrig: Pro Team ist abwechselnd ein Spieler dran, nennt z. B. Filme oder sagt, ob es zu einem Star ein Biopic gibt. Wer falsch liegt, fliegt raus; das letzte Team kassiert die Punkte.';

  @override
  String get explainUnsupported =>
      'Diesen Fragetyp kennt diese App-Version noch nicht.';

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
    return '$_temp0: Gemeinsamkeit';
  }

  @override
  String wordN(int n) {
    return 'Wort $n';
  }

  @override
  String get connectionsReady =>
      'Fertig. Gelb sollte die leichteste Gruppe sein, Lila die schwerste.';

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
      'Kleine Bilder unter der Frage, „?“ für noch verdeckte';

  @override
  String get teamsBuzz => 'Teams buzzern';

  @override
  String get onTheDevicesShort => 'Auf den Geräten';

  @override
  String get rightOrWrongShort => 'Richtig/falsch';

  @override
  String get whiteboardShort => 'Whiteboard';

  @override
  String get progressOnBigScreen => 'Fortschritt auf dem großen Bildschirm';

  @override
  String get rapidDevicesText =>
      'Jede Frage ist eine Aussage. Jedes Team tippt auf seinem Gerät richtig oder falsch; sobald du weitermachst, gibt\'s für richtige Tipps die Punkte.';

  @override
  String get rapidWhiteboardText =>
      'Jedes Team schreibt oder malt seine Antwort zu jeder Frage auf ein Whiteboard auf seinem Gerät. Bewerte jede richtig oder falsch; sobald du weitermachst, gibt\'s die Punkte.';

  @override
  String get rapidBuzzText =>
      'Teams buzzern bei jeder Frage. Bei einer richtigen Antwort gibt\'s die Punkte und es geht direkt weiter.';

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
      'Pro Team ist abwechselnd ein Spieler dran. Du bewertest jeden Zug: richtig, falsch (Team fliegt raus) oder falsch, bleibt aber drin. Das letzte Team kassiert die Punkte.';

  @override
  String get noPrompts =>
      'Keine Vorgaben: Jeder Zug beantwortet einfach die Frage.';

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
      'Geht nur mit eigenen Geräten: Jedes Team braucht ein verbundenes Handy oder Tablet (Setup → Geräte verbinden). Ohne Geräte kann niemand antworten.';

  @override
  String get matchingEditorText =>
      'Schreib jedes Paar so, wie es zusammengehört; die Teams bekommen die rechte Seite gemischt. Eine Seite kann Text, Bild oder beides sein. Ein Bild ohne Text bekommt auf den Geräten einen Namen wie „Bild 3“.';

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
      'Ein Team buzzert und nennt eine Antwort. Tipp sie an: Sie wird aufgedeckt und das Team bekommt die Punkte. Dann dürfen alle wieder buzzern.';

  @override
  String get topAnswersTypedText =>
      'Jedes Team tippt seine Antworten in eine Liste auf seinem Gerät. Du hakst ab, was es gefunden hat, mit Vorschlägen passend zum Getippten.';

  @override
  String get topAnswersWhiteboardText =>
      'Jedes Team schreibt seine Antworten auf ein nummeriertes Whiteboard. Du hakst ab, was es gefunden hat.';

  @override
  String get topAnswersListText =>
      'Beliebteste zuerst. Ohne eigene Punkte zählt eine Antwort so viel wie die Frage. Andere erlaubte Schreibweisen nach einem /.';

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
      'Jedes Team löst das Rätsel auf seinem Gerät. Du siehst live, welche Gruppen jedes Team schon hat.';

  @override
  String get chooseDeviceScreenText =>
      'Wähl, was sich mit der Frage auf den Geräten der Teams öffnet. Du siehst die Antworten live und entscheidest, wann sie gezeigt werden.';

  @override
  String get deviceScreenText =>
      'Öffnet sich mit der Frage auf den Geräten der Teams. Du siehst die Antworten live und entscheidest, wann sie gezeigt werden.';

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
  String get choosePictureToDrawOn => 'Bild zum Draufmalen wählen';

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
  String get rightWithin => 'Richtig bei ±';

  @override
  String get noBuzzingAtAll => 'Ganz ohne Buzzer';

  @override
  String get noBuzzingAtAllText =>
      'Auch Buzzer-Boxen bleiben aus, z. B. bei Schätzfragen';

  @override
  String get teamsCanStopEarly => 'Teams dürfen früher aufhören';

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
  String get outLoudNoBuzzer => 'Laut sagen, ohne Buzzer';

  @override
  String get buzzerBoxesOnly => 'Nur Buzzer-Boxen';

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
    return '$count sortieren';
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
  String get keepOutOfShow => 'Nicht in der Show zeigen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get cardsDialogText =>
      'Was du während der Show über den Bildschirm legen kannst, in dieser Reihenfolge. Tipp eine Karte an, um sie zu bearbeiten, zieh sie am Griff, um sie zu verschieben, oder schalte sie aus, um sie wegzulassen.';

  @override
  String get newCard => 'Neue Karte';

  @override
  String get uploading => 'Lädt hoch …';

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
      'Der Clip läuft im Vollbild auf dem großen Bildschirm; danach verschwindet die Karte.';

  @override
  String get look => 'Aussehen';

  @override
  String get removeCard => 'Karte entfernen';

  @override
  String get add => 'Hinzufügen';

  @override
  String get boardMusic => 'Board-Musik';

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
  String get effectQuestionOpens => 'Frage startet';

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
  String get effectFullySolved => 'Komplett gelöst';

  @override
  String appDefault(String sound) {
    return 'Standard: $sound';
  }

  @override
  String get asSetAbove => 'Wie oben';

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
      'Was in diesem Spiel läuft. Was du nicht einstellst, kommt aus den Sounds der App.';

  @override
  String get soundsLevelText =>
      'Alles auf „Wie oben“ kommt vom Board oder vom Spiel.';

  @override
  String get soundsAtMoments => 'Sounds für bestimmte Momente';

  @override
  String get ownEffects => 'Eigene Effekte';

  @override
  String get addEffect => 'Effekt hinzufügen';

  @override
  String get oggNotSupported =>
      'Ogg läuft unter Windows nicht. Nimm lieber MP3, WAV oder M4A.';

  @override
  String get fileTypeNotSupported => 'Dieser Dateityp geht leider nicht.';

  @override
  String couldNotUploadMedia(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'image': 'Bild konnte nicht hochgeladen werden.',
      'audio': 'Sound konnte nicht hochgeladen werden.',
      'other': 'Video konnte nicht hochgeladen werden.',
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
      'page': 'Seite konnte nicht geladen werden ($status).',
      'noList': 'Auf der Seite ist keine Liste.',
      'list': 'Liste konnte nicht geladen werden ($status).',
      'items': 'Einträge konnten nicht geladen werden ($status).',
      'other': 'Die Liste hat zu wenig Einträge.',
    });
    return '$_temp0';
  }

  @override
  String get importFailed => 'Import hat nicht geklappt.';

  @override
  String get rankerImportText =>
      'Die Top 10 der Liste ersetzen die Antworten dieser Frage.';

  @override
  String get rankerListUrl => 'Ranker-URL';

  @override
  String get import => 'Importieren';

  @override
  String get addTitle => 'Titel hinzufügen';

  @override
  String get arrowCircle => 'Dieser Pfeil würde im Kreis laufen.';

  @override
  String screensWide(String count) {
    return '$count Bildschirme breit';
  }

  @override
  String get mapTapFirst => 'Tipp die Blase an, die zuerst kommt.';

  @override
  String get mapTapNext =>
      'Jetzt die Blase antippen, zu der es weitergeht: Das setzt einen Pfeil oder entfernt den vorhandenen. Tippst du dieselbe Blase noch mal, verschwinden alle Pfeile zu ihr.';

  @override
  String get mapDragBubble =>
      'Ziehen zum Verschieben. Mit − und + unten änderst du die Größe.';

  @override
  String get mapDragSelected =>
      'Ziehen zum Verschieben. Mit den Buttons unten bearbeiten oder entfernen.';

  @override
  String get mapDragAnything =>
      'Zieh Sachen dahin, wo sie hinsollen. Tipp eine Blase, einen Titel, ein Bild oder eine Linie an, um sie auszuwählen.';

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
      'Einladungslink konnte nicht erstellt werden.';

  @override
  String get inviteLinkCopied => 'Einladungslink kopiert';

  @override
  String get removeFromGame => 'Aus dem Spiel entfernen';

  @override
  String get removeFromGameText =>
      'Der Zugriff endet sofort. Widerruf noch offene Einladungslinks, sonst kann die Person wieder beitreten.';

  @override
  String get access => 'Zugriff';

  @override
  String get members => 'Mitglieder';

  @override
  String get you => 'Du';

  @override
  String get accessExplanation =>
      'Mit vollem Zugriff kann man alles bearbeiten. Mit eingeschränktem Zugriff sieht man nur eigene oder geteilte Kategorien: So kann man Fragen schreiben und trotzdem mitspielen.';

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
      'full': 'Neuer Link: voller Zugriff',
      'other': 'Neuer Link: eingeschränkt',
    });
    return '$_temp0';
  }

  @override
  String get inviteLinksText =>
      'Wer den Link hat, kann beitreten, bis er abläuft oder du ihn widerrufst.';

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
      'Einladungslink konnte nicht geprüft werden.';

  @override
  String get couldNotJoinGame =>
      'Beitreten hat nicht geklappt. Vielleicht bist du schon drin oder der Link wurde widerrufen.';

  @override
  String get joinAGame => 'Spiel beitreten';

  @override
  String get inviteLink => 'Einladungslink';

  @override
  String get unnamedGame => 'Spiel ohne Namen';

  @override
  String youWillJoinWith(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'admin': 'Du trittst als Admin bei.',
      'full': 'Du bekommst vollen Zugriff.',
      'other': 'Du bekommst eingeschränkten Zugriff.',
    });
    return '$_temp0';
  }

  @override
  String get continueLabel => 'Weiter';

  @override
  String get join => 'Beitreten';

  @override
  String get couldNotCreateSession => 'Session konnte nicht erstellt werden.';

  @override
  String get presentHere => 'Hier präsentieren';

  @override
  String get presentHereText =>
      'Diese Session lief zuletzt auf einem anderen deiner Geräte. Dort wird sie beendet, falls sie noch läuft.';

  @override
  String get deleteSession => 'Session löschen';

  @override
  String deleteSessionText(String game) {
    return 'Die Session von „$game“ wird samt Teams und Punkten gelöscht.';
  }

  @override
  String get joinSessionScan => 'Session beitreten: Code scannen';

  @override
  String get joinSessionLink => 'Session per Link beitreten';

  @override
  String get newSession => 'Neue Session';

  @override
  String get couldNotLoadSessions =>
      'Deine Sessions konnten nicht geladen werden.';

  @override
  String get noSessionsText =>
      'Eine Session ist die Show eines Abends mit Teams, Punkten und Spielstand. Erstell eine, zeig sie auf dem großen Bildschirm und steuer sie vom Handy.';

  @override
  String get changeGame => 'Spiel ändern';

  @override
  String createdAt(String date) {
    return 'Erstellt am $date';
  }

  @override
  String get present => 'Präsentieren';

  @override
  String get control => 'Steuern';

  @override
  String get setUpTeamsAndBuzzers => 'Teams und Buzzer einrichten';

  @override
  String get chooseAGame => 'Spiel wählen';

  @override
  String get gameYouCannotOpen => 'Ein Spiel ohne Zugriff';

  @override
  String get noGamesForSession =>
      'Du hast noch keine Spiele. Erstell zuerst eins unter „Spiele“.';

  @override
  String get game => 'Spiel';

  @override
  String get createWithoutGame => 'Ohne Spiel erstellen';

  @override
  String get create => 'Erstellen';

  @override
  String get didNotReachPresenter =>
      'Das ist beim Präsentations-Gerät nicht angekommen.';

  @override
  String get noDevicePresenting =>
      'Kein Gerät zeigt diese Session gerade. Was du hier machst, passiert erst, wenn eins sie zeigt.';

  @override
  String get presentingElsewhere => 'Läuft woanders';

  @override
  String get presentingElsewhereText =>
      'Ein anderes deiner Geräte hat die Session übernommen.';

  @override
  String get couldNotOpenWindow =>
      'Zweites Fenster konnte nicht geöffnet werden.';

  @override
  String get couldNotStartPresenting =>
      'Session konnte nicht gestartet werden.';

  @override
  String get controlling => 'Steuerung';

  @override
  String get closePresenterWindow => 'Präsentationsfenster schließen';

  @override
  String get stopPresenting => 'Präsentation beenden';

  @override
  String get openInNewWindow =>
      'In neuem Fenster öffnen, z. B. für einen zweiten Bildschirm';

  @override
  String get fullscreen => 'Vollbild';

  @override
  String get controls => 'Steuerung';

  @override
  String get buzzerBoxRetrying =>
      'Buzzer-Box nicht verbunden · neuer Versuch …';

  @override
  String mediaNotDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mediendateien fehlen',
      one: '1 Mediendatei fehlt',
    );
    return '$_temp0';
  }

  @override
  String get couldNotSaveChange => 'Änderung konnte nicht gespeichert werden.';

  @override
  String setUpTitle(String title) {
    return '$title einrichten';
  }

  @override
  String get couldNotLoadSession => 'Session konnte nicht geladen werden.';

  @override
  String get setUpFromControl =>
      'Läuft diese Session gerade auf einem Bildschirm, richte sie lieber über „Steuern“ ein: Das präsentierende Gerät behält seine eigenen Teams.';

  @override
  String get teams => 'Teams';

  @override
  String get noTeamsYet => 'Noch keine Teams';

  @override
  String get queueBuzzers => 'Buzzer-Warteschlange';

  @override
  String get queueBuzzersText => 'Spätere Buzzer stellen sich hinten an';

  @override
  String get buzzerTest => 'Buzzer-Test';

  @override
  String get buzzerTestText =>
      'Buzzer lassen ihr Team aufleuchten; nur am Board';

  @override
  String get buzzerBoxAndSounds => 'Buzzer-Box und Team-Sounds';

  @override
  String get buzzerBoxAndSoundsText =>
      'Die USB-Buzzer-Box und der Buzzer-Sound jedes Teams';

  @override
  String get connectDevices => 'Geräte verbinden';

  @override
  String get connectDevicesText =>
      'Handys als Buzzer oder eine zweite Steuerung';

  @override
  String get newTeam => 'Neues Team';

  @override
  String get renameTeam => 'Team umbenennen';

  @override
  String get removeTeam => 'Team entfernen';

  @override
  String removeTeamText(String team) {
    return '„$team“ wird samt Punkten entfernt.';
  }

  @override
  String get addTeam => 'Team hinzufügen';

  @override
  String get noTeamsYetText =>
      'Noch keine Teams. Füg sie hier hinzu oder lass sie per Code beitreten.';

  @override
  String get couldNotCreateCodes => 'Codes konnten nicht erstellt werden.';

  @override
  String get controller => 'Steuerung';

  @override
  String get scanToControl =>
      'In Quiz Studio scannen, um diese Session von einem anderen Gerät zu steuern. Dort muss ein Konto angemeldet sein, das das Spiel öffnen darf.';

  @override
  String scanToBuzz(String team) {
    return 'In Quiz Studio scannen, um ein Handy als Buzzer für $team zu nutzen.';
  }

  @override
  String get devicesViaInternet => 'Geräte verbinden sich übers Internet.';

  @override
  String get devicesViaLan =>
      'Geräte im selben WLAN verbinden sich direkt, alle anderen übers Internet.';

  @override
  String get linkCopied => 'Link kopiert';

  @override
  String get copyLinkInstead => 'Stattdessen Link kopieren';

  @override
  String get addTeamsFirst =>
      'Füg zuerst Teams hinzu, dann gibt\'s für jedes einen Buzzer-Code.';

  @override
  String get teamRemoved => 'Dieses Team wurde entfernt.';

  @override
  String get buzzForTeam => 'Für dieses Team buzzern';

  @override
  String get setPoints => 'Punkte setzen';

  @override
  String get sessionHasNoGame => 'Diese Session hat noch kein Spiel.';

  @override
  String get statusBoard => 'Board';

  @override
  String get statusBetsShown =>
      'Einsätze sind auf dem großen Bildschirm · starte die Frage, wenn alle bereit sind';

  @override
  String statusBetting(int placed, int total) {
    return 'Teams setzen · $placed von $total da';
  }

  @override
  String get statusRapidDevices => 'Teams tippen richtig oder falsch';

  @override
  String get statusRapidWhiteboard =>
      'Teams antworten auf ihren Whiteboards · bewerte jede Antwort';

  @override
  String get statusAmountBet => 'Teams spielen auf ihre gewettete Zahl';

  @override
  String get statusOpenNoBuzzers => 'Frage offen · ohne Buzzer';

  @override
  String get statusOpenWaiting => 'Frage offen · wartet auf Buzzer';

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
      'Noch kein Spiel gewählt. Wähl eins in der Session-Liste.';

  @override
  String get groupHasNoQuestions => 'Diese Gruppe hat keine Fragen.';

  @override
  String questionsPlayed(int played, int total) {
    return '$played/$total Fragen gespielt';
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
      'Erst muss ein Team buzzern, dann kannst du Antworten aufdecken.';

  @override
  String betFor(String team) {
    return 'Einsatz: $team';
  }

  @override
  String betRange(int limit) {
    return '0 bis $limit Punkte';
  }

  @override
  String get betsTapTeam =>
      'Einsätze · tipp ein Team an, um den Einsatz einzutragen';

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
    return 'Punkte an $count Teams';
  }

  @override
  String get given => 'Vergeben';

  @override
  String get notGivenYet => 'Noch offen';

  @override
  String givenSoFar(String points) {
    return 'Bisher $points';
  }

  @override
  String get takeOutOfOrder => 'Aus Reihenfolge nehmen';

  @override
  String get putNextInOrder => 'Als Nächstes einreihen';

  @override
  String pointsFor(String team) {
    return 'Punkte für $team';
  }

  @override
  String get pointsForQuestion => 'Punkte für die Frage';

  @override
  String get didTeamsReach => 'Hat jedes Team seine Zahl geschafft?';

  @override
  String tapInOrder(String points, int step) {
    return 'Tipp die Teams an, wie sie fertig werden · $points, dann je $step weniger';
  }

  @override
  String get rateEachTeam => 'Jedes Team bewerten';

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
  String get pointsForAnswer => 'Punkte für die Antwort';

  @override
  String teamWins(String team, int points) {
    return '$team gewinnt · +$points';
  }

  @override
  String teamsTurn(String team) {
    return '$team ist dran';
  }

  @override
  String get nobodyLeft => 'Keiner mehr übrig';

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
    return 'Alle $count durch';
  }

  @override
  String itemOf(int item, int count) {
    return 'Frage $item von $count';
  }

  @override
  String get topAnswersEmpty =>
      'Diese Frage hat noch keine Antworten auf der Liste.';

  @override
  String get topTapToUncover =>
      'Tipp eine Antwort an, um sie auf dem großen Bildschirm aufzudecken.';

  @override
  String topTapNamed(String team) {
    return 'Tipp die Antwort an, die $team genannt hat. Steht sie nicht drauf: falsch.';
  }

  @override
  String get topWhenBuzz =>
      'Wenn ein Team buzzert, tipp die genannte Antwort an.';

  @override
  String get revealGroupNow => 'Jetzt eine Gruppe aufdecken?';

  @override
  String get revealGroupNowText =>
      'Die Teams spielen noch und sehen die Gruppe dann auch auf ihren Geräten. Ihre Zeit läuft weiter.';

  @override
  String get reveal => 'Aufdecken';

  @override
  String get stealWorked => 'Klauen geklappt';

  @override
  String get stealFailed => 'Klauen fehlgeschlagen';

  @override
  String get strike => 'Fehler';

  @override
  String get hide => 'Ausblenden';

  @override
  String get betsAreIn => 'Einsätze sind da';

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
  String get tabBoard => 'Board';

  @override
  String get tabEffects => 'Effekte';

  @override
  String get tabAnswers => 'Antworten';

  @override
  String get tabSetup => 'Setup';

  @override
  String get ungrouped => 'Ohne Gruppe';

  @override
  String get groupHasNoCategories => 'Diese Gruppe hat keine Kategorien.';

  @override
  String get showCategoryInMiddle => 'Kategorie in der Mitte zeigen';

  @override
  String get tapFieldToRead => 'Tipp ein Feld an, um die Frage zu lesen.';

  @override
  String get onScreen => 'auf dem Bildschirm';

  @override
  String get played => 'gespielt';

  @override
  String get takeOffKeepPlayable => 'Ausblenden, bleibt spielbar';

  @override
  String get markNotPlayed => 'Als ungespielt markieren';

  @override
  String get openQuestion => 'Frage öffnen';

  @override
  String get slotBoard => 'Board';

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
  String get noCardsPrepare => 'Keine Karten. Leg im Editor welche an.';

  @override
  String get textToShow => 'Anzeigetext';

  @override
  String get show => 'Zeigen';

  @override
  String get noCardOnScreen => 'Keine Karte sichtbar';

  @override
  String get takeCardOff => 'Karte ausblenden';

  @override
  String get keepSpeakersAwake => 'Lautsprecher wach halten';

  @override
  String get fewerDetails => 'Weniger Details';

  @override
  String get whatIsThis => 'Was ist das?';

  @override
  String get keepSpeakersAwakeText =>
      'Viele Lautsprecher gehen nach ein paar Minuten Stille aus und verschlucken dann den Anfang des nächsten Sounds. Hiermit läuft ein ganz leises Rauschen, wenn sonst nichts spielt; Musik und Sounds übernehmen, sobald sie starten.';

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
  String get questionSound => 'Fragen-Sound';

  @override
  String get answersOnDevices => 'Antworten auf den Geräten';

  @override
  String get openAQuestionFirst => 'Öffne zuerst eine Frage.';

  @override
  String get answersOnDevicesText =>
      'Jedes Team antwortet auf seinem Gerät. Du siehst die Antworten sofort, das Publikum erst, wenn du sie zeigst.';

  @override
  String get preparedScreensText =>
      'Slider, Sortieren, Zuordnen und vorbereitete Whiteboards stellst du pro Frage im Editor ein; sie starten von selbst.';

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
  String get letThemEditAgain => 'Wieder freigeben';

  @override
  String get showAll => 'Alle zeigen';

  @override
  String get rateAutomatically => 'Automatisch bewerten';

  @override
  String get givePointsForGroups => 'Punkte für Gruppen';

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
  String get takeOffScreen => 'Ausblenden';

  @override
  String get showOnScreen => 'Einblenden';

  @override
  String halfPoints(int points) {
    return 'Halbe Punkte (+$points)';
  }

  @override
  String outPlaceLabel(String place) {
    return '$place raus';
  }

  @override
  String get waitingForGame => 'Warten auf ein Spiel …';

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
  String get betRule => 'Richtig: Einsatz gewonnen · falsch: Einsatz weg';

  @override
  String amountRuleWithMinus(int plus, int minus) {
    return 'Zahl geschafft: $plus Punkte für jedes · verfehlt: −$minus für jedes';
  }

  @override
  String amountRule(int plus) {
    return 'Zahl geschafft: $plus Punkte für jedes';
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
  String get customColour => 'Eigene Farbe';

  @override
  String get useThisColour => 'Diese Farbe verwenden';

  @override
  String get presenterWindowTitle => 'Quiz Studio · Präsentation';

  @override
  String get reconnectingMainWindow => 'Verbinde neu mit dem Hauptfenster …';

  @override
  String get connectingMainWindow => 'Verbinde mit dem Hauptfenster …';

  @override
  String get leaveFullScreen => 'Vollbild verlassen (Esc)';

  @override
  String get fullScreenF11 => 'Vollbild (F11)';

  @override
  String get dragToProjector =>
      'Zieh das Fenster auf den Beamer und doppelklick darauf oder drück F11 für Vollbild.';

  @override
  String pictureLabel(String label) {
    return 'Bild $label';
  }

  @override
  String get yourAnswer => 'Eure Antwort';

  @override
  String get slideToAnswer => 'Schieben zum Antworten';

  @override
  String get dragIntoOrder => 'In die richtige Reihenfolge ziehen';

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
    return 'Tippt jetzt, wohin „$item“ gehört';
  }

  @override
  String get allPlacedSwap => 'Alles zugeordnet · ziehen zum Tauschen';

  @override
  String get dragOntoPartner => 'Zieht jede Antwort auf ihren Partner';

  @override
  String get dropToTakeBack => 'Hier ablegen zum Zurücknehmen';

  @override
  String get allPlaced => 'Alles zugeordnet';

  @override
  String get praisePerfect => 'Perfekt!';

  @override
  String get praiseGreat => 'Super!';

  @override
  String get praiseNice => 'Gut!';

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
  String get alreadyGuessed => 'Hattet ihr schon';

  @override
  String get allFourGroupsFound => 'Alle vier Gruppen gefunden';

  @override
  String get noTriesLeftWait => 'Keine Versuche mehr. Wartet auf die Lösung';

  @override
  String lockedInWith(int count) {
    return 'Eingeloggt mit $count von 4';
  }

  @override
  String get timeIsUp => 'Zeit ist um';

  @override
  String get mistakesRemaining => 'Fehler übrig:';

  @override
  String get shuffle => 'Mischen';

  @override
  String get deselectAll => 'Alles abwählen';

  @override
  String get submit => 'Abschicken';

  @override
  String get wereDone => 'Wir sind fertig';

  @override
  String get clear => 'Löschen';

  @override
  String get notASessionCode => 'Das ist kein Quiz-Studio-Code.';

  @override
  String get couldNotJoinSession =>
      'Beitreten hat nicht geklappt. Vielleicht ist der Code abgelaufen.';

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
  String get rejoinAsTeam => 'Wieder als Team beitreten';

  @override
  String get rejoinAsController => 'Wieder als Steuerung beitreten';

  @override
  String joinedAgo(String ago) {
    return 'Beigetreten $ago';
  }

  @override
  String get joinLink => 'Beitrittslink';

  @override
  String get orPasteLink => 'Oder Link einfügen';

  @override
  String get joinTerms =>
      'Mit dem Beitreten stimmst du den Nutzungsbedingungen und der Datenschutzerklärung zu. Kein Konto, kein Name nötig.';

  @override
  String get joinASession => 'Session beitreten';

  @override
  String get pasteJoinLinkHelp =>
      'Öffne „Geräte verbinden“ auf dem präsentierenden Gerät, kopier dort den Beitrittslink und füg ihn hier ein.';

  @override
  String get didNotGetThrough => 'Das kam nicht an.';

  @override
  String get couldNotReachSession => 'Session nicht erreichbar.';

  @override
  String get waitingForShow => 'Gleich geht\'s los …';

  @override
  String get teamRemovedFromSession =>
      'Euer Team wurde aus der Session entfernt.';

  @override
  String get youAreLastTeam => 'Ihr seid als Letzte übrig!';

  @override
  String teamWinsShort(String team) {
    return '$team gewinnt';
  }

  @override
  String get youAreOut => 'Ihr seid raus';

  @override
  String get yourTurn => 'Ihr seid dran!';

  @override
  String get buzzerTestPress => 'Buzzer-Test: drückt mal';

  @override
  String get waitingForNextQuestion => 'Gleich kommt die nächste Frage';

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
  String get noBuzzersForQuestion => 'Diesmal ohne Buzzer';

  @override
  String numberInLine(int n) {
    return 'Ihr seid Nummer $n in der Reihe';
  }

  @override
  String get anotherTeam => 'Ein anderes Team';

  @override
  String get needsNewerVersion =>
      'Für diese Frage braucht ihr eine neuere Version von Quiz Studio. Bitte aktualisiert die App.';

  @override
  String get answerHere => 'Hier antworten';

  @override
  String get answerBeingShown => 'Eure Antwort wird gezeigt';

  @override
  String get lockedInWaiting => 'Eingeloggt, warten auf die anderen';

  @override
  String get answersAreIn => 'Alle Antworten sind da';

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
      'Eure Antwort zählt so, wie sie ist, wenn die Spielleitung die Runde beendet.';

  @override
  String get answerCountsWhenTimeUp =>
      'Eure Antwort zählt so, wie sie ist, wenn die Zeit um ist.';

  @override
  String get lockedIn => 'Eingeloggt';

  @override
  String lockedInAfter(String seconds) {
    return 'Eingeloggt nach $seconds s';
  }

  @override
  String get lockInAnswer => 'Einloggen';

  @override
  String get answerFirst => 'Erst antworten';

  @override
  String get answerOnBigScreen => 'Eure Antwort ist auf dem großen Bildschirm.';

  @override
  String get gettingPicture => 'Bild lädt …';

  @override
  String get connectedLan => 'Übers WLAN verbunden';

  @override
  String get connectedInternet => 'Übers Internet verbunden';

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
  String get allIn => 'All in';

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
      'Die Datei ist zu groß; ein Buzzer-Sound darf höchstens 5 MB haben.';

  @override
  String get notASoundFile => 'Diese Datei kann die App nicht abspielen.';

  @override
  String get couldNotUploadBuzzerSound =>
      'Sound konnte nicht hochgeladen werden. Das Team behält seinen alten.';

  @override
  String get buzzers => 'Buzzer';

  @override
  String get useUsbBox => 'USB-Buzzer-Box nutzen';

  @override
  String get useUsbBoxText =>
      'Aus: Teams buzzern nur per Handy, und der große Bildschirm sucht keine Box.';

  @override
  String get usbBoxPlatforms =>
      'Eine USB-Buzzer-Box geht unter Windows, macOS und Linux. Handys und Tablets gehen trotzdem als Buzzer: siehe „Geräte verbinden“.';

  @override
  String get buzzerSounds => 'Buzzer-Sounds';

  @override
  String get buzzerSoundsText =>
      'Wird mit der Session gespeichert und vom präsentierenden Gerät abgespielt. Solange es einen Sound noch nicht geladen hat, und bei Teams ohne eigenen, kommt der Standard-Buzzer.';

  @override
  String get ownSound => 'Eigener Sound';

  @override
  String get chooseBuzzerSound => 'Buzzer-Sound wählen';

  @override
  String get uploadOwnSound => 'Eigenen Sound hochladen …';

  @override
  String get choose => 'Wählen';

  @override
  String get backToBuiltinBuzzer => 'Zurück zum Standard-Buzzer';

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
      'Die Buzzer erscheinen hier, sobald die Box Werte schickt.';

  @override
  String get pressTheBuzzers =>
      'Drück die Buzzer. Jeder leuchtet, solange er gedrückt ist, und die Zahlen zeigen, wer zuerst war. Tipp einen an, um Team oder Empfindlichkeit zu ändern.';

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
      'Ohne Zuordnung gehört Buzzer 1 zum ersten Team, Buzzer 2 zum zweiten und so weiter.';

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
  String get rawDataText => 'Genau das, was die Box schickt, zur Fehlersuche';

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
    return 'Wert $value · gedrückt ab $threshold';
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
    return '$rate Werte/s · seit $uptime';
  }

  @override
  String reconnectedTimes(int count) {
    return '$count× neu verbunden';
  }

  @override
  String get boxSilent => 'Offen, aber die Box schickt nichts';

  @override
  String get boxSilentText =>
      'Neuer Versuch alle paar Sekunden. Richtiger Port? Hat die Box Strom?';

  @override
  String get notConnectedShort => 'Nicht verbunden';

  @override
  String get boxDisconnectedText =>
      'Neuer Versuch alle paar Sekunden. Steck die Box ein; hier musst du nichts drücken.';

  @override
  String get choosePort => 'Port der Buzzer-Box wählen';

  @override
  String get rememberedOnDevice => 'Wird auf diesem Gerät gemerkt.';

  @override
  String get noSerialPorts => 'Keine seriellen Ports gefunden';

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
      'Erst die Frage vorlesen, dann bringt Weiter Frage 1';

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
      'Das Team, dessen Zahl am nächsten am richtigen Wert liegt, bekommt die meisten Punkte, jeder weitere Platz etwas weniger. Gleich nahe Teams teilen sich einen Platz. Die Plätze zählen, sobald die Antworten gesperrt sind, und der große Bildschirm zeigt sie mit den Antworten.';

  @override
  String get scoringClosenessNoSolution =>
      'Die Plätze richten sich danach, wie nah jede Zahl an der Lösung ist. Gib dafür unter „Wie Teams antworten“ einen richtigen Wert an.';

  @override
  String placeN(String place) {
    return '$place Platz';
  }

  @override
  String get statusRapidIntro => 'Frage offen · erst vorlesen';

  @override
  String get pickSeveral => 'Mehrfachauswahl';

  @override
  String get pickSeveralText =>
      'Für Fragen mit mehreren richtigen Antworten: Richtig ist nur, wer genau die richtigen wählt';

  @override
  String get explainOrdering =>
      'Sortieren: Einträge wie Erfindungen, Filme oder Städte, die jedes Team auf seinem Gerät ordnet, z. B. nach Jahr. Der große Bildschirm zeigt sie gemischt und setzt sie dann einzeln an ihren Platz.';

  @override
  String get orderingEditorText =>
      'Schreib die Einträge in der richtigen Reihenfolge, vom ersten bis zum letzten; zum Umsortieren ziehen. Jeder kann Text, Bild oder beides sein, dazu das, wonach sortiert wird (ein Jahr, eine Größe). Das erscheint, sobald der Eintrag an seinem Platz landet.';

  @override
  String get orderEntry => 'Eintrag';

  @override
  String get orderValue => 'Sortiert nach (optional)';

  @override
  String get orderValueHint => 'z. B. 1969';

  @override
  String get removeEntry => 'Eintrag entfernen';

  @override
  String get addEntry => 'Eintrag hinzufügen';

  @override
  String get orderScoringTitle => 'Punkte für';

  @override
  String orderScoring(String rule) {
    String _temp0 = intl.Intl.selectLogic(rule, {
      'exact': 'Nur ganz richtig',
      'pairs': 'Pro Paar',
      'other': 'Pro Platz',
    });
    return '$_temp0';
  }

  @override
  String orderScoringText(String rule) {
    String _temp0 = intl.Intl.selectLogic(rule, {
      'exact': 'Alle Punkte nur für die exakte Reihenfolge, sonst keine.',
      'pairs':
          'Anteil für je zwei Einträge in der richtigen Reihenfolge. Ein verrutschter Eintrag kostet nur wenig.',
      'other': 'Anteil für jeden Eintrag am richtigen Platz.',
    });
    return '$_temp0';
  }

  @override
  String get rightOrder => 'Richtige Reihenfolge';

  @override
  String get placeNext => 'Nächster Platz';

  @override
  String partialPairs(int right, int total) {
    return '$right von $total Paaren richtig';
  }

  @override
  String get testOnThisComputer => 'Auf diesem Computer testen';

  @override
  String get testDevices => 'Testgeräte';

  @override
  String get bot => 'Bot';

  @override
  String get allBots => 'Alle als Bots';

  @override
  String get noBots => 'Keine Bots';

  @override
  String get whoAnswers => 'Wer antwortet';

  @override
  String get notes => 'Notizen';

  @override
  String get roundForOtherTeams => 'Diese Runde ist für andere Teams';

  @override
  String get nextPair => 'Nächstes Paar';

  @override
  String get moreTime => 'Mehr Zeit';

  @override
  String get noTimeLimit => 'Ohne Zeitlimit';

  @override
  String get stopTimer => 'Timer stoppen';

  @override
  String get notesText =>
      'Ausgewählte Teams bekommen ein Notizfeld auf ihren Geräten, zusätzlich zu ihrer Antwort, z. B. für eine Bonus-Schätzung. Du liest die Notizen hier.';
}
