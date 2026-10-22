import 'dart:io';

import 'package:flutter/material.dart';

import 'package:quiz_show/core/theme.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/features/session/pages/screen_overlays.dart';
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

/// [card] as the big screen shows it, shrunk to [width].
class CardPreview extends StatelessWidget {
  const CardPreview({super.key, required this.gameId, required this.card, required this.width});

  final String gameId;
  final CueCard card;
  final double width;

  File? _file(String name) {
    if (!MediaService.instance.ready) return null;
    final file = MediaService.instance.localFile(gameId, name);
    return file.existsSync() ? file : null;
  }

  @override
  Widget build(BuildContext context) {
    final empty = card.title.isEmpty && card.text.isEmpty && card.image == null && card.video == null;
    return Container(
      width: width,
      height: width * 9 / 16,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(width / 24)),
      child: Theme(
        // The big screen is dark.
        data: buildAppTheme(Brightness.dark),
        child: Builder(
          builder: (context) => ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  child: SizedBox(
                    width: 1600,
                    height: 900,
                    child: CardOverlay(
                      animation: CardAnimation.off,
                      imageFile: _file,
                      card: empty
                          ? const OverlayCard(text: "Empty card")
                          : OverlayCard(
                              title: card.title.isEmpty ? null : card.title,
                              text: card.text.isEmpty ? null : card.text,
                              image: card.image,
                              style: card.style,
                            ),
                    ),
                  ),
                ),
                // A clip plays full screen; the preview says so.
                if (card.video != null)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(width / 32),
                      child: Icon(Icons.movie_outlined, color: Colors.white, size: width / 9),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CardsDialog extends StatefulWidget {
  const CardsDialog({super.key, required this.gameId, required this.cards, required this.save, this.title = "Cards"});

  final String gameId;
  final List<CueCard> cards;
  final void Function(List<Map<String, dynamic>> cards) save;
  final String title;

  @override
  State<CardsDialog> createState() => _CardsDialogState();
}

class _CardsDialogState extends State<CardsDialog> {
  static const double _tileWidth = 200;

  late final List<CueCard> _cards = [...widget.cards];
  final ScrollController _scroll = ScrollController();
  bool _uploading = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _save() => widget.save([for (final card in _cards) card.toMap()]);

  void _change(VoidCallback change) {
    setState(change);
    _save();
  }

  /// A new card goes last; the row scrolls to it so it is not missed.
  void _append(CueCard card) {
    _change(() => _cards.add(card));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
      }
    });
  }

  Future<void> _edit(int index) async {
    final edited = await showDialog<CueCard>(
      context: context,
      builder: (_) => CardEditorDialog(gameId: widget.gameId, card: _cards[index]),
    );
    if (edited == null || !mounted) return;
    _change(() => identical(edited, CardEditorDialog.removed) ? _cards.removeAt(index) : _cards[index] = edited);
  }

  Future<void> _new() async {
    final card = await showDialog<CueCard>(
      context: context,
      builder: (_) => CardEditorDialog(gameId: widget.gameId, card: const CueCard(), isNew: true),
    );
    if (card != null && mounted) _append(card);
  }

