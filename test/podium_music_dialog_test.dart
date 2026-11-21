import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/games/widgets/sounds_dialog.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/app_localizations.dart';

/// The podium's music is set with the game's music only, not per group or
/// category.
void main() {
  Future<List<Map<String, dynamic>>> pump(WidgetTester tester, {required bool isGame}) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final saved = <Map<String, dynamic>>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SoundsDialog(gameId: 'g', title: 'Sounds', data: const {}, save: saved.add, isGame: isGame)),
    ));
    await tester.pumpAndSettle();
    return saved;
  }

  testWidgets('the game has podium music, unset meaning the board music plays on', (tester) async {
    await pump(tester, isGame: true);
    final row = find.ancestor(of: find.text('Podium music'), matching: find.byType(DropdownButtonFormField<String>));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Board music')), findsOneWidget);
  });

  testWidgets('a group or category has none', (tester) async {
    await pump(tester, isGame: false);
    expect(find.text('Podium music'), findsNothing);
  });

  test('stored on the game, it is read like the other music and downloaded with the game', () {
    final config = MusicConfig.fromMap(const {'musicBackground': 'bg.mp3', 'musicPodium': 'podium.mp3'});
    expect(config.slots[musicPodium], 'podium.mp3');
    expect(config.mediaPaths, contains('podium.mp3'));
    expect(musicSlots, isNot(contains(musicPodium)), reason: 'not a slot the controller picks');
  });
}
