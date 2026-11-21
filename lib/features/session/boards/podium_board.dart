import 'package:flutter/material.dart';

import 'package:quiz_show/features/session/widgets/team_colors.dart';
import 'package:quiz_show/game/game.dart';

/// The podium on the big screen: the top three on steps, the first in the
/// middle, and the other teams in a row below with their places and points.
///
/// It comes up empty: the gamemaster unveils the places one by one from the
/// last up, or all at once ([shown] teams, counted from the last place).
class PodiumBoard extends StatelessWidget {
  const PodiumBoard({super.key, required this.teams, required this.unit, this.shown});

  final List<Team> teams;
  final double unit;

  /// How many teams are unveiled, from the last place up; null: all.
  final int? shown;

  @override
  Widget build(BuildContext context) {
    final places = podiumPlaces(teams);
    final revealed = {for (final (_, team) in places.reversed.take(shown ?? places.length)) team.id};
    final top = places.take(3).toList();
    final rest = places.skip(3).toList();
    // Second on the left, first in the middle, third on the right. Unveiled,
    // teams level on points stand as high as each other; before, the steps
    // give nothing away.
    double height(int place) => switch (place) {
      1 => 1.0,
      2 => 0.68,
      _ => 0.48,
    };
    (((int, Team), double), bool) step(int position) {
      final entry = top[position];
      final open = revealed.contains(entry.$2.id);
      return ((entry, height(open ? entry.$1 : position + 1)), open);
    }
    final steps = [
      if (top.length > 1) step(1),
      if (top.isNotEmpty) step(0),
      if (top.length > 2) step(2),
    ];
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (((place, team), height), open) in steps)
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: unit * 44),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: unit * 1),
                      child: _Step(key: ValueKey('podium-${team.id}'), place: place, team: team, height: height, unit: unit, open: open),
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
            children: [
              for (final (place, team) in rest)
                // Its room is kept, so nothing moves as it comes up.
                _Reveal(
                  open: revealed.contains(team.id),
                  child: _Rest(key: ValueKey('podium-${team.id}'), place: place, team: team, unit: unit),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Fades [child] in once [open], keeping its room before.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.open, required this.child});

  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: open ? 1 : 0,
    duration: const Duration(milliseconds: 500),
    curve: Curves.easeOut,
    child: child,
  );
}

/// Gold, silver and bronze for the steps.
Color _medal(int place) => switch (place) {
  1 => const Color(0xFFE8B931),
  2 => const Color(0xFFB4BCC5),
  _ => const Color(0xFFC2804A),
};

class _Step extends StatelessWidget {
  const _Step({super.key, required this.place, required this.team, required this.height, required this.unit, required this.open});

  final int place;
  final Team team;

  /// Unveiled: the team, its points and its place; before, a bare step.
  final bool open;

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
            _Reveal(
              open: open,
              child: Column(
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
                ],
              ),
            ),
            SizedBox(height: unit * 1.2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              height: tallest * height,
              alignment: Alignment.topCenter,
              padding: EdgeInsets.only(top: unit * 2),
              decoration: BoxDecoration(
                // Plain grey until its place is known.
                color: open ? medal : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.vertical(top: Radius.circular(unit * 1.6)),
              ),
              child: _Reveal(
                open: open,
                child: Text(
                  '$place',
                  style: TextStyle(fontSize: unit * 11, fontWeight: FontWeight.w800, color: onTeamColor(medal)),
                ),
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
