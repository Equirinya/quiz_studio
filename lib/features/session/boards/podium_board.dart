import 'package:flutter/material.dart';

import 'package:quiz_show/features/session/widgets/team_colors.dart';
import 'package:quiz_show/game/game.dart';

/// The podium on the big screen: the top three on steps, the first in the
/// middle, and the other teams in a row below with their places and points.
class PodiumBoard extends StatelessWidget {
  const PodiumBoard({super.key, required this.teams, required this.unit});

  final List<Team> teams;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final places = podiumPlaces(teams);
    final top = places.take(3).toList();
    final rest = places.skip(3).toList();
    // Second on the left, first in the middle, third on the right; teams
    // level on points stand as high as each other.
    double height(int place) => switch (place) {
      1 => 1.0,
      2 => 0.68,
      _ => 0.48,
    };
    final steps = [
      if (top.length > 1) (top[1], height(top[1].$1)),
      if (top.isNotEmpty) (top[0], height(top[0].$1)),
      if (top.length > 2) (top[2], height(top[2].$1)),
    ];
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final ((place, team), height) in steps)
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: unit * 44),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: unit * 1),
                      child: _Step(key: ValueKey('podium-${team.id}'), place: place, team: team, height: height, unit: unit),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (rest.isNotEmpty) ...[
          SizedBox(height: unit * 3),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: unit * 2,
            runSpacing: unit * 1.5,
            children: [for (final (place, team) in rest) _Rest(key: ValueKey('podium-${team.id}'), place: place, team: team, unit: unit)],
          ),
        ],
      ],
    );
  }
}

/// Gold, silver and bronze for the steps.
Color _medal(int place) => switch (place) {
  1 => const Color(0xFFE8B931),
  2 => const Color(0xFFB4BCC5),
  _ => const Color(0xFFC2804A),
};

class _Step extends StatelessWidget {
  const _Step({super.key, required this.place, required this.team, required this.height, required this.unit});

  final int place;
  final Team team;

  /// Of the tallest step, the first's.
  final double height;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final own = teamColor(team);
    final medal = _medal(place);
    return LayoutBuilder(
      builder: (context, box) {
        // Room above the tallest step for the cup, two lines of name and the
        // points.
        final tallest = (box.maxHeight - unit * 26).clamp(unit * 10, double.infinity);
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (place == 1) Icon(Icons.emoji_events, size: unit * 7, color: medal),
            Text(
              team.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: unit * 4.2, fontWeight: FontWeight.w700, height: 1.15, color: scheme.onSurface),
            ),
            SizedBox(height: unit * 0.6),
            Text(
              '${team.points}',
              style: TextStyle(fontSize: unit * 3.6, fontWeight: FontWeight.w600, color: own ?? scheme.primary),
            ),
            SizedBox(height: unit * 1.2),
            Container(
              height: tallest * height,
              alignment: Alignment.topCenter,
              padding: EdgeInsets.only(top: unit * 2),
              decoration: BoxDecoration(
                color: medal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(unit * 1.6)),
                // The team's own colour as a band along the top.
                border: own == null ? null : Border(top: BorderSide(color: own, width: unit * 1.2)),
              ),
              child: Text(
                '$place',
                style: TextStyle(fontSize: unit * 11, fontWeight: FontWeight.w800, color: onTeamColor(medal)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Rest extends StatelessWidget {
  const _Rest({super.key, required this.place, required this.team, required this.unit});

  final int place;
  final Team team;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final own = teamColor(team);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: unit * 2, vertical: unit * 1.2),
      decoration: BoxDecoration(
        color: own ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(unit * 1.4),
      ),
      child: DefaultTextStyle(
        style: TextStyle(fontSize: unit * 3, color: own == null ? scheme.onPrimaryContainer : onTeamColor(own)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$place.', style: const TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(width: unit * 1.2),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: unit * 30),
              child: Text(team.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            SizedBox(width: unit * 1.6),
            Text('${team.points}'),
          ],
        ),
      ),
    );
  }
}
