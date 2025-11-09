import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:quiz_show/pages/games_display/playboard.dart';

import '../../database/constants.dart';

class WheelPlayboard extends Playboard {
  const WheelPlayboard({
    super.key,
    required super.homePageState,
    required super.size,
    required super.categoryNames,
    required super.questionDocs,
    required super.selectedFieldData,
    required super.playedFieldsList,
  });

  @override
  Widget build(BuildContext context) {
    var (List<List<Map<String, dynamic>>> newQuestionDocs, List<int> gameQuestionPoints, List<(int, int)> emptyFields) =
        normalizeQuestionsInPoint(questionDocs);
    var ((int, int) newSelectedFieldData, List<(int, int)> newPlayedFieldsList) =
        normalizePlayData(gameQuestionPoints, emptyFields, categoryNames.length , selectedFieldData, playedFieldsList);

    return CustomPaint(
      size: size,
      painter: WheelPlayingFieldPainter(
        categories: categoryNames,
        pointRings: gameQuestionPoints,
        disabledFields: newPlayedFieldsList..addAll(emptyFields),
        colorScheme: Theme.of(context).colorScheme,
        highlightedField: newSelectedFieldData,
      ),
    );
  }
}

(List<List<Map<String, dynamic>>> newQuestionDocs, List<int> gameQuestionPoints, List<(int, int)> emptyFields) normalizeQuestionsInPoint(
      List<List<Map<String, dynamic>>> questionDocs) {
    // bestimme für jede Punktzahl, wie oft sie maximal in einer Kategorie vorkommt
    final Set<int> pointValues = {};
    final Map<int, int> maxCountPerPoint = {};
    for (var cat in questionDocs) {
      final Map<int, int> counts = {};
      for (var q in cat) {
        final int p = (q[pointsPlus] ?? 0) as int;
        pointValues.add(p);
        counts[p] = (counts[p] ?? 0) + 1;
      }
      for (var e in counts.entries) {
        maxCountPerPoint[e.key] = max(maxCountPerPoint[e.key] ?? 0, e.value);
      }
    }

    // baue die Ringe: für jede Punktzahl so viele Ringe wie der maximale Vorkommenwert
    final List<int> sortedPoints = pointValues.toList()..sort((a, b) => a - b);
    final List<int> rings = [];
    for (var p in sortedPoints) {
      final int repeat = maxCountPerPoint[p] ?? 0;
      for (int i = 0; i < repeat; i++) {
        rings.add(p);
      }
    }

    // initialisiere Ergebnisraster und fülle es, markiere leere Felder
    final List<List<Map<String, dynamic>>> questions = List.generate(questionDocs.length, (_) => []);
    final List<(int, int)> empties = [];
    for (int i = 0; i < questionDocs.length; i++) {
      final cat = questionDocs[i];
      // gruppiere Fragen der Kategorie nach Punktzahl (erhält Reihenfolge)
      final Map<int, List<Map<String, dynamic>>> grouped = {};
      for (var q in cat) {
        final int p = (q[pointsPlus] ?? 0) as int;
        grouped.putIfAbsent(p, () => []).add(q);
      }

      int ringIndex = 0;
      for (var p in sortedPoints) {
        final int repeat = maxCountPerPoint[p] ?? 0;
        final List<Map<String, dynamic>> bucket = grouped[p] ?? [];
        for (int k = 0; k < repeat; k++) {
          if (k < bucket.length) {
            questions[i].add(bucket[k]);
          } else {
            questions[i].add({});
            empties.add((i, ringIndex));
          }
          ringIndex++;
        }
      }
    }

    return (questions, rings, empties);
  }

