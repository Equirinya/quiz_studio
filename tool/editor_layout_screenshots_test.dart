// The question editor with every question type and its options switched on,
// at phone and desktop width, to judge its layout:
//   flutter test tool/editor_layout_screenshots_test.dart --update-goldens
// Writes tool/screenshots/editor_layout/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/core/theme.dart';
import 'package:quiz_show/features/games/pages/category_editor_page.dart';
import 'package:quiz_show/features/games/widgets/editor_section.dart';
import 'package:quiz_show/game/game.dart';

import '../test/game/connections_fixture.dart';
import '../test/game/rapid_fixture.dart';
import '../test/game/top_answers_fixture.dart';

final _fonts = '${Platform.environment['FLUTTER_ROOT'] ?? '/home/jacob/development/flutter'}/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  Future<ByteData> read(String name) => Future.value(ByteData.view(File('$_fonts/$name').readAsBytesSync().buffer));
  final roboto = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(read(name));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();
}

const _sounds = {
  'musicEffects': {'musicEffectAnswerCorrect': 'builtin:right_answer/voice_correct_female'},
};

/// Every question to look at, by name.
final Map<String, Map<String, dynamic>> _cases = {
  'free_whiteboard': {
    'type': 'free',
    'question': 'Draw the flag of Japan',
    'description': 'Drawing',
    'answerHint': 'A red circle on white',
    'pointsPlus': 400,
    'pointsMinus': 100,
    'image': 'flag.png',
    'music': 'theme.mp3',
    ..._sounds,
    'noBuzzer': true,
    'companion': {'kind': 'whiteboard', 'timer': 60, 'background': 'list', 'listRows': 5},
  },
  'free_text': {
    'type': 'free',
    'question': 'Capital of Peru?',
    'answerHint': 'Lima',
    'pointsPlus': 200,
    'pointsMinus': 0,
    'noBuzzer': true,
    'companion': {'kind': 'text', 'timer': 30},
  },
  'free_number': {
    'type': 'free',
    'question': 'How tall is the Eiffel Tower?',
    'answerHint': '330 m',
    'pointsPlus': 300,
    'pointsMinus': 0,
    'noBuzzer': true,
    'companion': {'kind': 'number', 'timer': 30, 'solution': 330, 'tolerance': 10, 'unit': 'm'},
  },
  'free_slider': {
    'type': 'free',
    'question': 'In which year did the Berlin Wall fall?',
    'answerHint': '1989',
    'pointsPlus': 300,
    'pointsMinus': 0,
    'noBuzzer': true,
    'companion': {'kind': 'slider', 'timer': 30, 'solution': 1989, 'tolerance': 2, 'unit': '', 'min': 1900, 'max': 2020, 'step': 1},
  },
  // Just switched to the slider: the labels sit inside the empty fields.
  'free_slider_empty': {
    'type': 'free',
    'question': 'In which year did the Berlin Wall fall?',
    'pointsPlus': 300,
    'pointsMinus': 0,
    'noBuzzer': true,
    'companion': {'kind': 'slider'},
  },
  'free_order': {
    'type': 'free',
    'question': 'Sort the planets by distance from the sun',
    'pointsPlus': 300,
    'pointsMinus': 0,
    'noBuzzer': true,
    'companion': {
      'kind': 'order',
      'timer': 60,
      'options': ['Mercury', 'Venus', 'Earth', 'Mars'],
    },
  },
  'free_match': {
    'type': 'free',
    'question': 'Which capital belongs to which country?',
    'pointsPlus': 300,
    'pointsMinus': 0,
    'noBuzzer': true,
    'companion': {
      'kind': 'match',
      'timer': 60,
      'options': ['France', 'Italy', 'Spain'],
      'targets': ['Paris', 'Rome', 'Madrid'],
    },
  },
  'free_list': {
    'type': 'free',
    'question': 'Name as many Beatles songs as you can',
    'pointsPlus': 300,
    'pointsMinus': 0,
    'noBuzzer': true,
    'companion': {'kind': 'list', 'timer': 90, 'listRows': 8},
  },
  'free_buzzer_timer': {
    'type': 'free',
    'question': 'Who wrote Faust?',
    'answerHint': 'Goethe',
    'pointsPlus': 200,
    'pointsMinus': 100,
    'timer': 20,
  },
  'free_bets': {'type': 'free', 'question': 'Capital of Peru?', 'answerHint': 'Lima', 'pointsPlus': 300, 'pointsMinus': 0, 'wager': true},
  'free_amount_bet': {
    'type': 'free',
    'question': 'Push-ups, go!',
    'pointsPlus': 10,
    'pointsMinus': 10,
    'noPhoneBuzzer': true,
    'timer': 30,
    'amountBet': {'prompt': 'How many push-ups can you do in 30 seconds?', 'max': 50},
  },
  'abcd_choice': {
    'type': 'abcd',
    'question': 'Which planet is the largest?',
    'pointsPlus': 200,
    'pointsMinus': 50,
    ..._sounds,
    'answers': ['Mars', 'Jupiter', 'Saturn', 'Venus'],
    'answersCorrect': [false, true, false, false],
    'companion': {'kind': 'choice', 'timer': 20},
  },
  'feud': {
    'type': 'feud',
    'question': 'Name something people take to the beach',
    'pointsPlus': 500,
    'information': ['Towel', 'Sunscreen', 'Umbrella', 'Book'],
    'informationPercentage': [40, 30, 20, 10],
  },
  'reveal_pictures': {
    'type': 'progressingReveal',
    'question': 'Which city is this?',
    'answerHint': 'Rome',
    'pointsPlus': 300,
    'pointsMinus': 0,
    'information': ['A river', 'Seven hills', 'The Colosseum'],
    'informationImage': ['1.png', '', '3.png'],
    'informationMusic': ['', 'bells.mp3', ''],
    'pictureStrip': true,
    'companion': {'kind': 'text', 'timer': 45},
  },
  'connections': connectionsGame(timer: 120).question(puzzle)!.data,
  'rapid_buzzer': rapidGame().question(buzzerRound)!.data,
  'rapid_devices': rapidGame().question(devicesRound)!.data,
  'matching': matchingGame().question(matchingRound)!.data,
  'top_answers': topAnswersGame(mode: TopAnswersMode.typed, timer: 60).question(films)!.data,
};

