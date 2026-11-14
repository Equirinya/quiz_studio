import 'dart:math';

import 'package:flutter/material.dart';

import 'package:quiz_show/features/companion/answer_view.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// [children] side by side on one line, scaled down together when they
/// don't fit, never wrapped onto a second line.
class OneRow extends StatelessWidget {
  const OneRow({super.key, required this.children, required this.spacing});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) SizedBox(width: spacing),
              child,
            ],
          ],
        ),
      );
}

/// Below a question while teams answer on their devices: the clock and, on
/// one small line, which teams are still thinking, writing or done.
class RoundStatusStrip extends StatelessWidget {
  const RoundStatusStrip({super.key, required this.state, required this.round, required this.unit});

  final SessionState state;
  final AnswerRound round;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The presenter runs the show, so the deadline is on its own clock.
        if (round.open && round.endsAtMillis != null)
          Padding(
            padding: EdgeInsets.only(bottom: unit),
            child: RoundCountdown(openedAt: round.openedAtMillis, endsAt: round.endsAtMillis!, hostClock: true, height: unit * 1.4),
          ),
        OneRow(
          spacing: unit,
          children: [
            for (final team in state.roundTeams)
              Builder(builder: (context) {
                final answer = round.answers[team.id];
                final writing = answer != null && !answer.isEmpty;
                final done = answer?.locked == true || (!round.open && writing);
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: unit * 1.6, vertical: unit * 0.7),
                  decoration: BoxDecoration(
                    color: done ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(unit * 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        done
                            ? Icons.lock
                            : writing
                                ? Icons.edit
                                : Icons.hourglass_empty,
                        size: unit * 2.4,
                        color: done ? scheme.onPrimaryContainer : scheme.outline,
                      ),
                      SizedBox(width: unit * 0.8),
                      Text(team.name, style: TextStyle(fontSize: unit * 2.2, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }
}

/// Columns and rows for [count] tiles: one big, then 2×1, 2×2, 3×2, 3×3, …
(int columns, int rows) gridShape(int count) {
  if (count <= 1) return (1, 1);
  final columns = sqrt(count).ceil();
  return (columns, (count / columns).ceil());
}

/// The answers the gamemaster has put on the big screen, over the question:
/// one team nearly full screen, more in an even grid. Each with its ruling
/// once there is one.
class ShownAnswers extends StatelessWidget {
  const ShownAnswers({
    super.key,
    required this.state,
    required this.round,
    required this.unit,
    this.places = const {},
    this.backgroundImage,
  });

  final SessionState state;
  final AnswerRound round;
  final double unit;

  /// By closeness: each team's place, 0 = first.
  final Map<String, int> places;

  /// Whiteboards drawn on a picture: that picture.
  final ImageProvider? backgroundImage;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final teamId in round.revealed)
        if (state.team(teamId) != null) state.team(teamId)!,
    ];
    final (columns, rows) = gridShape(shown.length);
    final gap = unit * 1.2;
    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: r == 0 ? 0 : gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) SizedBox(width: gap),
                    Expanded(
                      // The last row keeps the same tile width.
                      child: r * columns + c < shown.length
                          ? _AnswerTile(
                              state: state,
                              round: round,
                              team: shown[r * columns + c],
                              unit: unit * (shown.length == 1 ? 1.4 : (shown.length <= 4 ? 1.1 : 1)),
                              place: places[shown[r * columns + c].id],
                              backgroundImage: backgroundImage,
                            )
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.state,
    required this.round,
    required this.team,
    required this.unit,
    this.place,
    this.backgroundImage,
  });

  final SessionState state;
  final AnswerRound round;
  final Team team;
  final double unit;
  final int? place;
  final ImageProvider? backgroundImage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final verdict = state.results.verdicts[team.id];
    // Shown once it is on the scoreboard, not while it is being rated.
    final awarded = state.results.given[team.id];
    final place = verdict == null ? this.place : null;
    final medal = place == null ? null : placeColors.elementAtOrNull(place);
    final answer = round.answers[team.id];
    final took = answer?.secondsTaken(round);
    return Container(
      padding: EdgeInsets.all(unit * 1.5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(unit * 2),
        border: Border.all(
          width: unit * 0.5,
          color: verdict == null
              ? (medal ?? scheme.outlineVariant)
              : verdict
              ? Colors.green
              : scheme.error,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  team.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: unit * 2.8, fontWeight: FontWeight.w700, color: scheme.primary),
                ),
              ),
              if (took != null) Text("  ${took.toStringAsFixed(1)} s", style: TextStyle(fontSize: unit * 2.2, color: scheme.outline)),
              if (place != null) ...[
                SizedBox(width: unit),
                PlaceBadge(place: place, color: medal, unit: unit),
                if (awarded != null && awarded != 0)
                  Text(" +$awarded", style: TextStyle(fontSize: unit * 2.6, fontWeight: FontWeight.w700)),
              ],
              if (verdict != null) ...[
                SizedBox(width: unit),
                Icon(verdict ? Icons.check_circle : Icons.cancel, size: unit * 3.2, color: verdict ? Colors.green : scheme.error),
                if (awarded != null && awarded != 0)
                  Text(" ${awarded > 0 ? "+" : ""}$awarded", style: TextStyle(fontSize: unit * 2.6, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          SizedBox(height: unit),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final whiteboard = round.kind == CompanionKind.whiteboard;
                // A drawing fills the tile; an upright one goes by the height.
                if (whiteboard) {
                  final aspect = drawingAspect(answer?.drawing);
                  final width = min(box.maxWidth, box.maxHeight * aspect);
                  return Center(
                    child: SizedBox(
                      width: width,
                      child: AnswerView(spec: round.spec, answer: answer, fontSize: unit * 3.4, backgroundImage: backgroundImage),
                    ),
                  );
                }
                // Text grows with the tile, and shrinks to fit when long.
                return Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: box.maxWidth),
                      child: AnswerView(
                        spec: round.spec,
                        answer: answer,
                        fontSize: (box.maxHeight / 5).clamp(unit * 3.4, unit * 9),
                        backgroundImage: backgroundImage,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold, silver and bronze for the first three places.
const placeColors = [Color(0xFFE0B526), Color(0xFFA8B0B8), Color(0xFFC07A3E)];

/// "1st", "2nd", … on a round badge, in the place's colour from the podium.
class PlaceBadge extends StatelessWidget {
  const PlaceBadge({super.key, required this.place, required this.color, required this.unit});

  final int place;
  final Color? color;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: unit * 1.2, vertical: unit * 0.3),
      decoration: BoxDecoration(color: color ?? scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(unit * 2)),
      child: Text(
        context.l10n.ordinal(place + 1),
        style: TextStyle(fontSize: unit * 2.4, fontWeight: FontWeight.w800, color: color == null ? scheme.onSurface : Colors.black87),
      ),
    );
  }
}
