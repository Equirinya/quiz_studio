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
import 'package:quiz_show/features/session/pages/round_display.dart';
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
        // A group may bring its own colours, and a category its own while one
        // of its questions is open; the whole screen follows them.
        final category = state.current == null ? null : game.category(state.current!.categoryId);
        final (seed, accent) = category?.color != null ? (category!.color, category.accentColor) : (group?.color, group?.accentColor);
        final theme = seed == null
            ? base
            : ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Color(seed),
                  tertiary: accent == null ? null : Color(accent),
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
    return LayoutBuilder(builder: (context, constraints) {
    // More teams than fit on one line: flatter boxes, name and points side
    // by side, so the rows take less of the screen.
    final count = state.teams.length;
    final compact = count > ((constraints.maxWidth + unit) / (unit * 23)).floor();
    final width = unit * (compact ? 18 : 22);
    // Even rows: sixteen teams are two rows of eight, not seven, seven and two.
    final fits = max(1, ((constraints.maxWidth + unit) / (width + unit)).floor());
    final perRow = (count / (count / fits).ceil()).ceil();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: perRow * (width + unit)),
      child: Wrap(
      alignment: WrapAlignment.center,
      spacing: unit,
      runSpacing: unit * (compact ? 0.8 : 1),
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
                width: width,
                height: unit * (compact ? (bets == null ? 6.5 : 9) : (bets == null ? 12 : 14)),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(unit * 2),
                  border: own != null && position == 0 ? Border.all(color: scheme.onSurface, width: unit * 0.5) : null,
                ),
                alignment: Alignment.center,
                padding: compact ? EdgeInsets.symmetric(horizontal: unit * 1.5) : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (compact)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              team.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: unit * 2.2, color: text),
                            ),
                          ),
                          SizedBox(width: unit),
                          Text(
                            team.points.toString(),
                            style: TextStyle(fontSize: unit * 3.6, fontWeight: FontWeight.w600, color: text),
                          ),
                        ],
                      )
                    else ...[
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
                    ],
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
      ),
    );
    });
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
    if (group.type == BoardType.display) {
      // Line by line as written; a long text gets smaller rather than cut off.
      return LayoutBuilder(
        builder: (context, box) => Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: box.maxWidth,
              child: Text(
                group.text ?? group.name,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: unit * 7, height: 1.2),
              ),
            ),
          ),
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
              // A category with its own colours shows them on its column.
              child: Builder(builder: (context) {
                final scheme = categoryScheme(category, Theme.of(context).colorScheme);
                return Column(
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
              );
              }),
            ),
          ),
      ],
    );
  }
}

