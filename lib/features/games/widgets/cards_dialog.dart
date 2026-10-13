import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/game/game.dart';

/// The cards a game brings along for the gamemaster to put on screen: the
/// rules of a round, a break notice, a picture. [save] receives the whole
/// list as stored on the game document.
Future<void> showCardsDialog(
  BuildContext context, {
  required String gameId,
  required List<CueCard> cards,
  required void Function(List<Map<String, dynamic>> cards) save,
}) =>
    showDialog<void>(context: context, builder: (_) => _CardsDialog(gameId: gameId, cards: cards, save: save));

class _CardsDialog extends StatefulWidget {
  const _CardsDialog({required this.gameId, required this.cards, required this.save});

  final String gameId;
  final List<CueCard> cards;
  final void Function(List<Map<String, dynamic>> cards) save;

  @override
  State<_CardsDialog> createState() => _CardsDialogState();
}

class _CardRow {
  _CardRow(CueCard card)
      : title = TextEditingController(text: card.title),
        text = TextEditingController(text: card.text),
        image = card.image,
        video = card.video;

  final TextEditingController title;
  final TextEditingController text;
  String? image;
  String? video;

  void dispose() {
    title.dispose();
    text.dispose();
  }
}

class _CardsDialogState extends State<_CardsDialog> {
  late final List<_CardRow> _rows = [for (final card in widget.cards) _CardRow(card)];

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _save() => widget.save([
        for (final row in _rows) CueCard(title: row.title.text.trim(), text: row.text.text.trim(), image: row.image, video: row.video).toMap(),
      ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text("Cards"),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
"Text, pictures or video clips you can put over the screen at any time during the show. "
                "A card with a video plays it full screen and disappears when it ends.",
                style: theme.textTheme.bodySmall,
              ),
              for (final row in _rows)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: row.title,
                              decoration: const InputDecoration(labelText: "Title", isDense: true),
                              onChanged: (_) => _save(),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: row.text,
                              decoration: const InputDecoration(labelText: "Text", isDense: true),
                              minLines: 1,
                              maxLines: 4,
                              onChanged: (_) => _save(),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          MediaButton(
                            gameId: widget.gameId,
                            kind: MediaKind.image,
                            name: row.image,
                            onChanged: (name) {
                              setState(() => row.image = name);
                              _save();
                            },
                          ),
                          MediaButton(
                            gameId: widget.gameId,
                            kind: MediaKind.video,
                            name: row.video,
                            onChanged: (name) {
                              setState(() => row.video = name);
                              _save();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: "Remove card",
                            onPressed: () {
                              setState(() => _rows.remove(row));
                              _save();
                              WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _rows.add(_CardRow(const CueCard()))),
                  icon: const Icon(Icons.add),
                  label: const Text("Add card"),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Done"))],
    );
  }
}
