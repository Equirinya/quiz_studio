import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/game/game.dart';

/// The cards a game brings along for the gamemaster to put on screen: the
/// rules of a round, a break notice, a picture. [save] receives the whole
/// list as stored on the game document, in the order the gamemaster gets
/// them offered.
Future<void> showCardsDialog(
  BuildContext context, {
  required String gameId,
  required List<CueCard> cards,
  required void Function(List<Map<String, dynamic>> cards) save,
}) => showDialog<void>(
  context: context,
  builder: (_) => CardsDialog(gameId: gameId, cards: cards, save: save),
);

class CardsDialog extends StatefulWidget {
  const CardsDialog({super.key, required this.gameId, required this.cards, required this.save});

  final String gameId;
  final List<CueCard> cards;
  final void Function(List<Map<String, dynamic>> cards) save;

  @override
  State<CardsDialog> createState() => _CardsDialogState();
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

/// A small picture of what a card shows: its image, a built-in picture, or
/// an icon for text and video.
class CardThumbnail extends StatelessWidget {
  const CardThumbnail({super.key, required this.gameId, required this.image, this.video, this.width = 72});

  final String gameId;
  final String? image;
  final String? video;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final builtin = builtinImage(image);
    ImageProvider? provider;
    if (builtin != null) {
      provider = AssetImage(builtin.asset);
    } else if (image != null && MediaService.instance.ready) {
      final file = MediaService.instance.localFile(gameId, image!);
      if (file.existsSync()) provider = FileImage(file);
    }
    return Container(
      width: width,
      height: width * 9 / 16,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
      child: provider != null
          ? Image(image: provider, fit: BoxFit.cover)
          : Icon(
              video != null
                  ? Icons.movie_outlined
                  : image != null
                  ? Icons.image_outlined
                  : Icons.article_outlined,
              color: scheme.outline,
            ),
    );
  }
}

/// Lets the gamemaster pick one of the pictures that come with the app.
/// Returns its name, '' to take the current one away, or null for no change.
Future<String?> pickBuiltinImage(BuildContext context, {String? current}) => showDialog<String>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text("Built-in pictures"),
    content: SizedBox(
      width: 520,
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 16 / 9,
        children: [
          for (final image in builtinImages)
            InkWell(
              onTap: () => Navigator.of(context).pop(image.name),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    width: 3,
                    color: current == image.name ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  ),
                ),
                child: Image.asset(image.asset, fit: BoxFit.cover, semanticLabel: image.label),
              ),
            ),
        ],
      ),
    ),
    actions: [
      if (isBuiltinImage(current)) TextButton(onPressed: () => Navigator.of(context).pop(''), child: const Text("Remove")),
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
    ],
  ),
);

class _CardsDialogState extends State<CardsDialog> {
  late final List<_CardRow> _rows = [for (final card in widget.cards) _CardRow(card)];

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _save() => widget.save([
    for (final row in _rows)
      CueCard(title: row.title.text.trim(), text: row.text.text.trim(), image: row.image, video: row.video).toMap(),
  ]);

  Future<void> _chooseBuiltin(_CardRow row) async {
    final picked = await pickBuiltinImage(context, current: row.image);
    if (picked == null || !mounted) return;
    setState(() => row.image = picked.isEmpty ? null : picked);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text("Cards"),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Text, pictures or video clips you can put over the screen at any time during the show, offered in this order. "
              "Drag a card by its handle to move it. A card with a video plays it full screen and disappears when it ends.",
              style: theme.textTheme.bodySmall,
            ),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: _rows.length,
                // onReorderItem replaces this from Flutter 3.41 on; kept for older SDKs in CI.
                // ignore: deprecated_member_use
                onReorder: (from, to) {
                  setState(() {
                    if (to > from) to--;
                    _rows.insert(to, _rows.removeAt(from));
                  });
                  _save();
                },
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  final builtin = isBuiltinImage(row.image);
                  return Padding(
                    key: ObjectKey(row),
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(0, 10, 8, 0),
                            child: Icon(Icons.drag_indicator, semanticLabel: "Move card"),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4, right: 12),
                          child: CardThumbnail(gameId: widget.gameId, image: row.image, video: row.video),
                        ),
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
                        // Two by two, so a card is no taller than its two fields.
                        SizedBox(
                          width: 96,
                          child: Wrap(
                            children: [
                              MediaButton(
                                gameId: widget.gameId,
                                kind: MediaKind.image,
                                // A built-in picture is not a file of the game.
                                name: builtin ? null : row.image,
                                onChanged: (name) {
                                  setState(() => row.image = name);
                                  _save();
                                },
                              ),
                              IconButton(
                                tooltip: builtin ? "Change built-in picture" : "Use a built-in picture",
                                icon: Icon(builtin ? Icons.collections : Icons.collections_outlined),
                                color: builtin ? theme.colorScheme.primary : null,
                                onPressed: () => _chooseBuiltin(row),
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
                        ),
                      ],
                    ),
                  );
                },
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
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Done"))],
    );
  }
}
