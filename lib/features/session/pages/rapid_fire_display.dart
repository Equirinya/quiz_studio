import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mini_music_visualizer/mini_music_visualizer.dart';

import 'package:quiz_show/features/session/pages/rapid_progress.dart';
import 'package:quiz_show/game/game.dart';

/// A Fragenhagel on the big screen: the item being asked, big, with its
/// picture and sound; which teams have picked (devices mode); and the
/// progress in the style the editor chose.
class RapidFireDisplay extends StatelessWidget {
  const RapidFireDisplay({super.key, required this.state, required this.question, required this.unit, required this.file});

  final SessionState state;
  final Question question;
  final double unit;

  /// The local copy of a media file of the game, when there is one.
  final File? Function(String? name) file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rapid = question.rapidFire ?? const RapidFire();
    final total = rapid.items.length;
    final done = state.revealed.clamp(0, total);
    final item = rapid.itemAt(state.revealed);
    final image = file(item?.image);
    final round = state.answerRound;
    final flux = rapid.progress == ProgressStyle.flux;

    final card = Container(
      width: double.infinity,
      padding: EdgeInsets.all(unit * 3),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(unit * 3)),
      // Each item slides in over the one before.
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.15, 0), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: item == null
            ? Column(
                key: const ValueKey('done'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, size: unit * 14, color: scheme.primary),
                  SizedBox(height: unit * 2),
                  Text("That was the last one!", style: TextStyle(fontSize: unit * 6, fontWeight: FontWeight.w600)),
                ],
              )
            : Row(
                key: ValueKey('item-$done'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (image != null)
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(right: unit * 3),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(unit * 2),
                          child: Image.file(image, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  if (item.music != null)
                    Padding(
                      padding: EdgeInsets.only(right: unit * 2),
                      child: MiniMusicVisualizer(
                        animate: state.media == MediaPlayback.playing,
                        color: scheme.primary,
                        width: unit * 1.5,
                        height: unit * 5,
                        radius: unit * 0.4,
                      ),
                    ),
                  Flexible(
                    child: Text(
                      item.question,
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: unit * 6),
                    ),
                  ),
                ],
              ),
      ),
    );

    // Buzzer mode moves fast: who is answering must be clear from across the room.
    final answering = state.phase == Phase.buzzered && state.buzzQueue.isNotEmpty ? state.team(state.buzzQueue.first) : null;
    final queued = [for (final id in state.buzzQueue.skip(1)) state.team(id)?.name ?? '?'];
    final banner = answering == null
        ? null
        : Container(
            key: ValueKey('buzz-${answering.id}-${state.revealed}'),
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: unit * 4, vertical: unit * 2),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(unit * 3),
              boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.6), blurRadius: unit * 4, spreadRadius: unit * 0.5)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_active, size: unit * 9, color: scheme.onPrimary),
                SizedBox(width: unit * 3),
                Flexible(
                  child: Text(
                    answering.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: unit * 9, fontWeight: FontWeight.w800, color: scheme.onPrimary),
                  ),
                ),
                if (queued.isNotEmpty) ...[
                  SizedBox(width: unit * 4),
                  Text(
                    "then ${queued.join(", ")}",
                    style: TextStyle(fontSize: unit * 3.2, color: scheme.onPrimary.withValues(alpha: 0.85)),
                  ),
                ],
              ],
            ),
          );

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: card),
                    // Pops up over the item the moment a team buzzes.
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.all(unit * 2),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) => ScaleTransition(
                            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                            child: child,
                          ),
                          child: banner ?? const SizedBox(key: ValueKey('no-buzz')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (flux)
                Padding(
                  padding: EdgeInsets.only(left: unit * 3),
                  child: RapidProgress(style: rapid.progress, done: done, total: total, unit: unit),
                ),
            ],
          ),
        ),
        // Devices mode: who has made up their mind, but not what they picked.
        if (round != null && item != null)
          Padding(
            padding: EdgeInsets.only(top: unit * 2),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: unit * 1.5,
              children: [
                for (final team in state.teams)
                  Chip(
                    avatar: Icon(
                      round.answers[team.id]?.locked == true
                          ? Icons.lock
                          : round.answers[team.id]?.choice != null
                              ? Icons.edit
                              : Icons.hourglass_empty,
                      size: unit * 2.8,
                    ),
                    label: Text(team.name, style: TextStyle(fontSize: unit * 2.6)),
                  ),
              ],
            ),
          ),
        if (!flux && rapid.progress != ProgressStyle.off)
          Padding(
            padding: EdgeInsets.only(top: unit * 3),
            child: RapidProgress(style: rapid.progress, done: done, total: total, unit: unit),
          ),
      ],
    );
  }
}
