import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/game/game.dart';

/// The cards a game, a board or a category brings along for the gamemaster
/// to put on screen: the rules of a round, a break notice, a picture. [save]
/// receives the whole list as stored, in the order the gamemaster gets them
/// offered. The game's list includes the pictures that come with the app.
Future<void> showCardsDialog(
  BuildContext context, {
  required String gameId,
  required List<CueCard> cards,
  required void Function(List<Map<String, dynamic>> cards) save,
  String title = "Cards",
}) => showDialog<void>(
  context: context,
  builder: (_) => CardsDialog(gameId: gameId, cards: cards, save: save, title: title),
);

class CardsDialog extends StatefulWidget {
  const CardsDialog({super.key, required this.gameId, required this.cards, required this.save, this.title = "Cards"});

  final String gameId;
  final List<CueCard> cards;
  final void Function(List<Map<String, dynamic>> cards) save;
  final String title;

  @override
  State<CardsDialog> createState() => _CardsDialogState();
}

class _CardRow {
  _CardRow(CueCard card)
    : title = TextEditingController(text: card.title),
      text = TextEditingController(text: card.text),
      image = card.image,
      video = card.video,
      hidden = card.hidden;

  final TextEditingController title;
  final TextEditingController text;
  String? image;
  String? video;
  bool hidden;

  bool get builtin => isBuiltinImage(image);

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
      CueCard(
        title: row.title.text.trim(),
        text: row.text.text.trim(),
        image: row.image,
        video: row.video,
        hidden: row.hidden,
      ).toMap(),
  ]);

  bool _uploading = false;

  /// A new card that is just a picture: pick it, and it is in the list.
  Future<void> _addPicture() async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await MediaKind.image.pick();
    if (path == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final name = await MediaService.instance.upload(widget.gameId, path);
      if (!mounted) return;
      setState(() => _rows.add(_CardRow(CueCard(image: name))));
      _save();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Could not upload the picture.")));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Text, pictures or video clips you can put over the screen during the show, offered in this order. "
              "Drag a card by its handle to move it; switch one off to keep it out of the show. "
              "A card with a video plays it full screen and disappears when it ends.",
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
                  final builtin = row.builtin;
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
                          child: Opacity(
                            opacity: row.hidden ? 0.4 : 1,
                            child: CardThumbnail(gameId: widget.gameId, image: row.image, video: row.video),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              TextField(
                                controller: row.title,
                                decoration: InputDecoration(
                                  labelText: "Title",
                                  hintText: builtinImage(row.image)?.label,
                                  isDense: true,
                                ),
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
                          width: 112,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            children: [
                              // A picture that comes with the app stays what it is.
                              if (!builtin) ...[
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
                              ],
                              Switch(
                                value: !row.hidden,
                                onChanged: (on) {
                                  setState(() => row.hidden = !on);
                                  _save();
                                },
                              ),
                              if (!builtin)
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
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _rows.add(_CardRow(const CueCard()))),
                  icon: const Icon(Icons.add),
                  label: const Text("Add card"),
                ),
                TextButton.icon(
                  onPressed: _uploading ? null : _addPicture,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_uploading ? "Uploading…" : "Add picture"),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Done"))],
    );
  }
}
