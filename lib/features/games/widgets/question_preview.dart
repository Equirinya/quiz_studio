import 'package:flutter/material.dart';

import 'package:quiz_show/features/session/pages/presenter_view.dart';
import 'package:quiz_show/game/game.dart';

/// Shows [question] as the audience will see it.
Future<void> showQuestionPreview(
  BuildContext context, {
  required String gameId,
  required String categoryId,
  required Question question,
}) =>
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: QuestionPreview(gameId: gameId, categoryId: categoryId, question: question),
        ),
      ),
    );

/// The big screen in small, with the question open: first as it appears,
/// then step by step to everything revealed.
class QuestionPreview extends StatefulWidget {
  const QuestionPreview({super.key, required this.gameId, required this.categoryId, required this.question});

  final String gameId;
  final String categoryId;
  final Question question;

  @override
  State<QuestionPreview> createState() => _QuestionPreviewState();
}

class _QuestionPreviewState extends State<QuestionPreview> {
  int _revealed = 0;

  Question get _q => widget.question;

  /// How many steps there are to uncover.
  int get _steps => switch (_q.type) {
        // One more than the answers: the last step marks right and wrong.
        QuestionType.abcd => _q.answers.length + 1,
        QuestionType.progressingReveal || QuestionType.feud => _q.information.length,
        QuestionType.topAnswers => _q.topAnswers?.items.length ?? 0,
        _ => 0,
      };

  SessionState get _state => SessionState(
        phase: Phase.question,
        current: QuestionRef(widget.categoryId, _q.id),
        revealed: _revealed,
        // The newest picture is the big one, as when the gamemaster steps through.
        imageFocus: _q.type == QuestionType.progressingReveal ? _revealed : 0,
        feudRevealed: _q.type == QuestionType.feud || _q.type == QuestionType.topAnswers ? [for (var i = 0; i < _revealed; i++) i] : const [],
      );

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: LayoutBuilder(
                builder: (context, box) {
                  final unit = box.maxHeight / 100;
                  return Padding(
                    padding: EdgeInsets.all(unit * 3),
                    child: QuestionDisplay(gameId: widget.gameId, state: _state, question: _q, unit: unit),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              if (steps > 0) ...[
                IconButton(
                  icon: const Icon(Icons.navigate_before),
                  tooltip: "Hide one",
                  onPressed: _revealed == 0 ? null : () => setState(() => _revealed--),
                ),
                Text("$_revealed of $steps revealed"),
                IconButton(
                  icon: const Icon(Icons.navigate_next),
                  tooltip: "Reveal next",
                  onPressed: _revealed >= steps ? null : () => setState(() => _revealed++),
                ),
              ],
              const Spacer(),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Close")),
            ],
          ),
        ),
      ],
    );
  }
}
