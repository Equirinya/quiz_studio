import 'dart:math';

import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';

const String pointsPlus = 'pointsPlus';

/// The wheel: one sector per category, one ring per point value. The painters
/// and the normalisation below are v1's, unchanged; this widget only feeds
/// them from the v2 models.
class WheelBoard extends StatelessWidget {
  const WheelBoard({super.key, required this.group, required this.state, required this.size});

  final CategoryGroup group;
  final SessionState state;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final categoryNames = [for (final category in group.categories) category.name];
    if (categoryNames.isEmpty) return const SizedBox();
    final questionDocs = [
      for (final category in group.categories)
        [
          for (final question in category.questions) <String, dynamic>{pointsPlus: question.pointsPlus},
        ],
    ];
    (int, int)? indexOf(QuestionRef? ref) {
      if (ref == null) return null;
      final c = group.categories.indexWhere((category) => category.id == ref.categoryId);
      if (c < 0) return null;
      final q = group.categories[c].questions.indexWhere((question) => question.id == ref.questionId);
      return q < 0 ? null : (c, q);
    }

    final selectedFieldData = indexOf(state.current) ?? (-1, -1);
    final playedFieldsList = [for (final key in state.played) ?indexOf(QuestionRef.tryParse(key))];

    if (group.splitPointFields) {
      var (
        List<List<List<Map<String, dynamic>>>> _,
        List<int> gameQuestionPoints,
        List<List<int>> subFields,
        List<(int, int)> emptyFields,
      ) = normalizeQuestionsInPointWithSplitFields(questionDocs);
      var ((int, int, int) newSelectedFieldData, List<(int, int, int)> newPlayedFieldsList) = normalizePlayDataWithSplitFields(
        subFields,
        gameQuestionPoints,
        emptyFields,
        categoryNames.length,
        selectedFieldData,
        playedFieldsList,
      );
      return CustomPaint(
        size: size,
        painter: WheelPlayingFieldPainterWithSplitFields(
          categories: categoryNames,
          pointRings: gameQuestionPoints,
          subFields: subFields,
          disabledFields: newPlayedFieldsList..addAll(emptyFields.map((e) => (e.$1, e.$2, 0))),
          colorScheme: Theme.of(context).colorScheme,
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          highlightedField: newSelectedFieldData,
        ),
      );
    }
    var (List<List<Map<String, dynamic>>> _, List<int> gameQuestionPoints, List<(int, int)> emptyFields) =
        normalizeQuestionsInPoint(questionDocs);
    var ((int, int) newSelectedFieldData, List<(int, int)> newPlayedFieldsList) = normalizePlayData(
      gameQuestionPoints,
      emptyFields,
      categoryNames.length,
      selectedFieldData,
      playedFieldsList,
    );
    return CustomPaint(
      size: size,
      painter: WheelPlayingFieldPainter(
        categories: categoryNames,
        pointRings: gameQuestionPoints,
        disabledFields: newPlayedFieldsList..addAll(emptyFields),
        colorScheme: Theme.of(context).colorScheme,
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        highlightedField: newSelectedFieldData,
      ),
    );
  }
}

// ── v1, unchanged from here on ───────────────────────────────────────────────

(List<List<List<Map<String, dynamic>>>> newQuestionDocs, List<int> gameQuestionPoints, List<List<int>> subFields, List<(int, int)> emptyFields)
normalizeQuestionsInPointWithSplitFields(List<List<Map<String, dynamic>>> questionDocs) {
  // bestimme für jede Punktzahl, wie oft sie maximal in einer Kategorie vorkommt
  final Set<int> pointValues = {};
  for (var cat in questionDocs) {
    for (var q in cat) {
      final int p = (q[pointsPlus] ?? 0) as int;
      pointValues.add(p);
    }
  }

  // baue die Ringe: für jede Punktzahl so viele Ringe wie der maximale Vorkommenwert
  final List<int> sortedPoints = pointValues.toList()..sort((a, b) => a - b);

  // initialisiere Ergebnisraster und fülle es, markiere leere Felder
  final List<List<List<Map<String, dynamic>>>> questions = List.generate(questionDocs.length, (_) => []);
  List<List<int>> subFields = List.generate(questionDocs.length, (_) => []);
  final List<(int, int)> empties = [];
  for (int i = 0; i < questionDocs.length; i++) {
    final cat = questionDocs[i];
    // gruppiere Fragen der Kategorie nach Punktzahl (erhält Reihenfolge)
    final Map<int, List<Map<String, dynamic>>> grouped = {};
    for (var q in cat) {
      final int p = (q[pointsPlus] ?? 0) as int;
      grouped.putIfAbsent(p, () => []).add(q);
    }

    for (var p in sortedPoints.indexed) {
      if (grouped.containsKey(p.$2)) {
        questions[i].add(grouped[p.$2]!);
        subFields[i].add(grouped[p.$2]!.length);
      } else {
        questions[i].add([]);
        empties.add((i, p.$1));
        subFields[i].add(0);
      }
    }
  }

  return (questions, sortedPoints, subFields, empties);
}

