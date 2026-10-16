import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mini_music_visualizer/mini_music_visualizer.dart';

import 'package:quiz_show/features/companion/answer_view.dart';
import 'package:quiz_show/features/companion/connections.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/session/boards/map_board.dart';
import 'package:quiz_show/features/session/boards/wheel_board.dart';
import 'package:quiz_show/features/session/pages/screen_overlays.dart';
import 'package:quiz_show/features/session/pages/video_card.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/game/game.dart';

/// What the audience sees: scores, the board, and the open question as far
/// as the gamemaster has revealed it. Everything scales with the screen
/// height, so it reads the same on a laptop and on a projector.
class PresenterView extends StatelessWidget {
  const PresenterView({super.key, required this.connection, this.videoCards = false});

  final SessionConnection connection;

  /// Whether video cards are played. Off by default, so the view can be
  /// shown where there is no video player, as in tests.
  final bool videoCards;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([connection.state, connection.game]),
      builder: (context, _) {
        final state = connection.state.value;
        final game = connection.game.value;
        if (state == null) return const Center(child: CupertinoActivityIndicator());
        if (game == null) {
          return Center(child: Text("Waiting for a game…", style: Theme.of(context).textTheme.headlineSmall));
        }
        final group = game.group(state.groupId) ?? game.groups.firstOrNull;
        final base = Theme.of(context);
        // A group may bring its own colours; the whole screen follows them.
        final theme = group?.color == null
            ? base
            : ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Color(group!.color!),
                  tertiary: group.accentColor == null ? null : Color(group.accentColor!),
                  brightness: base.brightness,
                ),
              );
        final question = state.current == null ? null : game.question(state.current!);
        File? mediaFile(String name) {
          final file = MediaService.instance.localFile(game.id, name);
          return file.existsSync() ? file : null;
        }

        return Theme(
          data: theme,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _screen(state, game, group, question),
              // Cards and effects lie over whatever is on screen.
              CardOverlay(
                card: state.overlay,
                animation: state.cardAnimation,
                imageFile: mediaFile,
                // Only the presenting device plays video, and takes the card
                // off again when the clip is over.
                videoBuilder: connection.host == null || !videoCards
                    ? null
                    : (file) => VideoCard(
                          key: ValueKey(file.path),
                          file: file,
                          onFinished: () => connection.host?.dispatch(const HideCard()),
                        ),
              ),
              ScreenEffectLayer(effects: connection.host?.effects),
            ],
          ),
        );
      },
    );
  }

  Widget _screen(SessionState state, GameContent game, CategoryGroup? group, Question? question) {
    return Builder(
      builder: (context) => ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final unit = constraints.maxHeight / 100;
            return Padding(
              padding: EdgeInsets.all(unit * 2),
              child: Column(
                children: [
                  _Scores(state: state, unit: unit),
                  SizedBox(height: unit * 2),
                  Expanded(
                    child: question != null
                        ? QuestionDisplay(gameId: game.id, state: state, question: question, unit: unit)
                        : group == null
                        ? const SizedBox()
                        : group.type == BoardType.wheel
                        ? LayoutBuilder(
                            builder: (context, box) => WheelBoard(group: group, state: state, size: box.biggest),
                          )
                        : group.type == BoardType.map
                                        ? MapBoard(
                                            group: group,
                                            state: state,
                                            imageFile: (name) {
                                              final file = MediaService.instance.localFile(game.id, name);
                                              return file.existsSync() ? file : null;
                                            },
                                          )
                                        : _BoardGrid(group: group, state: state, unit: unit),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Scores extends StatelessWidget {
  const _Scores({required this.state, required this.unit});

  final SessionState state;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showQueue = state.phase == Phase.buzzered || state.phase == Phase.buzzerTest;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: unit,
      runSpacing: unit,
      children: [
        for (final team in state.teams)
          Builder(
            builder: (context) {
              final position = showQueue ? state.buzzQueue.indexOf(team.id) : -1;
              // The answering team stands out; queued teams fade towards the back.
              final color = position < 0
                  ? scheme.surfaceContainerHigh
                  : Color.lerp(scheme.primaryContainer, scheme.surfaceContainerHigh, position / state.buzzQueue.length)!;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: unit * 22,
                height: unit * 12,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(unit * 2)),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: unit * 2.2),
                    ),
                    Text(
                      team.points.toString(),
                      style: TextStyle(fontSize: unit * 4.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// A plain grid of categories and point fields, for groups without a board
/// of their own.
class _BoardGrid extends StatelessWidget {
  const _BoardGrid({required this.group, required this.state, required this.unit});

  final CategoryGroup group;
  final SessionState state;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (group.type == BoardType.display) {
      return Center(
        child: Text(
          group.text ?? group.name,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: unit * 7),
        ),
      );
    }
    final rows = group.categories.fold(0, (most, c) => c.questions.length > most ? c.questions.length : most);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in group.categories)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: unit * 0.6),
              child: Column(
                children: [
                  SizedBox(
                    height: unit * 8,
                    child: Center(
                      child: Text(
                        category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: unit * 2.8, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  for (var i = 0; i < rows; i++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final question = category.questions.elementAtOrNull(i);
                          if (question == null) return const SizedBox();
                          final played = state.played.contains(QuestionRef(category.id, question.id).key);
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: unit * 0.6),
                            decoration: BoxDecoration(
                              color: played ? scheme.surfaceContainerLow : scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(unit * 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              question.pointsPlus.toString(),
                              style: TextStyle(
                                fontSize: unit * 4,
                                fontWeight: FontWeight.w600,
                                color: played ? scheme.outlineVariant : scheme.onPrimaryContainer,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The open question as far as it is revealed. [unit] is a hundredth of the
/// screen's height.
class QuestionDisplay extends StatelessWidget {
  const QuestionDisplay({super.key, required this.gameId, required this.state, required this.question, required this.unit});

  final String gameId;
  final SessionState state;
  final Question question;
  final double unit;

  File? _file(String? name) {
    if (name == null || name.isEmpty || !MediaService.instance.ready) return null;
    final file = MediaService.instance.localFile(gameId, name);
    return file.existsSync() ? file : null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Progressing reveal can swap the question's image for a revealed one.
    final focused = question.type == QuestionType.progressingReveal && state.imageFocus > 0
        ? question.informationImages.elementAtOrNull(state.imageFocus - 1)
        : null;
    final image = _file(focused) ?? _file(question.image);
    final round = state.answerRound;
    if (question.type == QuestionType.connections) {
      return _ConnectionsDisplay(state: state, question: question, unit: unit);
    }
    final strip =
        state.thumbnails && round == null && question.type == QuestionType.progressingReveal && question.hasInformationImages;
    return Column(
      children: [
        if (question.description != null)
          Padding(
            padding: EdgeInsets.only(bottom: unit),
            child: Chip(
              label: Text(question.description!, style: TextStyle(fontSize: unit * 2.4)),
            ),
          ),
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(unit * 2),
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(unit * 3)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (image != null)
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(right: unit * 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(unit * 2),
                        child: Image.file(image, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                if (question.hasMusic)
                  Padding(
                    padding: EdgeInsets.only(right: unit * 2),
                    // Bars that dance while the sound plays and stand still otherwise.
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
                    question.text,
                    textAlign: TextAlign.center,
                    maxLines: image == null ? 6 : 8,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: unit * 4.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (strip)
          Padding(
            padding: EdgeInsets.only(top: unit * 1.5),
            child: _PictureStrip(
              unit: unit,
              files: [for (final name in question.informationImages) _file(name)],
              names: question.informationImages,
              revealed: state.revealed,
              focus: state.imageFocus,
            ),
          ),
        SizedBox(height: unit * 2),
        if (round != null)
          Expanded(
            flex: 3,
            child: _AnswerRoundDisplay(
              state: state,
              round: round,
              unit: unit,
              backgroundImage: _file(round.spec.backgroundImage) == null ? null : FileImage(_file(round.spec.backgroundImage)!),
            ),
          )
        else
          switch (question.type) {
            QuestionType.abcd => Expanded(
              flex: 2,
              child: _Tiles(
                unit: unit,
                columns: 2,
                tiles: [
                  for (final (i, answer) in question.answers.indexed)
                    (
                      label: String.fromCharCode(0x41 + i),
                      text: answer,
                      shown: i < state.revealed,
                      mark: state.revealed > question.answers.length ? question.answersCorrect.elementAtOrNull(i) ?? false : null,
                    ),
                ],
              ),
            ),
            // Pictures only: the strip above says it all.
            QuestionType.progressingReveal when strip && question.information.every((text) => text.trim().isEmpty) =>
              const SizedBox(),
            QuestionType.progressingReveal => Expanded(
              flex: 2,
              child: _Tiles(
                unit: unit,
                tiles: [
                  for (final (i, information) in question.information.indexed)
                    (label: "${i + 1}", text: information, shown: i < state.revealed, mark: null),
                ],
              ),
            ),
            QuestionType.feud => Expanded(
              flex: 3,
              child: Column(
                children: [
                  SizedBox(
                    height: unit * 6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [for (var i = 0; i < state.wrongAttempts; i++) Icon(Icons.close, color: scheme.error, size: unit * 6)],
                    ),
                  ),
                  Expanded(
                    child: _Tiles(
                      unit: unit,
                      columns: question.information.length <= 5 ? 1 : 2,
                      tiles: [
                        for (final (i, information) in question.information.indexed)
                          (
                            // The value is part of what gets uncovered.
                            label: state.feudRevealed.contains(i) ? _feudValue(question, i) : "",
                            text: information,
                            shown: state.feudRevealed.contains(i),
                            mark: null,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _ => const Spacer(),
          },
      ],
    );
  }


  static String _feudValue(Question question, int index) {
    final value = question.percentages.elementAtOrNull(index) ?? 0;
    final text = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
    return question.absoluteValues ? text : "$text%";
  }
}

/// Connections on the big screen: the sixteen words as the teams see them,
/// the groups the gamemaster has revealed, and how far every team has got.
class _ConnectionsDisplay extends StatelessWidget {
  const _ConnectionsDisplay({required this.state, required this.question, required this.unit});

  final SessionState state;
  final Question question;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spec = question.companion!;
    final order = connectionsOrder(state.current?.key ?? '');
    final words = [for (final index in order) spec.wordAt(index)];
    final revealed = state.revealed.clamp(0, kConnectionsGroups);
    final round = state.answerRound;
    return Column(
      children: [
        Text(
          question.text.isEmpty ? "Find four groups of four" : question.text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: unit * 3.6, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: unit * 1.2),
        if (round != null && round.open && round.endsAtMillis != null)
          Padding(
            padding: EdgeInsets.only(bottom: unit * 1.2),
            child: RoundCountdown(openedAt: round.openedAtMillis, endsAt: round.endsAtMillis!, hostClock: true, height: unit * 1.4),
          ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 2.3,
              child: ConnectionsGrid(
                words: words,
                groups: [for (var level = 0; level < revealed; level++) GridGroup.fromSpec(spec, level, order)],
                gap: unit * 1.2,
                fontSize: unit * 3,
              ),
            ),
          ),
        ),
        if (round != null) ...[
          SizedBox(height: unit * 1.5),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: unit * 1.5,
            runSpacing: unit,
            children: [
              for (final team in state.teams)
                Builder(builder: (context) {
                  final answer = round.answers[team.id];
                  final progress = answer?.connections ?? const ConnectionsProgress();
                  final took = answer?.secondsTaken(round);
                  final done = progress.finished(spec) || answer?.locked == true;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(horizontal: unit * 2, vertical: unit * 1),
                    decoration: BoxDecoration(
                      color: progress.solved.length == kConnectionsGroups ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(unit * 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(team.name, style: TextStyle(fontSize: unit * 3.2, fontWeight: FontWeight.w700)),
                        SizedBox(width: unit * 1.5),
                        ConnectionsProgressRow(
                          solved: progress.solved,
                          mistakes: progress.mistakes,
                          allowed: spec.mistakes,
                          size: unit * 3.2,
                        ),
                        if (done && took != null) ...[
                          SizedBox(width: unit),
                          Text("${took.toStringAsFixed(1)} s", style: TextStyle(fontSize: unit * 2.6, color: scheme.outline)),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ],
      ],
    );
  }
}

/// The pictures of a progressing reveal in a row: the ones revealed so far
/// in small, a question mark for each still to come, and a frame around the
/// one that is shown big.
class _PictureStrip extends StatelessWidget {
  const _PictureStrip({required this.unit, required this.files, required this.names, required this.revealed, required this.focus});

  final double unit;

  /// One per step; null where the step has no picture or the file is missing.
  final List<File?> files;
  final List<String> names;
  final int revealed;

  /// 1-based; 0 for none.
  final int focus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final count = names.length;
        // As v1 had them: never wider than a seventh of the screen.
        final width = ((box.maxWidth - unit * count) / (count < 7 ? 7 : count)).clamp(0.0, unit * 22);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              if (names[i].isNotEmpty)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(horizontal: unit * 0.5),
                  width: width,
                  height: width * 9 / 16,
                  clipBehavior: Clip.antiAlias,
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(unit * 1.2),
                    border: Border.all(width: unit * 0.4, color: focus == i + 1 ? scheme.primary : Colors.transparent),
                  ),
                  decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(unit * 1.2)),
                  child: i < revealed && files[i] != null
                      ? Image.file(files[i]!, fit: BoxFit.cover)
                      : Center(
                          child: Text(
                            i < revealed ? "${i + 1}" : "?",
                            style: TextStyle(fontSize: width * 0.22, fontWeight: FontWeight.w600, color: scheme.outline),
                          ),
                        ),
                ),
          ],
        );
      },
    );
  }
}

typedef _Tile = ({String label, String text, bool shown, bool? mark});

/// A grid of answer tiles; a tile keeps its place while it is still hidden.
class _Tiles extends StatelessWidget {
  const _Tiles({required this.tiles, required this.unit, this.columns});

  final List<_Tile> tiles;
  final double unit;
  final int? columns;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (tiles.isEmpty) return const SizedBox();
    final perRow = columns ?? (tiles.length <= 3 ? tiles.length : (tiles.length / 2).ceil());
    final rows = (tiles.length / perRow).ceil();
    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < perRow; c++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final tile = tiles.elementAtOrNull(r * perRow + c);
                        if (tile == null) return const SizedBox();
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: tile.shown ? 1 : 0.25,
                          child: Container(
                            margin: EdgeInsets.all(unit * 0.6),
                            padding: EdgeInsets.symmetric(horizontal: unit * 2),
                            decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(unit * 1.5)),
                            child: Row(
                              children: [
                                Text(
                                  tile.label,
                                  style: TextStyle(fontSize: unit * 3, fontWeight: FontWeight.bold, color: scheme.tertiary),
                                ),
                                SizedBox(width: unit * 2),
                                Expanded(
                                  child: Text(
                                    tile.shown ? tile.text : "",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: unit * 3),
                                  ),
                                ),
                                if (tile.mark != null)
                                  Icon(
                                    tile.mark! ? Icons.check : Icons.close,
                                    size: unit * 4,
                                    color: tile.mark! ? Colors.green : scheme.error,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// An answer round on the big screen: who is still writing, how much time is
/// left, and the answers the gamemaster has shown so far, each with its
/// ruling once there is one.
class _AnswerRoundDisplay extends StatelessWidget {
  const _AnswerRoundDisplay({required this.state, required this.round, required this.unit, this.backgroundImage});

  final ImageProvider? backgroundImage;

  final SessionState state;
  final AnswerRound round;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = [
      for (final teamId in round.revealed)
        if (state.team(teamId) != null) state.team(teamId)!,
    ];
    return Column(
      children: [
        // The presenter runs the show, so the deadline is on its own clock.
        if (round.open && round.endsAtMillis != null)
          Padding(
            padding: EdgeInsets.only(bottom: unit * 1.5),
            child: RoundCountdown(openedAt: round.openedAtMillis, endsAt: round.endsAtMillis!, hostClock: true, height: unit * 1.6),
          ),
        if (shown.isEmpty)
          Expanded(
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: unit * 1.5,
                runSpacing: unit * 1.5,
                children: [
                  for (final team in state.teams)
                    Builder(builder: (context) {
                      final answer = round.answers[team.id];
                      final done = answer?.locked == true || (!round.open && answer != null && !answer.isEmpty);
                      final writing = answer != null && !answer.isEmpty;
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: unit * 3, vertical: unit * 1.5),
                        decoration: BoxDecoration(
                          color: done ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(unit * 2),
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
                              size: unit * 3.5,
                              color: done ? scheme.onPrimaryContainer : scheme.outline,
                            ),
                            SizedBox(width: unit * 1.5),
                            Text(team.name, style: TextStyle(fontSize: unit * 3.2, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final team in shown)
                  Expanded(
                    child: Builder(builder: (context) {
                      final verdict = round.verdicts[team.id];
                      final awarded = round.awarded[team.id];
                      final took = round.answers[team.id]?.secondsTaken(round);
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: unit * 0.8),
                        padding: EdgeInsets.all(unit * 1.5),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(unit * 2),
                          border: Border.all(
                            width: unit * 0.5,
                            color: verdict == null
                                ? Colors.transparent
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
                                if (took != null)
                                  Text(
                                    "  ${took.toStringAsFixed(1)} s",
                                    style: TextStyle(fontSize: unit * 2.2, color: scheme.outline),
                                  ),
                                if (verdict != null) ...[
                                  SizedBox(width: unit),
                                  Icon(
                                    verdict ? Icons.check_circle : Icons.cancel,
                                    size: unit * 3.2,
                                    color: verdict ? Colors.green : scheme.error,
                                  ),
                                  if (awarded != null && awarded != 0)
                                    Text(
                                      " ${awarded > 0 ? "+" : ""}$awarded",
                                      style: TextStyle(fontSize: unit * 2.6, fontWeight: FontWeight.w700),
                                    ),
                                ],
                              ],
                            ),
                            SizedBox(height: unit),
                            Expanded(
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: unit * 60),
                                    child: SizedBox(
                                      // Wide enough to fill the tile; an upright
                                      // board is scaled down to its height.
                                      width: round.kind == CompanionKind.whiteboard
                                          ? unit * 60 * (drawingAspect(round.answers[team.id]?.drawing) < 1 ? 0.6 : 1)
                                          : null,
                                      child: AnswerView(
                                        spec: round.spec,
                                        answer: round.answers[team.id],
                                        fontSize: unit * 3.4,
                                        backgroundImage: backgroundImage,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