//maps the play data to the normalized question data
((int, int) selectedFieldData, List<(int, int)> playedFieldsList) normalizePlayData(List<int> gameQuestionPoints, List<(int, int)> emptyFields, int categoryCount, (int, int) selectedFieldData, List<(int, int)> playedFieldsList) {
  List<Map<int,int>> mappedIndices = [];
  for (int categoryIndex = 0; categoryIndex < categoryCount; categoryIndex++) {
    int emptyFieldsCount = 0;
    mappedIndices.add({});
    for(int ringIndex = 0; ringIndex < gameQuestionPoints.length; ringIndex++) {
      if (emptyFields.contains((categoryIndex, ringIndex))) {
        emptyFieldsCount++;
      }
      mappedIndices[categoryIndex][ringIndex - emptyFieldsCount] = ringIndex;
    }
  }
  var newSelectedFieldData = selectedFieldData.$1 < 0 ? (-1,-1) : (selectedFieldData.$1, mappedIndices[selectedFieldData.$1][selectedFieldData.$2] ?? selectedFieldData.$2);
  List<(int, int)> newPlayedFieldsList = playedFieldsList
      .map((e) => (e.$1, mappedIndices[e.$1][e.$2] ?? e.$2))
      .toList();
  return (newSelectedFieldData, newPlayedFieldsList);
}

((int, int) selectedFieldData, List<(int, int)> playedFieldsList) denormalizePlayData(List<int> gameQuestionPoints, List<(int, int)> emptyFields, int categoryCount, (int, int) selectedFieldData, List<(int, int)> playedFieldsList) {
  List<Map<int,int>> mappedIndices = [];
  for (int categoryIndex = 0; categoryIndex < categoryCount; categoryIndex++) {
    int emptyFieldsCount = 0;
    mappedIndices.add({});
    for(int ringIndex = 0; ringIndex < gameQuestionPoints.length; ringIndex++) {
      if (emptyFields.contains((categoryIndex, ringIndex))) {
        emptyFieldsCount++;
      }
      mappedIndices[categoryIndex][ringIndex] = ringIndex - emptyFieldsCount;
    }
  }
  var newSelectedFieldData = selectedFieldData.$1 < 0 ? (-1,-1) : (selectedFieldData.$1, mappedIndices[selectedFieldData.$1][selectedFieldData.$2] ?? selectedFieldData.$2);
  List<(int, int)> newPlayedFieldsList = playedFieldsList
      .map((e) => (e.$1, mappedIndices[e.$1][e.$2] ?? e.$2))
      .toList();
  return (newSelectedFieldData, newPlayedFieldsList);
}


class WheelPlayingFieldPainter extends CustomPainter {
  final List<int> pointRings;
  final List<String> categories;
  final (int categoryIndex, int ringIndex) highlightedField;
  final List<(int categoryIndex, int ringIndex)> disabledFields;
  final ColorScheme colorScheme;