//maps the play data to the normalized question data
((int, int, int) selectedFieldData, List<(int, int, int)> playedFieldsList) normalizePlayDataWithSplitFields(
  List<List<int>> subFields,
  List<int> gameQuestionPoints,
  List<(int, int)> emptyFields,
  int categoryCount,
  (int, int) selectedFieldData,
  List<(int, int)> playedFieldsList,
) {
  List<Map<int, (int, int)>> mappedIndices = [];
  for (int categoryIndex = 0; categoryIndex < categoryCount; categoryIndex++) {
    int emptyFieldsCount = 0;
    int subFieldCount = 0;
    mappedIndices.add({});
    for (int ringIndex = 0; ringIndex < gameQuestionPoints.length; ringIndex++) {
      if (subFields[categoryIndex][ringIndex] == 0) {
        emptyFieldsCount++;
      } else {
        for (int subIndex = 0; subIndex < subFields[categoryIndex][ringIndex]; subIndex++) {
          mappedIndices[categoryIndex][ringIndex - emptyFieldsCount + subFieldCount] = (ringIndex, subIndex);
          subFieldCount++;
        }
        subFieldCount--;
      }
    }
  }
  (int, int, int) newSelectedFieldData;
  if (selectedFieldData.$1 < 0) {
    newSelectedFieldData = (-1, -1, 0);
  } else {
    (int, int) mapped = mappedIndices[selectedFieldData.$1][selectedFieldData.$2] ?? (selectedFieldData.$2, 0);
    newSelectedFieldData = (selectedFieldData.$1, mapped.$1, mapped.$2);
  }
  List<(int, int, int)> newPlayedFieldsList = playedFieldsList.map((e) {
    (int, int) mapped = mappedIndices[e.$1][e.$2] ?? (e.$2, 0);
    return (e.$1, mapped.$1, mapped.$2);
  }).toList();

  return (newSelectedFieldData, newPlayedFieldsList);
}