/// Where the pictures go; the German run (german_screenshots_test.dart) changes it.
String shotDir = 'screenshots';

void main() {
  setUpAll(_loadFonts);

  /// Draws the card expanded at [width], as tall as it needs to be.
  Future<void> card(WidgetTester tester, String name, Map<String, dynamic> data, double width, {bool openAll = false}) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget app() => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        appBar: AppBar(title: const Text("Maths")),
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: [QuestionCard(gameId: 'g', categoryId: 'c', question: Question.fromMap('q', data), initiallyExpanded: true)],
        ),
      ),
    );
    // Measure first, then draw at the height the card needs.
    tester.view.physicalSize = Size(width, 4000);
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 500));
    if (openAll) {
      // Open the sections that start closed.
      for (final section in tester.widgetList<EditorSection>(find.byType(EditorSection)).toList()) {
        if (!section.open) section.onToggle();
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }
    final height = tester.getRect(find.byType(QuestionCard)).bottom + 16;
    tester.view.physicalSize = Size(width, height);
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('$shotDir/editor_layout/$name.png'));
  }

  for (final MapEntry(key: name, value: data) in _cases.entries) {
    testWidgets('editor layout: $name, phone', (tester) => card(tester, '${name}_phone', data, 412));
    testWidgets('editor layout: $name, phone, all open', (tester) => card(tester, '${name}_phone_open', data, 412, openAll: true));
    testWidgets('editor layout: $name, desktop', (tester) => card(tester, '${name}_desktop', data, 1280));
  }
}