/// [base], or the colours of [category] where it has its own.
ColorScheme categoryScheme(Category category, ColorScheme base) => category.color == null
    ? base
    : ColorScheme.fromSeed(
        seedColor: Color(category.color!),
        tertiary: category.accentColor == null ? null : Color(category.accentColor!),
        brightness: base.brightness,
      );

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
    final round = state.answerRound;
    // Every kind of question in the same frame: its own display, below it
    // one small line of who is answering on the devices, and the answers
    // the gamemaster shows popping up over it all.
    final main = switch (question.type) {
      QuestionType.connections => _ConnectionsDisplay(state: state, question: question, unit: unit),
      QuestionType.rapidFire => RapidFireDisplay(state: state, question: question, unit: unit, file: _file),
      QuestionType.lastStanding => StandingDisplay(state: state, question: question, unit: unit, file: _file),
      QuestionType.progressingReveal => _RevealDisplay(state: state, question: question, unit: unit, file: _file),
      _ => _standard(context, round),
    };
    // Connections shows each team's progress itself.
    final strip = round != null && question.type != QuestionType.connections;
    final shown = round != null && round.revealed.any((id) => state.team(id) != null);
    final background = round == null ? null : _file(round.spec.backgroundImage);
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              Expanded(child: main),
              if (strip)
                Padding(
                  padding: EdgeInsets.only(top: unit * 1.5),
                  child: RoundStatusStrip(state: state, round: round, unit: unit),
                ),
            ],
          ),
        ),
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(animation), child: child),
            ),
            child: !shown
                ? const SizedBox(key: ValueKey('no-answers'))
                : Container(
                    key: const ValueKey('answers'),
                    padding: EdgeInsets.all(unit * 1.5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(unit * 3),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: unit * 4)],
                    ),
                    child: ShownAnswers(
                      state: state,
                      round: round,
                      unit: unit,
                      places: question.byCloseness ? closenessPlaces(state) : const {},
                      backgroundImage: background == null ? null : FileImage(background),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// The question in its box, and below it what belongs to its kind: the
  /// ABCD answers, the survey, the pieces to match or put in order, the
  /// top answers. Without anything below, the question gets all the room.
  Widget _standard(BuildContext context, AnswerRound? round) {
    final scheme = Theme.of(context).colorScheme;
    final image = _file(question.image);
    // Matching and put in order: the question as tall as its text, the
    // pieces get the rest.
    final pieces = question.type == QuestionType.matching || question.type == QuestionType.ordering;
    final (body, flex) = switch (question.type) {
      QuestionType.abcd when question.answers.isNotEmpty => (
          _Tiles(
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
          2,
        ),
      QuestionType.feud => (
          Column(
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
          3,
        ),
      QuestionType.matching => (_MatchingBoard(question: question, unit: unit, file: _file, placed: state.revealed), 7),
      QuestionType.ordering => (OrderingBoard(state: state, question: question, unit: unit, file: _file), 7),
      // Top answers: the list takes over once its first answer is uncovered.
      QuestionType.topAnswers when round == null || state.feudRevealed.isNotEmpty => (
          _TopAnswersBoard(state: state, question: question, unit: unit),
          4,
        ),
      _ => (null, 0),
    };
    final card = Container(
      width: double.infinity,
      padding: EdgeInsets.all(unit * 2),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(unit * 3)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        // The picture as big as the box lets it be.
        crossAxisAlignment: pieces ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
        children: [
          if (image != null)
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.only(right: question.text.trim().isEmpty ? 0 : unit * 2),
                child: FittedBox(
                  child: ClipRRect(borderRadius: BorderRadius.circular(unit * 2), child: Image.file(image)),
                ),
              ),
            ),
          if (question.hasMusic)
            Center(
              child: Padding(
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
            ),
          if (image == null || question.text.trim().isNotEmpty)
            Flexible(
              flex: 2,
              child: Center(
                child: Text(
                  question.text,
                  textAlign: TextAlign.center,
                  maxLines: pieces ? 3 : (body == null ? 8 : 6),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: unit * 4.5),
                ),
              ),
            ),
        ],
      ),
    );
    return Column(
      children: [
        if (question.description != null)
          Padding(
            padding: EdgeInsets.only(bottom: unit),
            child: Chip(label: Text(question.description!, style: TextStyle(fontSize: unit * 2.4))),
          ),
        if (pieces && image == null)
          ConstrainedBox(constraints: BoxConstraints(maxHeight: unit * 28), child: card)
        else
          Expanded(flex: body == null ? 1 : (pieces ? 3 : 3), child: card),
        if (body != null)
          Expanded(
            flex: flex,
            child: Padding(padding: EdgeInsets.only(top: unit * 1.5), child: body),
          ),
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
                    child: ScaleTransition(
                      alignment: Alignment.centerLeft,
                      scale: Tween(begin: 0.6, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  // Every answer starts at the same place, however many
                  // teams found it.
                  layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
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
          OneRow(
            spacing: unit * 1.5,
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
///
/// As the solution is revealed ([placed] pairs), each right item slides under
/// its partner; the ones still to come close up behind.
class _MatchingBoard extends StatelessWidget {
  const _MatchingBoard({required this.question, required this.unit, required this.file, this.placed = 0});

  final Question question;
  final double unit;
  final File? Function(String? name) file;
  final int placed;

  @override
  Widget build(BuildContext context) {
    final matching = question.matching ?? const Matching();
    final n = matching.pairs.length;
    final numbers = matching.rightNumbers(question.id);
    // Pair indices of the right items in the order they are shown.
    final shuffled = List<int>.generate(n, (i) => i)..sort((a, b) => numbers[a].compareTo(numbers[b]));
    final done = placed.clamp(0, n);
    final waiting = [for (final pair in shuffled) if (pair >= done) pair];
    int slotOf(int pair) => pair < done ? pair : done + waiting.indexOf(pair);
    final top = [for (final pair in matching.pairs) pair.left];
    final bottom = [for (final pair in matching.pairs) pair.right];
    return LayoutBuilder(
      builder: (context, box) {
        final inner = box.maxWidth / (n == 0 ? 1 : n) - 2 * (_margin + _padding);
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
            Expanded(child: _row(top, fontSize, context, slotOf: (pair) => pair, done: done)),
            SizedBox(height: unit * 1.5),
            Expanded(child: _row(bottom, fontSize, context, slotOf: slotOf, done: done)),
          ],
        );
      },
    );
  }

  double get _margin => unit * 0.6;
  double get _padding => unit;

  /// One side of the board; [sides] by pair, each in the slot [slotOf] says.
  Widget _row(List<MatchSide> sides, double fontSize, BuildContext context, {required int Function(int pair) slotOf, required int done}) {
    final scheme = Theme.of(context).colorScheme;
    final pictures = sides.any((side) => side.image != null);
    final texts = sides.any((side) => side.text.isNotEmpty);
    return LayoutBuilder(
      builder: (context, box) {
        final margin = _margin;
        final padding = _padding;
        final width = box.maxWidth / (sides.isEmpty ? 1 : sides.length);
        // The border that marks the pair put together last takes room too.
        final border = unit * 0.3;
        final inner = width - 2 * (margin + padding + border);
        final textHeight = texts ? fontSize * 1.3 * 2 + unit * 0.6 : 0.0;
        final square = pictures ? (box.maxHeight - 2 * (padding + border) - textHeight).clamp(0.0, inner).toDouble() : 0.0;
        // The pair put together last moves over the others.
        final paintOrder = [for (var i = 0; i < sides.length; i++) if (i != done - 1) i, if (done > 0 && done <= sides.length) done - 1];
        return Stack(
          children: [
            for (final pair in paintOrder)
              AnimatedPositioned(
                key: ValueKey(pair),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOutCubic,
                left: slotOf(pair) * width,
                top: 0,
                width: width,
                height: box.maxHeight,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  margin: EdgeInsets.symmetric(horizontal: margin),
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    color: pair == done - 1
                        ? scheme.primaryContainer
                        : pair < done
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(unit * 2),
                    border: Border.all(color: pair == done - 1 ? scheme.primary : Colors.transparent, width: border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (pictures)
                        SizedBox.square(
                          dimension: square,
                          child: file(sides[pair].image) != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(unit * 1.2),
                                  child: Image.file(file(sides[pair].image)!, fit: BoxFit.cover),
                                )
                              : sides[pair].image != null
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
                                sides[pair].text,
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