(List<List<Map<String, dynamic>>> newQuestionDocs, List<int> gameQuestionPoints, List<(int, int)> emptyFields) normalizeQuestionsInPoint(
  List<List<Map<String, dynamic>>> questionDocs,
) {
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
((int, int) selectedFieldData, List<(int, int)> playedFieldsList) normalizePlayData(
  List<int> gameQuestionPoints,
  List<(int, int)> emptyFields,
  int categoryCount,
  (int, int) selectedFieldData,
  List<(int, int)> playedFieldsList,
) {
  List<Map<int, int>> mappedIndices = [];
  for (int categoryIndex = 0; categoryIndex < categoryCount; categoryIndex++) {
    int emptyFieldsCount = 0;
    mappedIndices.add({});
    for (int ringIndex = 0; ringIndex < gameQuestionPoints.length; ringIndex++) {
      if (emptyFields.contains((categoryIndex, ringIndex))) {
        emptyFieldsCount++;
      }
      mappedIndices[categoryIndex][ringIndex - emptyFieldsCount] = ringIndex;
    }
  }
  var newSelectedFieldData = selectedFieldData.$1 < 0
      ? (-1, -1)
      : (selectedFieldData.$1, mappedIndices[selectedFieldData.$1][selectedFieldData.$2] ?? selectedFieldData.$2);
  List<(int, int)> newPlayedFieldsList = playedFieldsList.map((e) => (e.$1, mappedIndices[e.$1][e.$2] ?? e.$2)).toList();
  return (newSelectedFieldData, newPlayedFieldsList);
}

((int, int) selectedFieldData, List<(int, int)> playedFieldsList) denormalizePlayData(
  List<int> gameQuestionPoints,
  List<(int, int)> emptyFields,
  int categoryCount,
  (int, int) selectedFieldData,
  List<(int, int)> playedFieldsList,
) {
  List<Map<int, int>> mappedIndices = [];
  for (int categoryIndex = 0; categoryIndex < categoryCount; categoryIndex++) {
    int emptyFieldsCount = 0;
    mappedIndices.add({});
    for (int ringIndex = 0; ringIndex < gameQuestionPoints.length; ringIndex++) {
      if (emptyFields.contains((categoryIndex, ringIndex))) {
        emptyFieldsCount++;
      }
      mappedIndices[categoryIndex][ringIndex] = ringIndex - emptyFieldsCount;
    }
  }
  var newSelectedFieldData = selectedFieldData.$1 < 0
      ? (-1, -1)
      : (selectedFieldData.$1, mappedIndices[selectedFieldData.$1][selectedFieldData.$2] ?? selectedFieldData.$2);
  List<(int, int)> newPlayedFieldsList = playedFieldsList.map((e) => (e.$1, mappedIndices[e.$1][e.$2] ?? e.$2)).toList();
  return (newSelectedFieldData, newPlayedFieldsList);
}

class WheelPlayingFieldPainter extends CustomPainter {
  final List<int> pointRings;
  final List<String> categories;
  final (int categoryIndex, int ringIndex) highlightedField;
  final List<(int categoryIndex, int ringIndex)> disabledFields;
  final ColorScheme colorScheme;

  /// The app's font, which a painter does not pick up from the theme.
  final String? fontFamily;

  WheelPlayingFieldPainter({
    super.repaint,
    required this.pointRings,
    required this.categories,
    required this.colorScheme,
    this.fontFamily,
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
          style: TextStyle(color: colorScheme.onSurface, fontFamily: fontFamily, fontSize: smallerDimension / 25),
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
              : cellPaint,
        );
        textPainter.paint(canvas, Offset(0, -halfradius) - textPainter.size.center(Offset.zero));
        canvas.rotate(radians);
      }
    }
    canvas.rotate(-radians / 2);

    //striche
    double maxRingRadius = smallerDimension * 0.5 / (pointRings.length + 2) * (pointRings.length + 1);
    double minRingRadius = smallerDimension * 0.5 / (pointRings.length + 2);
    for (int categoryIndex = 0; categoryIndex <= categories.length; categoryIndex++) {
      double radians = categoryIndex / categories.length * pi * 2;
      canvas.drawLine(
        Offset(sin(radians) * minRingRadius, -cos(radians) * minRingRadius),
        Offset(sin(radians) * maxRingRadius, -cos(radians) * maxRingRadius),
        thinStructurePaint,
      );
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
        1.0,
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
        style: TextStyle(color: colorScheme.onSurface, fontFamily: fontFamily, fontSize: smallerDimension / 17),
      );
      Offset offset;
      if (index < (categories.length - 1) / 2) {
        textPainter = TextPainter(text: text, textDirection: TextDirection.rtl);
        textPainter.layout(maxWidth: size.width / 5);
        offset = Offset(size.width * 0.45, -smallerDimension * 0.5 + (index + 0.5) * sideHeightStep) - textPainter.size.centerRight(Offset.zero);

        canvas.drawLine(
          textPainter.size.bottomRight(offset).translate(3 * lW, 2 * lW),
          textPainter.size.topRight(offset).translate(3 * lW, -2 * lW),
          linePaint,
        );
      } else if (index == (categories.length - 1) / 2) {
        textPainter = TextPainter(text: text, textDirection: TextDirection.ltr);
        textPainter.layout(maxWidth: size.width / 3);
        offset = Offset(0, smallerDimension * 0.5) - textPainter.size.topCenter(Offset.zero);

        canvas.drawLine(
          textPainter.size.bottomLeft(offset).translate(-2 * lW, 2 * lW),
          textPainter.size.bottomRight(offset).translate(2 * lW, 2 * lW),
          linePaint,
        );
      } else {
        textPainter = TextPainter(text: text, textDirection: TextDirection.ltr);
        textPainter.layout(maxWidth: size.width / 5);
        offset =
            Offset(size.width * -0.45, smallerDimension * 0.5 - (index - ((categories.length + 1) ~/ 2) + 0.5) * sideHeightStep) -
            textPainter.size.centerLeft(Offset.zero);

        canvas.drawLine(
          textPainter.size.bottomLeft(offset).translate(-3 * lW, 2 * lW),
          textPainter.size.topLeft(offset).translate(-3 * lW, -2 * lW),
          linePaint,
        );
      }
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; //TODO
  }
}

class WheelPlayingFieldPainterWithSplitFields extends CustomPainter {
  final List<String> categories;
  final List<int> pointRings;
  final List<List<int>> subFields;
  final (int categoryIndex, int ringIndex, int subIndex) highlightedField;
  final List<(int categoryIndex, int ringIndex, int subIndex)> disabledFields;
  final ColorScheme colorScheme;

  /// The app's font, which a painter does not pick up from the theme.
  final String? fontFamily;

