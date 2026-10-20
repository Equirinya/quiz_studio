import 'package:flutter/material.dart';

import 'package:quiz_show/game/game.dart';

/// One labelled setting: what it is, what is set right now, and where a tap
/// leads. Easier to find and understand than a row of bare icons.
class SettingTile {
  const SettingTile({required this.icon, required this.title, required this.summary, required this.onTap, this.isSet = false});

  final IconData icon;
  final String title;

  /// What is set right now, in a few words.
  final String summary;
  final VoidCallback onTap;

  /// Something is set here, as opposed to the defaults.
  final bool isSet;
}

/// The settings of a game, board or category as a row of labelled tiles that
/// wraps on a narrow screen.
class SettingsStrip extends StatelessWidget {
  const SettingsStrip({super.key, required this.tiles});

  final List<SettingTile> tiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        // Two side by side on a phone, up to four on a wide screen.
        final columns = (box.maxWidth / 180).floor().clamp(1, 4);
        final width = (box.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: width,
                child: Material(
                  color: tile.isSet ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: tile.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(tile.icon, color: tile.isSet ? scheme.onSecondaryContainer : scheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tile.title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(
                                  tile.summary,
                                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "2 music, 3 effects"; [inherited] says what applies when nothing is set.
String soundsSummary(MusicConfig sounds, {required String inherited}) {
  final music = sounds.slots.length;
  final effects = sounds.effects.length;
  if (music == 0 && effects == 0) return inherited;
  return [
    if (music > 0) music == 1 ? "1 music" : "$music music",
    if (effects > 0) effects == 1 ? "1 effect" : "$effects effects",
  ].join(", ");
}

/// "12 offered, 2 off" for the game, "3 cards" for a board or category.
String cardsSummary(List<CueCard> cards, {String none = "None"}) {
  final off = cards.where((card) => card.hidden).length;
  final on = cards.length - off;
  if (cards.isEmpty) return none;
  return off == 0 ? (on == 1 ? "1 card" : "$on cards") : "$on offered, $off off";
}
