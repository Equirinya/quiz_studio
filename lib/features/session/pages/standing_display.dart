import 'dart:io';

import 'package:flutter/material.dart';

import 'package:quiz_show/features/session/widgets/team_colors.dart';
import 'package:quiz_show/game/game.dart';

/// Last team standing on the big screen: the question, whose turn it is and
/// this turn's prompt, and every team in turn order, crossed out once it is
/// out. At the end, the winner.
class StandingDisplay extends StatelessWidget {
  const StandingDisplay({super.key, required this.state, required this.question, required this.unit, required this.file});

  final SessionState state;
  final Question question;
  final double unit;

  /// A media file of the game on this device, if it is there.
  final File? Function(String? name) file;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final play = state.standing;
    if (play == null) return const SizedBox.shrink();
    final item = question.lastStanding?.itemAt(play.item);
    final current = play.current == null ? null : state.team(play.current!);
    final winner = play.winner == null ? null : state.team(play.winner!);
    final picture = winner == null ? file(item?.image) : null;
    final out = play.out;
    return Column(
      children: [
        // The question stays up, small, above what this turn is about.
        Text(
          question.text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: unit * 3.4, color: scheme.onSurfaceVariant),
        ),
        SizedBox(height: unit * 1.5),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(unit * 3),
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(unit * 3)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Column(
                key: ValueKey('${play.turns.length}/${winner?.id}'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (winner != null) ...[
                    Icon(Icons.emoji_events, size: unit * 12, color: Colors.amber),
                    Text(
                      winner.name,
                      style: TextStyle(fontSize: unit * 9, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      "is the last team standing",
                      style: TextStyle(fontSize: unit * 4, color: scheme.primary),
                    ),
                  ] else ...[
                    if (current != null)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: unit * 3, vertical: unit),
                        decoration: BoxDecoration(
                          color: teamColor(current) ?? scheme.primary,
                          borderRadius: BorderRadius.circular(unit * 4),
                        ),
                        child: Text(
                          "${current.name}'s turn",
                          style: TextStyle(
                            fontSize: unit * 4.5,
                            fontWeight: FontWeight.w700,
                            color: teamColor(current) == null ? scheme.onPrimary : onTeamColor(teamColor(current)!),
                          ),
                        ),
                      ),
                    if (item != null) ...[
                      SizedBox(height: unit * 3),
                      if (picture != null)
                        Flexible(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: unit * 2),
                            child: Image.file(picture, fit: BoxFit.contain),
                          ),
                        ),
                      Text(
                        item.question,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: unit * 8, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: unit * 2),
        // Everyone in turn order; the ones out fade and are crossed out.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: unit * 1.5,
          runSpacing: unit,
          children: [
            for (final id in play.order)
              if (state.team(id) case final team?)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: out.contains(id) ? 0.4 : 1,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: unit * 2, vertical: unit * 0.8),
                    decoration: BoxDecoration(
                      color: id == play.current || id == play.winner
                          ? (teamColor(team) ?? scheme.primaryContainer)
                          : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(unit * 2),
                      border: Border.all(color: id == play.current ? scheme.onSurface : Colors.transparent, width: unit * 0.3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (out.contains(id)) Icon(Icons.close, size: unit * 3, color: scheme.error),
                        if (id == play.winner) Icon(Icons.emoji_events, size: unit * 3, color: Colors.amber),
                        SizedBox(width: unit * 0.5),
                        Text(
                          team.name,
                          style: TextStyle(
                            fontSize: unit * 3,
                            fontWeight: FontWeight.w600,
                            decoration: out.contains(id) ? TextDecoration.lineThrough : null,
                            color: (id == play.current || id == play.winner) && teamColor(team) != null
                                ? onTeamColor(teamColor(team)!)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}
