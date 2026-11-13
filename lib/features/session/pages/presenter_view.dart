import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mini_music_visualizer/mini_music_visualizer.dart';

import 'package:quiz_show/features/companion/answer_view.dart';
import 'package:quiz_show/features/companion/connections.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/session/boards/map_board.dart';
import 'package:quiz_show/features/session/boards/wheel_board.dart';
import 'package:quiz_show/features/session/pages/ordering_display.dart';
import 'package:quiz_show/features/session/pages/screen_overlays.dart';
import 'package:quiz_show/features/session/pages/standing_display.dart';
import 'package:quiz_show/features/session/pages/video_card.dart';
import 'package:quiz_show/features/session/session_connection.dart';
import 'package:quiz_show/features/session/widgets/score_pop.dart';
import 'package:quiz_show/features/session/widgets/team_colors.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/features/session/pages/rapid_fire_display.dart';
import 'package:quiz_show/l10n/l10n.dart';

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
          return Center(child: Text(context.l10n.waitingForGame, style: Theme.of(context).textTheme.headlineSmall));
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
                videoBuilder: !videoCards
                    ? null
                    : (file) => VideoCard(
                          key: ValueKey(file.path),
                          file: file,
                          onFinished: () => connection.send(const HideCard()),
                        ),
              ),
              ScreenEffectLayer(effects: connection.effects),
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
                  _Scores(state: state, unit: unit, question: question),
                  // The question's own clock, when the devices have none.
                  if (state.timer case final timer? when timer.running && state.answerRound == null)
                    Padding(
                      padding: EdgeInsets.only(top: unit * 1.5),
                      child: RoundCountdown(
                        openedAt: timer.openedAtMillis,
                        endsAt: timer.endsAtMillis,
                        hostClock: true,
                        height: unit * 1.6,
                      ),
                    ),
                  SizedBox(height: unit * 2),
                  Expanded(
                    child: question != null && state.waitingForBets
                        ? BettingDisplay(
                            state: state,
                            category: game.category(state.current!.categoryId)?.name,
                            question: question,
                            unit: unit,
                          )
                        : question != null
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
  const _Scores({required this.state, required this.unit, this.question});

  final SessionState state;
  final double unit;
  final Question? question;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showQueue = state.phase == Phase.buzzered || state.phase == Phase.buzzerTest;
    // Bets go up once they are closed, for as long as the question is open.
    // While the bets are revealed big they stay out of the score boxes.
    final bets = state.betting != null && !state.waitingForBets ? state.betting!.bets : null;
    // Teams scoring together pop up one after another, in the order they scored.
    final popOrder = <String>[];
    for (final change in state.scoreLog.reversed) {
      if (popOrder.contains(change.teamId)) break;
      popOrder.insert(0, change.teamId);
    }
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
              // A team with its own colour always shows it, brightest while it answers.
              final own = teamColor(team);
              final color = own != null
                  ? (position < 0 || position == 0 ? own : Color.lerp(own, scheme.surfaceContainerHigh, 0.4)!)
                  : position < 0
                      ? scheme.surfaceContainerHigh
                      : Color.lerp(scheme.primaryContainer, scheme.surfaceContainerHigh, position / state.buzzQueue.length)!;
              final text = own == null ? null : onTeamColor(color);
              final box = AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: unit * 22,
                height: unit * (bets == null ? 12 : 14),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(unit * 2),
                  border: own != null && position == 0 ? Border.all(color: scheme.onSurface, width: unit * 0.5) : null,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: unit * 2.2, color: text),
                    ),
                    Text(
                      team.points.toString(),
                      style: TextStyle(fontSize: unit * 4.5, fontWeight: FontWeight.w600, color: text),
                    ),
                    if (bets != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            question?.amountBet == null ? context.l10n.betValue(bets[team.id] ?? 0) : context.l10n.goalValue(bets[team.id] ?? 0),
                            style: TextStyle(fontSize: unit * 2.2, fontWeight: FontWeight.w600, color: text ?? scheme.primary),
                          ),
                          // Amount bets: reached or missed, once judged.
                          if (question?.amountBet != null && state.results.verdicts[team.id] != null)
                            Padding(
                              padding: EdgeInsets.only(left: unit * 0.5),
                              child: Icon(
                                state.results.verdicts[team.id]! ? Icons.check_circle : Icons.cancel,
                                size: unit * 2.4,
                                color: text ?? (state.results.verdicts[team.id]! ? Colors.green.shade400 : scheme.error),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              );
              // What the team just got pops up under its box for a moment.
              return ScorePop(
                teamId: team.id,
                log: state.scoreLog,
                size: unit * 3.2,
                delay: Duration(milliseconds: 350 * (popOrder.indexOf(team.id).clamp(0, 99))),
                child: box,
              );
            },
          ),
      ],
    );
  }
}

