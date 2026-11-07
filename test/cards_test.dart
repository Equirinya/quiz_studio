import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/games/widgets/cards_dialog.dart';
import 'package:quiz_show/features/session/pages/controller_page.dart';
import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/features/session/pages/screen_overlays.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

import 'game/fixture.dart';

void main() {
  group('built-in pictures', () {
    test('every one is shipped, and named so it cannot clash with game media', () {
      expect(builtinImages.map((i) => i.id).toSet(), hasLength(builtinImages.length));
      for (final image in builtinImages) {
        expect(File(image.asset).existsSync(), isTrue, reason: image.asset);
        expect(builtinImage(image.name), same(image));
        expect(isBuiltinImage(image.name), isTrue);
      }
      expect(builtinImage('builtin:unknown'), isNull);
      expect(builtinImage('correct.jpg'), isNull);
      expect(isBuiltinImage(null), isFalse);
    });

    test('a card with a built-in picture has nothing to download', () {
      final game = GameContent.assemble(
        id: 'g',
        game: {
          'cards': [
            {'title': '', 'image': 'builtin:correct'},
            {'title': '', 'image': 'own.png'},
          ],
        },
        groups: {},
        categories: {},
        questions: {},
      );
      expect(game.mediaPaths, {'own.png'});
    });
  });

  group('card animation', () {
    test('kept with the session until changed', () {
      final state = fixtureState();
      expect(state.cardAnimation, CardAnimation.fade);
      final next = reduce(state, const SetCardAnimation(CardAnimation.bounce), fixtureGame()).state;
      expect(next.cardAnimation, CardAnimation.bounce);
      expect(reduce(next, const SetCardAnimation(CardAnimation.bounce), fixtureGame()).accepted, isFalse);
      // Showing and hiding cards does not change it.
      final shown = reduce(next, const ShowCard(OverlayCard(image: 'builtin:wrong')), fixtureGame()).state;
      expect(reduce(shown, const HideCard(), fixtureGame()).state.cardAnimation, CardAnimation.bounce);
      final copy = SessionState.fromJson(jsonDecode(jsonEncode(next.toJson())) as Map<String, dynamic>);
      expect(copy.cardAnimation, CardAnimation.bounce);
      // A state saved before there was a choice fades, as cards always did.
      expect(SessionState.fromJson(state.toJson()..remove('cardAnimation')).cardAnimation, CardAnimation.fade);
      expect(CardAnimation.fromName('wobble'), CardAnimation.fade);
      final command = Command.fromJson(jsonDecode(jsonEncode(const SetCardAnimation(CardAnimation.slideDown).toJson())));
      expect((command as SetCardAnimation).animation, CardAnimation.slideDown);
      expect(mayIssue(const Sender(Role.player, teamId: 'red'), const SetCardAnimation(CardAnimation.off)), isFalse);
    });

    Future<void> overlay(WidgetTester tester, OverlayCard? card, CardAnimation animation) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CardOverlay(card: card, imageFile: (_) => null, animation: animation)),
      ));
    }

    const card = OverlayCard(title: 'Break', text: 'Back in ten');

    testWidgets('off: the card is there at once, and gone at once', (tester) async {
      await overlay(tester, null, CardAnimation.off);
      await overlay(tester, card, CardAnimation.off);
      await tester.pump();
      expect(find.text('Break'), findsOneWidget);
      expect(tester.getCenter(find.text('Break')).dy, lessThan(450));
      await overlay(tester, null, CardAnimation.off);
      await tester.pump();
      expect(find.text('Break'), findsNothing);
    });

    testWidgets('slide in from the bottom comes up from below, and settles in the middle', (tester) async {
      await overlay(tester, null, CardAnimation.slideUp);
      await overlay(tester, card, CardAnimation.slideUp);
      await tester.pump(const Duration(milliseconds: 60));
      final early = tester.getCenter(find.text('Break')).dy;
      await tester.pump(const Duration(milliseconds: 700));
      final settled = tester.getCenter(find.text('Break')).dy;
      expect(early, greaterThan(settled + 200));
    });

    testWidgets('slide in from the top comes down from above', (tester) async {
      await overlay(tester, null, CardAnimation.slideDown);
      await overlay(tester, card, CardAnimation.slideDown);
      await tester.pump(const Duration(milliseconds: 60));
      final early = tester.getCenter(find.text('Break')).dy;
      await tester.pump(const Duration(milliseconds: 700));
      expect(early, lessThan(tester.getCenter(find.text('Break')).dy - 200));
    });

    /// On screen, scaling included.
    double width(WidgetTester tester) =>
        tester.getBottomRight(find.text('Break')).dx - tester.getTopLeft(find.text('Break')).dx;

    testWidgets('bounce overshoots before it settles', (tester) async {
      await overlay(tester, null, CardAnimation.bounce);
      await overlay(tester, card, CardAnimation.bounce);
      var biggest = 0.0;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 33));
        biggest = [biggest, width(tester)].reduce((a, b) => a > b ? a : b);
      }
      final settled = width(tester);
      expect(biggest, greaterThan(settled * 1.05));
    });

    for (final animation in CardAnimation.values) {
      testWidgets('${animation.name}: on and off again, ending where it should', (tester) async {
        await overlay(tester, null, animation);
        await overlay(tester, card, animation);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Break'), findsOneWidget);
        expect(tester.getCenter(find.text('Break')).dx, closeTo(800, 2));
        await overlay(tester, null, animation);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Break'), findsNothing);
      });
    }

    testWidgets('a built-in picture fills the screen without a frame', (tester) async {
      await overlay(tester, const OverlayCard(image: 'builtin:correct'), CardAnimation.off);
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, 'assets/cards/correct.jpg');
    });
  });

  group('on the controller', () {
    late SessionHost host;
    late SessionConnection connection;

    Future<void> pumpBoth(WidgetTester tester) async {
      tester.view.physicalSize = const Size(2000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      host = SessionHost(initial: fixtureState());
      connection = SessionConnection.local(host, game: fixtureGame());
      addTearDown(connection.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(width: 460, child: ControllerView(connection: connection)),
              Expanded(child: PresenterView(connection: connection)),
            ],
          ),
        ),
      ));
      await tester.pump();
    }

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('a built-in picture goes on screen with the animation chosen next to it', (tester) async {
      await pumpBoth(tester);
      await tap(tester, find.descendant(of: find.byType(ControllerView), matching: find.widgetWithText(TextButton, 'Effects')));
      await tap(tester, find.byKey(const ValueKey('card-animation')));
      await tap(tester, find.text('Bounce in').last);
      expect(host.state.cardAnimation, CardAnimation.bounce);

      await tap(tester, find.byTooltip("Time's up!"));
      expect(host.state.overlay!.image, 'builtin:times_up');
      final shown = find.descendant(of: find.byType(PresenterView), matching: find.byType(Image));
      expect((tester.widget<Image>(shown).image as AssetImage).assetName, 'assets/cards/times_up.jpg');
      await tap(tester, find.text('Take card off screen'));
      expect(host.state.overlay, isNull);
      expect(host.state.cardAnimation, CardAnimation.bounce);
    });
  });

  group('in the editor', () {
    Future<List<List<Map<String, dynamic>>>> pumpDialog(WidgetTester tester, List<CueCard> cards) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saved = <List<Map<String, dynamic>>>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CardsDialog(gameId: 'g', cards: cards, save: saved.add)),
      ));
      return saved;
    }

    testWidgets('cards are moved by their handle along the row', (tester) async {
      final saved = await pumpDialog(tester, const [
        CueCard(title: 'One'),
        CueCard(title: 'Two'),
        CueCard(title: 'Three'),
      ]);
      final handle = find.byIcon(Icons.drag_indicator).first;
      final right = tester.getCenter(find.byIcon(Icons.drag_indicator).last).dx - tester.getCenter(handle).dx;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset((right + 200) / 10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect([for (final card in saved.last) card['title']], ['Two', 'Three', 'One']);
    });

    testWidgets('a built-in picture is switched off, not removed; an own card can be removed', (tester) async {
      final saved = await pumpDialog(tester, const [CueCard(title: 'Answer'), CueCard(image: 'builtin:correct')]);
      // Only the own card can be edited, and removed from its editor.
      expect(find.byTooltip('Edit'), findsOneWidget);
      await tester.tap(find.byTooltip('Keep it out of the show').last);
      await tester.pumpAndSettle();
      expect(saved.last.last, containsPair('hidden', true));
      expect(saved.last.last['image'], 'builtin:correct');
      await tester.tap(find.byTooltip('Offer it in the show'));
      await tester.pumpAndSettle();
      expect(saved.last.last.containsKey('hidden'), isFalse);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove card'));
      await tester.pumpAndSettle();
      expect([for (final card in saved.last) card['image']], ['builtin:correct']);
    });

    testWidgets('a new card is made in its own editor and lands at the end of the row', (tester) async {
      final saved = await pumpDialog(tester, const [CueCard(title: 'Rules')]);
      await tester.tap(find.text('New card'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Break');
      await tester.tap(find.text('Poster'));
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect([for (final card in saved.last) card['title']], ['Rules', 'Break']);
      expect(saved.last.last['style'], 'poster');
    });
  });
}