  WheelPlayingFieldPainter({
    super.repaint,
    required this.pointRings,
    required this.categories,
    required this.colorScheme,
    required this.highlightedField,
    required this.disabledFields,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Offset center = size.center(const Offset(0, 0));
    double heightfactor = categories.length % 2 == 1 ? 0.85 : 1;
    canvas.translate(center.dx, center.dy * heightfactor);
    double smallerDimension = min(size.height * heightfactor, size.width * 0.5);

    //paints
    Paint thinStructurePaint = Paint()
      ..color = colorScheme.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = smallerDimension / 300;
    Paint highlightStructurePaint = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = smallerDimension / 180;

    double cellPaintStrokeWidth = smallerDimension / (pointRings.length + 2) / 2;
    Paint selectedCellPaint = Paint()
      ..color = Color.lerp(Color.lerp(colorScheme.primary, colorScheme.secondaryContainer, 0.5), colorScheme.primaryContainer, 0.1)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellPaintStrokeWidth;
    Paint disabledCellPaint = Paint()
      ..color = colorScheme.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellPaintStrokeWidth;
    Paint cellPaint = Paint()
      ..color = colorScheme.secondaryContainer
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellPaintStrokeWidth;

    double radians = 1.0 / categories.length * pi * 2;
    canvas.rotate(radians / 2);
    for (int ringIndex = 0; ringIndex < pointRings.length; ringIndex++) {
      double halfradius = smallerDimension * 0.5 / (pointRings.length + 2) * (ringIndex + 1.5);
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: pointRings[ringIndex].toString(),
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: smallerDimension / 25,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      for (int categoryIndex = 0; categoryIndex < categories.length; categoryIndex++) {
        (int, int) cell = (categoryIndex, ringIndex);
        canvas.drawArc(
            Rect.fromCircle(center: Offset.zero, radius: halfradius),
            3 * pi / 2 - radians / 2,
            radians,
            false,
            cell == highlightedField
                ? selectedCellPaint
                : disabledFields.contains(cell)
                    ? disabledCellPaint
                    : cellPaint);
        textPainter.paint(
          canvas,
          Offset(0, -halfradius) - textPainter.size.center(Offset.zero),
        );
        canvas.rotate(radians);
      }
    }
    canvas.rotate(-radians / 2);

    //striche
    double maxRingRadius = smallerDimension * 0.5 / (pointRings.length + 2) * (pointRings.length + 1);
    double minRingRadius = smallerDimension * 0.5 / (pointRings.length + 2);
    for (int categoryIndex = 0; categoryIndex <= categories.length; categoryIndex++) {
      double radians = categoryIndex / categories.length * pi * 2;
      canvas.drawLine(Offset(sin(radians) * minRingRadius, -cos(radians) * minRingRadius),
          Offset(sin(radians) * maxRingRadius, -cos(radians) * maxRingRadius), thinStructurePaint);
    }

    //thin rings
    for (int ringIndex = 2; ringIndex <= pointRings.length; ringIndex++) {
      double radius = smallerDimension * 0.5 / (pointRings.length + 2) * (ringIndex);
      canvas.drawCircle(Offset.zero, radius, thinStructurePaint);
    }

    //drop shadows
    double ringPercentage = 1.0 / (pointRings.length + 2);
    Rect rect = Rect.fromCircle(center: Offset.zero, radius: smallerDimension * 0.5);
    RadialGradient gradient = RadialGradient(
      colors: const <Color>[
        Colors.black26,
        Colors.black12,
        Colors.transparent,
        Colors.transparent,
        Colors.black12,
        Colors.black26,
        Colors.transparent,
      ],
      stops: <double>[
        ringPercentage,
        ringPercentage + 0.001,
        ringPercentage * 1.5,
        1 - ringPercentage * 1.5,
        1 - ringPercentage - 0.001,
        1 - ringPercentage,
        1.0
      ],
    );
    // rect is the area we are painting over
    final Paint paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    //thick rings
    for (int ringIndex in [1, pointRings.length + 1]) {
      double radius = smallerDimension * 0.5 / (pointRings.length + 2) * (ringIndex);
      canvas.drawCircle(Offset.zero, radius, highlightStructurePaint);
    }

    //titles
    double lW = smallerDimension / 120;
    Paint linePaint = Paint()
      ..color = colorScheme.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = lW
      ..strokeCap = StrokeCap.round;
    double sideHeightStep = smallerDimension / ((categories.length) ~/ 2);
    for (var (index, title) in categories.indexed) {
      TextPainter textPainter;
      TextSpan text = TextSpan(
        text: title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: smallerDimension / 17,
        ),
      );
      Offset offset;
      if (index < (categories.length - 1) / 2) {
        textPainter = TextPainter(
          text: text,
          textDirection: TextDirection.rtl,
        );
        textPainter.layout(maxWidth: size.width / 5);
        offset = Offset(size.width * 0.45, -smallerDimension * 0.5 + (index + 0.5) * sideHeightStep) - textPainter.size.centerRight(Offset.zero);

        canvas.drawLine(
            textPainter.size.bottomRight(offset).translate(3 * lW, 2 * lW), textPainter.size.topRight(offset).translate(3 * lW, -2 * lW), linePaint);
      } else if (index == (categories.length - 1) / 2) {
        textPainter = TextPainter(
          text: text,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: size.width / 3);
        offset = Offset(0, smallerDimension * 0.5) - textPainter.size.topCenter(Offset.zero);

        canvas.drawLine(textPainter.size.bottomLeft(offset).translate(-2 * lW, 2 * lW),
            textPainter.size.bottomRight(offset).translate(2 * lW, 2 * lW), linePaint);
      } else {
        textPainter = TextPainter(
          text: text,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: size.width / 5);
        offset = Offset(size.width * -0.45, smallerDimension * 0.5 - (index - ((categories.length + 1) ~/ 2) + 0.5) * sideHeightStep) -
            textPainter.size.centerLeft(Offset.zero);

        canvas.drawLine(
            textPainter.size.bottomLeft(offset).translate(-3 * lW, 2 * lW), textPainter.size.topLeft(offset).translate(-3 * lW, -2 * lW), linePaint);
      }
      textPainter.paint(
        canvas,
        offset,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; //TODO
  }
}
