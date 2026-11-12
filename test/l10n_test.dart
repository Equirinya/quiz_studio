import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/settings/account_page.dart';
import 'package:quiz_show/game/content.dart';
import 'package:quiz_show/game/last_standing.dart';
import 'package:quiz_show/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _arb(String name) => jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

/// The placeholders a message uses at its top level, e.g. {team} or {count, plural, …}.
Set<String> _placeholders(String message) {
  final names = <String>{};
  var depth = 0;
  for (var i = 0; i < message.length; i++) {
    if (message[i] == '{') {
      if (depth == 0) {
        final match = RegExp(r'\{(\w+)').matchAsPrefix(message, i);
        if (match != null) names.add(match.group(1)!);
      }
      depth++;
    } else if (message[i] == '}') {
      depth--;
    }
  }
  return names;
}

Widget _app(Widget child, {Locale locale = const Locale('de')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  test('every text is in English and German, with the same placeholders', () {
    final en = _arb('app_en.arb');
    final de = _arb('app_de.arb');
    final enKeys = en.keys.where((key) => !key.startsWith('@')).toSet();
    final deKeys = de.keys.where((key) => !key.startsWith('@')).toSet();
    expect(deKeys.difference(enKeys), isEmpty, reason: 'only in German');
    expect(enKeys.difference(deKeys), isEmpty, reason: 'missing in German');
    for (final key in enKeys) {
      expect(_placeholders(de[key] as String), _placeholders(en[key] as String), reason: key);
      expect((de[key] as String).trim(), isNotEmpty, reason: key);
    }
  });

  test('names of the game\'s enums', () {
    final de = lookupAppLocalizations(const Locale('de'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(de.questionType(QuestionType.lastStanding), 'Wer bleibt übrig');
    expect(de.questionType(QuestionType.matching), 'Zuordnen');
    expect(en.questionType(QuestionType.free), QuestionType.free.uiString);
    for (final type in QuestionType.values) {
      expect(en.questionType(type), type.uiString);
    }
    for (final order in TurnOrder.values) {
      expect(en.turnOrder(order), order.uiString);
    }
    expect(de.ordinal(2), '2.');
    expect(en.ordinal(2), '2nd');
    expect(en.ordinal(11), '11th');
    expect(en.ordinal(23), '23rd');
    expect(de.deviceLabel('Picture B'), 'Bild B');
    expect(de.deviceLabel('Right'), 'Richtig');
    expect(de.deviceLabel('B · Paris'), 'B · Paris');
    expect(de.pointsCount(1), '1 Punkt');
    expect(en.pointsCount(3), '3 points');
    expect(de.teamsTurn('Rot'), 'Rot ist dran');
  });

  testWidgets('without localizations the texts are English', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          l10n = context.l10n;
          return const SizedBox();
        },
      ),
    );
    expect(l10n.localeName, 'en');
  });

  testWidgets('the account page in German', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _app(
        AccountView(
          username: 'Jacob',
          email: null,
          guest: true,
          version: '2.0.0',
          onRename: () {},
          onUpgrade: () {},
          onSignOut: () {},
        ),
      ),
    );
    expect(find.text('Gastkonto'), findsOneWidget);
    expect(find.text('E-Mail und Passwort hinzufügen'), findsOneWidget);
    expect(find.text('Abmelden'), findsOneWidget);
    expect(find.text('Sprache'), findsOneWidget);
    expect(find.text('Systemsprache'), findsOneWidget);
  });

  testWidgets('picking a language keeps it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => AppLanguage.locale.value = null);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: AppLanguage.locale,
        builder: (context, locale, _) => _app(const LanguageTile(), locale: locale ?? const Locale('en')),
      ),
    );
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.byType(LanguageTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(AppLanguage.locale.value, const Locale('de'));
    expect(find.text('Sprache'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('app_language'), 'de');

    AppLanguage.locale.value = null;
    await AppLanguage.load();
    expect(AppLanguage.locale.value, const Locale('de'));
  });
}