  WheelPlayingFieldPainterWithSplitFields({
    super.repaint,
    required this.categories,
    required this.pointRings,
    required this.subFields,
    required this.colorScheme,
    this.fontFamily,
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
    for (int ringIndex = 0; ringIndex < pointRings.length; ringIndex++) {
      double halfradius = smallerDimension * 0.5 / (pointRings.length + 2) * (ringIndex + 1.5);
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: pointRings[ringIndex].toString(),
          style: TextStyle(color: colorScheme.onSurface, fontFamily: fontFamily, fontSize: smallerDimension / 25),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      for (int categoryIndex = 0; categoryIndex < categories.length; categoryIndex++) {
        final int subCount = max(subFields[categoryIndex][ringIndex], 1);

        // base start for the whole category slice (canvas is already rotated per category)
        final double baseStart = 3 * pi / 2;
        final double subSweep = radians / subCount;

        // draw each subfield as its own arc and paint its number centered within that sub-arc
        for (int subIndex = 0; subIndex < subCount; subIndex++) {

          // choose paint per subfield: highlighted > disabled > custom gradient > default
          final bool isHighlighted = highlightedField == (categoryIndex, ringIndex, subIndex);
          final bool isDisabled = disabledFields.contains((categoryIndex, ringIndex, subIndex));

          Paint paintForSub = isHighlighted
              ? selectedCellPaint
              : isDisabled
              ? disabledCellPaint
              : cellPaint;

          canvas.rotate(subSweep / 2);
          // draw arc for this subfield
          canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: halfradius), baseStart-subSweep/2, subSweep, false, paintForSub);
          // paint number centered in this sub-arc: rotate into sub-arc center, paint at top
          textPainter.paint(canvas, Offset(0, -halfradius) - textPainter.size.center(Offset.zero));
          canvas.rotate(subSweep / 2);
        }
      }
    }

    //striche
    double maxRingRadius = smallerDimension * 0.5 / (pointRings.length + 2) * (pointRings.length + 1);
    double minRingRadius = smallerDimension * 0.5 / (pointRings.length + 2);
    for (int categoryIndex = 0; categoryIndex < categories.length; categoryIndex++) {
      double radians = categoryIndex / categories.length * pi * 2;
      Offset innerPoint = Offset(sin(radians) * minRingRadius, -cos(radians) * minRingRadius);
      Offset outerPoint = Offset(sin(radians) * maxRingRadius, -cos(radians) * maxRingRadius);
      canvas.drawLine(innerPoint, outerPoint, thinStructurePaint);

      // lines for subfields
      for (int ringIndex = 0; ringIndex < pointRings.length; ringIndex++) {
        final int subCount = max(subFields[categoryIndex][ringIndex], 1);
        final double subSweep = pi * 2 / (subCount*categories.length);
        for (int subIndex = 1; subIndex < subCount; subIndex++) {
          final double startAngle = radians + subSweep * subIndex;
          Offset innerPoint = Offset(sin(startAngle) * minRingRadius, -cos(startAngle) * minRingRadius);
          Offset outerPoint = Offset(sin(startAngle) * maxRingRadius, -cos(startAngle) * maxRingRadius);
          Offset newInnerPoint = Offset.lerp(innerPoint, outerPoint, (ringIndex) / pointRings.length)!;
          Offset newOuterPoint = Offset.lerp(innerPoint, outerPoint, (ringIndex + 1) / pointRings.length)!;
          canvas.drawLine(newInnerPoint, newOuterPoint, thinStructurePaint);
        }
      }
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
        1.0,
      ],
    );
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
        style: TextStyle(color: colorScheme.onSurface, fontFamily: fontFamily, fontSize: smallerDimension / 17),
      );
      Offset offset;
      if (index < (categories.length - 1) / 2) {
        textPainter = TextPainter(text: text, textDirection: TextDirection.rtl);
        textPainter.layout(maxWidth: size.width / 5);
        offset = Offset(size.width * 0.45, -smallerDimension * 0.5 + (index + 0.5) * sideHeightStep) - textPainter.size.centerRight(Offset.zero);

        canvas.drawLine(
          textPainter.size.bottomRight(offset).translate(3 * lW, 2 * lW),
          textPainter.size.topRight(offset).translate(3 * lW, -2 * lW),
          linePaint,
        );
      } else if (index == (categories.length - 1) / 2) {
        textPainter = TextPainter(text: text, textDirection: TextDirection.ltr);
        textPainter.layout(maxWidth: size.width / 3);
        offset = Offset(0, smallerDimension * 0.5) - textPainter.size.topCenter(Offset.zero);

        canvas.drawLine(
          textPainter.size.bottomLeft(offset).translate(-2 * lW, 2 * lW),
          textPainter.size.bottomRight(offset).translate(2 * lW, 2 * lW),
          linePaint,
        );
      } else {
        textPainter = TextPainter(text: text, textDirection: TextDirection.ltr);
        textPainter.layout(maxWidth: size.width / 5);
        offset =
            Offset(size.width * -0.45, smallerDimension * 0.5 - (index - ((categories.length + 1) ~/ 2) + 0.5) * sideHeightStep) -
            textPainter.size.centerLeft(Offset.zero);

        canvas.drawLine(
          textPainter.size.bottomLeft(offset).translate(-3 * lW, 2 * lW),
          textPainter.size.topLeft(offset).translate(-3 * lW, -2 * lW),
          linePaint,
        );
      }
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; //TODO
  }
}