  /// A new card that is just a picture: pick it, and it is in the row.
  Future<void> _addPicture() async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await MediaKind.image.pick();
    if (path == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final name = await MediaService.instance.upload(widget.gameId, path);
      if (mounted) _append(CueCard(image: name));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Could not upload the picture.")));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _tile(int index) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = _cards[index];
    final builtin = isBuiltinImage(card.image);
    final label = card.title.isNotEmpty
        ? card.title
        : builtinImage(card.image)?.label ?? (card.text.isNotEmpty ? card.text : (card.image != null ? "Picture" : "Card"));
    return Padding(
      key: ObjectKey(card),
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: _tileWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(_tileWidth / 24),
              onTap: builtin ? () => _change(() => _cards[index] = _switched(card)) : () => _edit(index),
              child: Opacity(
                opacity: card.hidden ? 0.35 : 1,
                child: CardPreview(gameId: widget.gameId, card: card, width: _tileWidth),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.drag_indicator, size: 20, color: scheme.outline, semanticLabel: "Move card"),
                  ),
                ),
                Expanded(
                  child: Text(
                    card.hidden ? "$label · off" : label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: card.hidden ? scheme.outline : null),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  tooltip: card.hidden ? "Offer it in the show" : "Keep it out of the show",
                  icon: Icon(card.hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => _change(() => _cards[index] = _switched(card)),
                ),
                // A picture that comes with the app stays what it is.
                if (!builtin)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    tooltip: "Edit",
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(index),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "What you can put over the screen during the show, offered in this order. Tap a card to change it, "
              "drag it by its handle to move it, or switch it off to keep it out of the show.",
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(onPressed: _new, icon: const Icon(Icons.add), label: const Text("New card")),
                FilledButton.tonalIcon(
                  onPressed: _uploading ? null : _addPicture,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_uploading ? "Uploading…" : "Add picture"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _tileWidth * 9 / 16 + 60,
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: ReorderableListView.builder(
                  scrollController: _scroll,
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: _cards.length,
                  // onReorderItem replaces this from Flutter 3.41 on; kept for older SDKs in CI.
                  // ignore: deprecated_member_use
                  onReorder: (from, to) => _change(() {
                    if (to > from) to--;
                    _cards.insert(to, _cards.removeAt(from));
                  }),
                  itemBuilder: (context, index) => _tile(index),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Done"))],
    );
  }
}

/// One card: a large preview while it is being changed, its words, its
/// picture or clip, and its look, chosen by seeing it. Pops with the card,
/// or with nothing when cancelled. Removing a card pops with no card and
/// tells the list through [CardEditorDialog.removed].
class CardEditorDialog extends StatefulWidget {
  const CardEditorDialog({super.key, required this.gameId, required this.card, this.isNew = false});

  final String gameId;
  final CueCard card;
  final bool isNew;

  /// What the dialog returns for "Remove card".
  static const CueCard removed = CueCard(title: '\u0000removed');

  @override
  State<CardEditorDialog> createState() => _CardEditorDialogState();
}

class _CardEditorDialogState extends State<CardEditorDialog> {
  late final TextEditingController _title = TextEditingController(text: widget.card.title);
  late final TextEditingController _text = TextEditingController(text: widget.card.text);
  late String? _image = widget.card.image;
  late String? _video = widget.card.video;
  late CardStyle _style = widget.card.style;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  CueCard _card({CardStyle? style}) => CueCard(
    title: _title.text.trim(),
    text: _text.text.trim(),
    image: _image,
    video: _video,
    hidden: widget.card.hidden,
    style: style ?? _style,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      title: Text(widget.isNew ? "New card" : "Card"),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: CardPreview(gameId: widget.gameId, card: _card(), width: 520)),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                autofocus: widget.isNew,
                decoration: const InputDecoration(labelText: "Title"),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _text,
                decoration: const InputDecoration(labelText: "Text"),
                minLines: 1,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text("Picture", style: theme.textTheme.labelLarge),
                  MediaButton(gameId: widget.gameId, kind: MediaKind.image, name: _image, onChanged: (name) => setState(() => _image = name)),
                  const SizedBox(width: 16),
                  Text("Video clip", style: theme.textTheme.labelLarge),
                  MediaButton(gameId: widget.gameId, kind: MediaKind.video, name: _video, onChanged: (name) => setState(() => _video = name)),
                ],
              ),
              if (_video != null)
                Text("A clip plays full screen on the big screen and the card goes when it ends.", style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Text("Look", style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final style in CardStyle.values)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _style = style),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: style == _style ? scheme.primary : Colors.transparent, width: 2.5),
                        ),
                        child: Column(
                          children: [
                            CardPreview(gameId: widget.gameId, card: _card(style: style), width: 120),
                            const SizedBox(height: 4),
                            Text(style.uiString, style: theme.textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!widget.isNew)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () => Navigator.of(context).pop(CardEditorDialog.removed),
            icon: const Icon(Icons.delete_outline),
            label: const Text("Remove card"),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
        FilledButton(onPressed: () => Navigator.of(context).pop(_card()), child: Text(widget.isNew ? "Add" : "Save")),
      ],
    );
  }
}

/// [card] switched on or off for the show.
CueCard _switched(CueCard card) =>
    CueCard(title: card.title, text: card.text, image: card.image, video: card.video, hidden: !card.hidden, style: card.style);