/// While teams bet on a question: its category or bet question, and which
/// teams have bet, never how much. Once the bets are closed: every team's
/// bet, big, until the question starts.
class BettingDisplay extends StatelessWidget {
  const BettingDisplay({super.key, required this.state, required this.unit, this.category, this.question});

  final SessionState state;
  final String? category;
  final double unit;

  /// For bets on an amount: its bet question and points.
  final Question? question;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bets = state.betting?.bets ?? const {};
    final amount = question?.amountBet;
    final prompt = amount?.prompt.trim() ?? '';
    final shown = state.betsShown;
    // Many teams: smaller cards and no dice, so every bet still fits.
    final count = state.teams.length;
    final card = unit * (count <= 5 ? 1.0 : (count <= 12 ? 0.85 : 0.6));
    // Even rows: twelve teams are two rows of six, not eleven and one.
    final perRow = count <= 7 ? count : (count / (count / 7).ceil()).ceil();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(unit * 3),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(unit * 3)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // One line on top: what is being bet on.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.casino_outlined, size: unit * 6, color: scheme.primary),
              SizedBox(width: unit * 1.5),
              Flexible(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: prompt.isNotEmpty ? prompt : (amount != null ? context.l10n.howManyCanYouDo : (shown ? context.l10n.theBets : context.l10n.placeYourBets))),
                    if (amount == null && category != null)
                      TextSpan(text: "  ·  ${category!}", style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w500)),
                  ]),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: unit * 6, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: unit * 3),
          if (shown)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: perRow * card * 24 + (perRow - 1) * card * 2.5 + 1),
              child: Wrap(
              alignment: WrapAlignment.center,
              spacing: card * 2.5,
              runSpacing: card * 2,
              children: [
                for (final (index, team) in state.teams.indexed)
                  // One after the other, each with a little bounce.
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 450 + 250 * index),
                    curve: Interval(index / (state.teams.length + 1), 1, curve: Curves.easeOutBack),
                    builder: (context, t, child) => Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
                    ),
                    child: Container(
                      width: card * 24,
                      padding: EdgeInsets.symmetric(vertical: card * 2, horizontal: card),
                      decoration: BoxDecoration(
                        color: teamColor(team) ?? scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(card * 2.5),
                      ),
                      child: Column(
                        children: [
                          Text(
                            team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: unit * (count <= 8 ? 3.2 : 2.6),
                              color: teamColor(team) == null ? scheme.onPrimaryContainer : onTeamColor(teamColor(team)!),
                            ),
                          ),
                          Text(
                            "${bets[team.id] ?? 0}",
                            style: TextStyle(
                              fontSize: card * 10,
                              fontWeight: FontWeight.w800,
                              color: teamColor(team) == null ? scheme.onPrimaryContainer : onTeamColor(teamColor(team)!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              ),
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: unit * 2,
              runSpacing: unit,
              children: [
                for (final team in state.teams)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: EdgeInsets.symmetric(horizontal: unit * 2, vertical: unit),
                    decoration: BoxDecoration(
                      color: bets.containsKey(team.id) ? scheme.primaryContainer : scheme.surface,
                      borderRadius: BorderRadius.circular(unit * 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          bets.containsKey(team.id) ? Icons.check_circle : Icons.hourglass_empty,
                          size: unit * 3.5,
                          color: bets.containsKey(team.id) ? scheme.primary : scheme.outline,
                        ),
                        SizedBox(width: unit),
                        Text(team.name, style: TextStyle(fontSize: unit * 3.2)),
                      ],
                    ),
                  ),
              ],
            ),
          // The rule, small, under the bets.
          Padding(
            padding: EdgeInsets.only(top: unit * 3),
            child: Text(
              amount == null
                  ? context.l10n.betRule
                  : question!.pointsMinus > 0
                  ? context.l10n.amountRuleWithMinus(question!.pointsPlus, question!.pointsMinus)
                  : context.l10n.amountRule(question!.pointsPlus),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: unit * 2.8, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
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
                              question.boardPoints.toString(),
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
    if (question.type == QuestionType.rapidFire) {
      return RapidFireDisplay(state: state, question: question, unit: unit, file: _file);
    }
    if (question.type == QuestionType.lastStanding) {
      return StandingDisplay(state: state, question: question, unit: unit, file: _file);
    }
    if (question.type == QuestionType.progressingReveal && round == null) {
      return _RevealDisplay(state: state, question: question, unit: unit, file: _file);
    }
    final strip =
        question.pictureStrip && round == null && question.type == QuestionType.progressingReveal && question.hasInformationImages;
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
          // Matching gives the room to its pieces.
          flex: question.type == QuestionType.matching || question.type == QuestionType.ordering ? 2 : 3,
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
        // Matching: the pieces to put together.
        if (question.type == QuestionType.matching)
          Expanded(
            flex: 7,
            child: Padding(
              padding: EdgeInsets.only(top: unit * 1.5),
              child: _MatchingBoard(question: question, unit: unit, file: _file),
            ),
          ),
        // Put in order: the entries, mixed up, then put in place.
        if (question.type == QuestionType.ordering)
          Expanded(
            flex: 7,
            child: Padding(
              padding: EdgeInsets.only(top: unit * 1.5),
              child: OrderingBoard(state: state, question: question, unit: unit, file: _file),
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
        // Top answers: the list takes over once its first answer is uncovered.
        if (question.type == QuestionType.topAnswers && (round == null || state.feudRevealed.isNotEmpty))
          Expanded(flex: 4, child: _TopAnswersBoard(state: state, question: question, unit: unit))
        else if (round != null)
          Expanded(
            flex: 3,
            child: _AnswerRoundDisplay(
              state: state,
              round: round,
              unit: unit,
              places: question.byCloseness ? closenessPlaces(state) : const {},
              backgroundImage: _file(round.spec.backgroundImage) == null ? null : FileImage(_file(round.spec.backgroundImage)!),
            ),
          )
        else
          switch (question.type) {
            QuestionType.abcd => Expanded(
              flex: 2,
              child: _Tiles(
                unit: unit,
                // Up to four answers two by two, more three by three.
                columns: question.answers.length <= 4 ? 2 : 3,
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

/// Progressing reveal on the big screen. With pictures, the newest one shown
/// takes nearly the whole screen, the question above it in one line and the
/// strip of all pictures below. With hints only, the question stays small and
/// the hints get the room, in a grid that fits them all.
class _RevealDisplay extends StatelessWidget {
  const _RevealDisplay({required this.state, required this.question, required this.unit, required this.file});

  final SessionState state;
  final Question question;
  final double unit;
  final File? Function(String? name) file;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final infos = question.information;
    final shown = state.revealed.clamp(0, infos.length);
    final focus = state.imageFocus;
    final focused = focus > 0 ? file(question.informationImages.elementAtOrNull(focus - 1)) : null;
    final caption = focus > 0 ? (infos.elementAtOrNull(focus - 1) ?? '').trim() : '';
    final pictures = question.hasInformationImages;
    final strip = pictures && question.pictureStrip;
    final mainImage = file(question.image);

    // The question, with the bars that dance while its sound plays.
    Widget questionText(double size, int lines) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (question.hasMusic)
              Padding(
                padding: EdgeInsets.only(right: size * 0.5),
                child: MiniMusicVisualizer(
                  animate: state.media == MediaPlayback.playing,
                  color: scheme.primary,
                  width: size * 0.3,
                  height: size,
                  radius: size * 0.08,
                ),
              ),
            Flexible(
              child: Text(
                question.text,
                textAlign: TextAlign.center,
                maxLines: lines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: size, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );

    final picturesStrip = strip
        ? Padding(
            padding: EdgeInsets.only(top: unit * 1.5),
            child: _PictureStrip(
              unit: unit,
              files: [for (final name in question.informationImages) file(name)],
              names: question.informationImages,
              revealed: state.revealed,
              focus: focus,
            ),
          )
        : const SizedBox();

    // The newest picture, nearly full screen.
    if (focused != null) {
      return Column(
        children: [
          questionText(unit * 3.2, 1),
          SizedBox(height: unit),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(unit * 2),
              child: Image.file(focused, fit: BoxFit.contain),
            ),
          ),
          if (caption.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: unit),
              child: Text(caption, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: unit * 3.2)),
            ),
          picturesStrip,
        ],
      );
    }

    final texts = [for (final info in infos) info.trim()];
    final hasTexts = texts.any((t) => t.isNotEmpty);
    // About as many columns as rows, never more than four: hints stay wide
    // enough to read in two or three lines.
    final int columns = texts.isEmpty ? 1 : sqrt(texts.length).ceil().clamp(1, 4).toInt();
    final rows = texts.isEmpty ? 1 : (texts.length / columns).ceil();
    return Column(
      children: [
        if (question.description != null)
          Padding(
            padding: EdgeInsets.only(bottom: unit),
            child: Chip(label: Text(question.description!, style: TextStyle(fontSize: unit * 2.4))),
          ),
        Flexible(
          flex: 2,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: unit * 3, vertical: unit * 1.5),
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(unit * 3)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (mainImage != null)
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(right: unit * 2),
                      child: ClipRRect(borderRadius: BorderRadius.circular(unit * 2), child: Image.file(mainImage, fit: BoxFit.contain)),
                    ),
                  ),
                Flexible(flex: 2, child: Center(child: questionText(unit * 4, 3))),
              ],
            ),
          ),
        ),
        SizedBox(height: unit * 1.5),
        if (hasTexts)
          Expanded(
            flex: 5,
            child: Column(
              children: [
                for (var r = 0; r < rows; r++)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var c = 0; c < columns; c++)
                          Expanded(
                            child: Builder(builder: (context) {
                              final i = r * columns + c;
                              if (i >= texts.length) return const SizedBox();
                              final visible = i < shown;
                              return AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity: visible ? 1 : 0.3,
                                child: Container(
                                  margin: EdgeInsets.all(unit * 0.6),
                                  padding: EdgeInsets.symmetric(horizontal: unit * 2, vertical: unit),
                                  decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(unit * 1.5)),
                                  child: Row(
                                    children: [
                                      Text("${i + 1}", style: TextStyle(fontSize: unit * 2.6, fontWeight: FontWeight.bold, color: scheme.tertiary)),
                                      SizedBox(width: unit * 1.5),
                                      Expanded(
                                        // Long hints shrink to fit rather than being cut off.
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(maxWidth: unit * 160 / columns),
                                            child: Text(
                                              visible ? texts[i] : "",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontSize: unit * 3.2, height: 1.2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          )
        else
          const Spacer(),
        picturesStrip,
      ],
    );
  }
}

/// Top answers on the big screen: numbered bars, uncovered one by one, each
/// with its points and the teams that found it.
class _TopAnswersBoard extends StatelessWidget {
  const _TopAnswersBoard({required this.state, required this.question, required this.unit});

  final SessionState state;
  final Question question;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = question.topAnswers ?? const TopAnswers();
    final items = top.items;
    if (items.isEmpty) return const SizedBox();
    final round = state.answerRound;
    final columns = items.length <= 6 ? 1 : 2;
    final perColumn = (items.length / columns).ceil();
    Widget bar(int i) {
      final shown = state.feudRevealed.contains(i);
      final finders = [
        if (state.foundBy[i] != null) ?state.team(state.foundBy[i]!),
        for (final team in state.teams)
          if (round?.found[team.id]?.contains(i) == true) team,
      ];
      return Padding(
        padding: EdgeInsets.all(unit * 0.5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          padding: EdgeInsets.symmetric(horizontal: unit * 2),
          decoration: BoxDecoration(
            color: shown ? scheme.primaryContainer : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(unit * 1.5),
          ),
          child: Row(
            children: [
              Text("${i + 1}", style: TextStyle(fontSize: unit * 3, fontWeight: FontWeight.w800, color: scheme.tertiary)),
              SizedBox(width: unit * 2),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(animation), child: child),
                  ),
                  layoutBuilder: (current, previous) => Stack(alignment: Alignment.center, children: [...previous, ?current]),
                  child: shown
                      ? Text(
                          items[i].answer.split(RegExp(r'[/|;]')).first.trim(),
                          key: const ValueKey('shown'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: unit * 3, fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer),
                        )
                      : const SizedBox(key: ValueKey('covered')),
                ),
              ),
              if (shown)
                for (final team in finders)
                  Padding(
                    padding: EdgeInsets.only(left: unit),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: unit * 1.2, vertical: unit * 0.4),
                      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(unit)),
                      child: Text(team.name, style: TextStyle(fontSize: unit * 1.9, color: scheme.onPrimary, fontWeight: FontWeight.w600)),
                    ),
                  ),
              if (shown) ...[
                SizedBox(width: unit * 1.5),
                Text(
                  "${top.pointsOf(i, question.pointsPlus)}",
                  style: TextStyle(fontSize: unit * 3, fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var c = 0; c < columns; c++)
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < perColumn; r++)
                  Expanded(child: c * perColumn + r < items.length ? bar(c * perColumn + r) : const SizedBox()),
              ],
            ),
          ),
      ],
    );
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
          question.text.isEmpty ? context.l10n.findFourGroups : question.text,
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
/// The two sides of a matching question: the left items in their order, the
/// right ones shuffled. Every picture of a row gets the same square, and the
/// texts one size, small enough for the longest word to fit.
class _MatchingBoard extends StatelessWidget {
  const _MatchingBoard({required this.question, required this.unit, required this.file});

  final Question question;
  final double unit;
  final File? Function(String? name) file;

  @override
  Widget build(BuildContext context) {
    final matching = question.matching ?? const Matching();
    final numbers = matching.rightNumbers(question.id);
    final right = [for (var i = 0; i < matching.pairs.length; i++) (numbers[i], matching.pairs[i].right)]
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final top = [for (final pair in matching.pairs) pair.left];
    final bottom = [for (final (_, side) in right) side];
    return LayoutBuilder(
      builder: (context, box) {
        final inner = box.maxWidth / (top.isEmpty ? 1 : top.length) - 2 * (_margin + _padding);
        // One text size for the whole board, small enough that no word is
        // broken in the middle.
        var fontSize = [...top, ...bottom].any((side) => side.image != null) ? unit * 2.8 : unit * 3.6;
        final base = DefaultTextStyle.of(context).style;
        double widest = 0;
        for (final side in [...top, ...bottom]) {
          for (final word in side.text.split(RegExp(r'\s+'))) {
            final painter = TextPainter(
              text: TextSpan(text: word, style: base.copyWith(fontSize: fontSize, height: 1.2)),
              textDirection: TextDirection.ltr,
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            if (painter.width > widest) widest = painter.width;
            painter.dispose();
          }
        }
        // A little room to spare: the measure and the real line differ slightly.
        if (widest > inner * 0.92 && widest > 0) fontSize *= inner * 0.92 / widest;
        return Column(
          children: [
            Expanded(child: _row(top, fontSize, context)),
            SizedBox(height: unit * 1.5),
            Expanded(child: _row(bottom, fontSize, context)),
          ],
        );
      },
    );
  }

  double get _margin => unit * 0.6;
  double get _padding => unit;

  Widget _row(List<MatchSide> sides, double fontSize, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pictures = sides.any((side) => side.image != null);
    final texts = sides.any((side) => side.text.isNotEmpty);
    return LayoutBuilder(
      builder: (context, box) {
        final margin = _margin;
        final padding = _padding;
        final inner = box.maxWidth / sides.length - 2 * (margin + padding);
        final textHeight = texts ? fontSize * 1.3 * 2 + unit * 0.6 : 0.0;
        final square = pictures ? (box.maxHeight - 2 * padding - textHeight).clamp(0.0, inner).toDouble() : 0.0;
        return Row(
          children: [
            for (final side in sides)
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: margin),
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(unit * 2)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (pictures)
                        SizedBox.square(
                          dimension: square,
                          child: file(side.image) != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(unit * 1.2),
                                  child: Image.file(file(side.image)!, fit: BoxFit.cover),
                                )
                              : side.image != null
                              ? Icon(Icons.image_outlined, size: square * 0.5, color: scheme.outline)
                              : null,
                        ),
                      if (texts)
                        SizedBox(
                          height: textHeight,
                          child: Align(
                            alignment: pictures ? Alignment.topCenter : Alignment.center,
                            child: Padding(
                              padding: EdgeInsets.only(top: pictures ? unit * 0.6 : 0),
                              child: Text(
                                side.text,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: fontSize, height: 1.2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

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
                        // Once the solution is shown the tile itself turns green or red.
                        final right = tile.mark == true;
                        final wrong = tile.mark == false;
                        final background = right ? Colors.green.shade700 : (wrong ? scheme.errorContainer : scheme.surfaceContainerLow);
                        final foreground = right ? Colors.white : (wrong ? scheme.onErrorContainer : null);
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: tile.shown ? 1 : 0.25,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            margin: EdgeInsets.all(unit * 0.6),
                            padding: EdgeInsets.symmetric(horizontal: unit * 2),
                            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(unit * 1.5)),
                            child: Row(
                              children: [
                                Text(
                                  tile.label,
                                  style: TextStyle(fontSize: unit * 3, fontWeight: FontWeight.bold, color: foreground ?? scheme.tertiary),
                                ),
                                SizedBox(width: unit * 2),
                                Expanded(
                                  child: Text(
                                    tile.shown ? tile.text : "",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: unit * 3, color: foreground),
                                  ),
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
  const _AnswerRoundDisplay({required this.state, required this.round, required this.unit, this.places = const {}, this.backgroundImage});

  final ImageProvider? backgroundImage;

  /// By closeness: each team's place, 0 = first.
  final Map<String, int> places;

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
            // More than six answers go on two rows, so each stays readable.
            child: Column(
              children: [
                for (final row in _rowsOf(shown, shown.length > 6 ? (shown.length / 2).ceil() : shown.length))
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: shown.length > 6 ? unit * 0.4 : 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final team in row)
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final verdict = state.results.verdicts[team.id];
                                  // Shown once it is on the scoreboard, not while it is being rated.
                                  final awarded = state.results.given[team.id];
                                  final place = verdict == null ? places[team.id] : null;
                                  final medal = place == null ? null : _placeColors.elementAtOrNull(place);
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
                                            ? (medal ?? Colors.transparent)
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
                                            if (place != null) ...[
                                              SizedBox(width: unit),
                                              _PlaceBadge(place: place, color: medal, unit: unit),
                                              if (awarded != null && awarded != 0)
                                                Text(
                                                  " +$awarded",
                                                  style: TextStyle(fontSize: unit * 2.6, fontWeight: FontWeight.w700),
                                                ),
                                            ],
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
                                },
                              ),
                            ),
                          // The last row keeps the same tile width.
                          for (var k = row.length; k < (shown.length > 6 ? (shown.length / 2).ceil() : shown.length); k++)
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// [items] in rows of [perRow].
/// Gold, silver and bronze for the first three places.
const _placeColors = [Color(0xFFE0B526), Color(0xFFA8B0B8), Color(0xFFC07A3E)];

/// "1st", "2nd", … on a round badge, in the place's colour from the podium.
class _PlaceBadge extends StatelessWidget {
  const _PlaceBadge({required this.place, required this.color, required this.unit});

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

List<List<T>> _rowsOf<T>(List<T> items, int perRow) => [
  for (var start = 0; start < items.length; start += perRow)
    items.sublist(start, start + perRow > items.length ? items.length : start + perRow),
];
