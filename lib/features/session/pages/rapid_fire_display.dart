import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mini_music_visualizer/mini_music_visualizer.dart';

import 'package:quiz_show/features/session/pages/media_box.dart';
import 'package:quiz_show/features/session/pages/rapid_progress.dart';
import 'package:quiz_show/features/session/widgets/team_colors.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// A Fragenhagel on the big screen: the item being asked, big, with its
/// picture and sound; which teams have picked (devices mode); and the
/// progress in the style the editor chose.
class RapidFireDisplay extends StatelessWidget {
  const RapidFireDisplay({
    super.key,
    required this.state,
    required this.question,
    required this.unit,
    required this.file,
    this.onVideoEnd,
  });

  final SessionState state;
  final Question question;
  final double unit;

  /// The local copy of a media file of the game, when there is one.
  final File? Function(String? name) file;

  /// See [MediaBox.onVideoEnd].
  final VoidCallback? onVideoEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rapid = question.rapidFire ?? const RapidFire();
    final total = rapid.items.length;
    final done = state.revealed.clamp(0, total);
    final item = rapid.itemAt(state.revealed);
    final videoName = item == null ? null : question.videoAt(state.revealed, state.standing);
    final media = MediaBox(
      images: [for (final name in item?.images ?? const <String>[]) ?file(name)],
      unit: unit,
      videoName: videoName,
      video: file(videoName),
      playback: state.media,
      onVideoEnd: onVideoEnd,
      shown: (item?.media ?? MediaSet.empty).stepsThroughPictures ? state.imageFocus : null,
    );
    final image = !media.isEmpty;
    final flux = rapid.progress == ProgressStyle.flux;
    // Before the first item only the question itself is up, to be read out.
    final intro = state.revealed < 0;
    final heading = question.text.trim();
    // An item without text of its own is read out: the question itself
    // stays in its place, with the item's picture if it has one.
    final own = item != null && item.question.trim().isNotEmpty;
    final text = own ? item.question : heading;

    final Key itemKey = intro ? const ValueKey('intro') : item == null ? const ValueKey('done') : ValueKey('item-$done');
    final card = Container(
      width: double.infinity,
      padding: EdgeInsets.all(unit * 3),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(unit * 3)),
      // Each item comes in from the right while the one before leaves to
      // the left. The leaving one runs its animation backwards, so it
      // starts from the left.
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: Offset(child.key == itemKey ? 0.15 : -0.15, 0), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: intro
            ? Center(
                key: itemKey,
                child: Text(
                  heading,
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: unit * 7, fontWeight: FontWeight.w600),
                ),
              )
            : item == null
            ? Column(
                key: itemKey,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, size: unit * 14, color: scheme.primary),
                  SizedBox(height: unit * 2),
                  Text(context.l10n.thatWasTheLastOne, style: TextStyle(fontSize: unit * 6, fontWeight: FontWeight.w600)),
                ],
              )
            : LayoutBuilder(
                key: itemKey,
                builder: (context, box) {
                  final music = item.music != null && videoName == null;
                  // The item's text, with the bars of its sound right before it.
                  final itemText = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (music)
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
                      if (text.isNotEmpty)
                        Flexible(
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            // As wide as its lines, so the bars stay right beside it.
                            textWidthBasis: TextWidthBasis.longestLine,
                            style: TextStyle(fontSize: unit * 6),
                          ),
                        ),
                    ],
                  );
                  if (!image) return Center(child: itemText);
                  // As on a question: the text as wide as it needs, up to a
                  // share that grows with its length; the media get the rest.
                  final share = text.length <= 30 ? 0.3 : (text.length <= 80 ? 0.38 : 0.48);
                  final beside = text.isNotEmpty || music;
                  return Row(
                    // The picture as big as the box lets it be.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: beside ? media.aligned(Alignment.centerLeft) : media),
                      if (beside) ...[
                        SizedBox(width: unit * 3),
                        ConstrainedBox(
                          constraints: BoxConstraints.tightFor(width: box.maxWidth * share),
                          child: Center(child: itemText),
                        ),
                      ],
                    ],
                  );
                },
              ),
      ),
    );

    // Buzzer mode moves fast: who is answering must be clear from across the room.
    final answering = state.phase == Phase.buzzered && state.buzzQueue.isNotEmpty ? state.team(state.buzzQueue.first) : null;
    final queued = [for (final id in state.buzzQueue.skip(1)) state.team(id)?.name ?? '?'];
    final bannerColor = teamColor(answering) ?? scheme.primary;
    final onBanner = teamColor(answering) == null ? scheme.onPrimary : onTeamColor(bannerColor);
    final banner = answering == null
        ? null
        : Container(
            key: ValueKey('buzz-${answering.id}-${state.revealed}'),
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: unit * 4, vertical: unit * 2),
            decoration: BoxDecoration(
              color: bannerColor,
              borderRadius: BorderRadius.circular(unit * 3),
              boxShadow: [BoxShadow(color: bannerColor.withValues(alpha: 0.6), blurRadius: unit * 4, spreadRadius: unit * 0.5)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_active, size: unit * 9, color: onBanner),
                SizedBox(width: unit * 3),
                Flexible(
                  child: Text(
                    answering.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: unit * 9, fontWeight: FontWeight.w800, color: onBanner),
                  ),
                ),
                if (queued.isNotEmpty) ...[
                  SizedBox(width: unit * 4),
                  Text(
                    context.l10n.thenTeams(queued.join(", ")),
                    style: TextStyle(fontSize: unit * 3.2, color: onBanner.withValues(alpha: 0.85)),
                  ),
                ],
              ],
            ),
          );

    return Column(
      children: [
        // The question itself stays above its items.
        if (!intro && own && heading.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: unit * 2),
            child: Text(
              heading,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: unit * 4, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
            ),
          ),
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
        if (!flux && rapid.progress != ProgressStyle.off)
          Padding(
            padding: EdgeInsets.only(top: unit * 3),
            child: RapidProgress(style: rapid.progress, done: done, total: total, unit: unit),
          ),
      ],
    );
  }
}
