import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// The pictures, sound and video of a question or of one item, one row each.
/// Any number of pictures, dragged into their order, shown side by side or
/// one after another. Files can be dropped on any row. A picture being
/// uploaded already has its row, with "Add another picture" below it.
class MediaSetFields extends StatefulWidget {
  const MediaSetFields({super.key, required this.gameId, required this.media, required this.onChanged});

  final String gameId;
  final MediaSet media;
  final ValueChanged<MediaSet> onChanged;

  @override
  State<MediaSetFields> createState() => _MediaSetFieldsState();
}

/// A picture on its way up: the file on this device, and how far it is.
class _Upload {
  _Upload(this.path);

  final String path;
  final ValueNotifier<double?> progress = ValueNotifier(null);
}

class _MediaSetFieldsState extends State<MediaSetFields> {
  /// What is set, as changed here: the saved one comes back a moment later.
  late MediaSet _media = widget.media;

  /// Pictures still uploading, in the order they were added; one at a time.
  final List<_Upload> _uploads = [];
  bool _running = false;

  @override
  void didUpdateWidget(MediaSetFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a real change from outside; a rebuild with the value from before
    // the last change here would undo it.
    if (widget.media != oldWidget.media) _media = widget.media;
  }

  void _emit(MediaSet next) {
    _media = next;
    if (mounted) setState(() {});
    widget.onChanged(next);
  }

  /// Pictures chosen or dropped: a row each at once, uploaded in turn. Goes
  /// on when the editor is closed, and still saves them.
  Future<void> _add(List<String> paths) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _uploads.addAll(paths.map(_Upload.new)));
    if (_running) return;
    _running = true;
    while (_uploads.isNotEmpty) {
      final upload = _uploads.first;
      upload.progress.value = 0;
      final name = await uploadMedia(
        messenger,
        l10n,
        widget.gameId,
        MediaKind.image,
        upload.path,
        onProgress: (progress) => upload.progress.value = progress,
      );
      _uploads.remove(upload);
      if (name != null) {
        _emit(_media.copyWith(images: [..._media.images, name]));
      } else if (mounted) {
        setState(() {});
      }
    }
    _running = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = _media;
    final images = media.images;
    // Uploads count already: they show where the picture will be.
    final count = images.length + _uploads.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Several pictures: all at once, or the gamemaster steps through
        // them. A setting of the pictures together, so above them.
        if (count > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, icon: const Icon(Icons.view_column_outlined), label: Text(l10n.picturesSideBySide)),
                ButtonSegment(value: true, icon: const Icon(Icons.burst_mode_outlined), label: Text(l10n.picturesOneByOne)),
              ],
              selected: {media.oneByOne},
              onSelectionChanged: (selected) => _emit(media.copyWith(oneByOne: selected.first)),
            ),
          ),
        if (count == 1 && images.length == 1)
          MediaButton.tile(
            key: ValueKey('0/${images.single}'),
            gameId: widget.gameId,
            kind: MediaKind.image,
            name: images.single,
            title: l10n.picture,
            onChanged: (name) => _emit(media.copyWith(images: [?name])),
          )
        // Several: dragged by the handle into the order they are shown in.
        else if (images.isNotEmpty)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            // onReorderItem replaces this from Flutter 3.41 on; kept for older SDKs in CI.
            // ignore: deprecated_member_use
            onReorder: (from, to) {
              if (to > from) to -= 1;
              final order = [...images];
              order.insert(to, order.removeAt(from));
              _emit(media.copyWith(images: order));
            },
            children: [
              for (var i = 0; i < images.length; i++)
                Row(
                  // The same file twice keeps two keys.
                  key: ValueKey('${images[i]}/${images.take(i).where((name) => name == images[i]).length}'),
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.drag_indicator, semanticLabel: l10n.reorderPictures),
                        ),
                      ),
                    ),
                    Expanded(
                      child: MediaButton.tile(
                        gameId: widget.gameId,
                        kind: MediaKind.image,
                        name: images[i],
                        title: l10n.pictureN(i + 1),
                        onChanged: (name) => _emit(media.copyWith(images: [...images.take(i), ?name, ...images.skip(i + 1)])),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        for (final (i, upload) in _uploads.indexed)
          _UploadRow(
            key: ObjectKey(upload),
            upload: upload,
            title: count > 1 ? l10n.pictureN(images.length + i + 1) : l10n.picture,
            indent: count > 1,
          ),
        // Always one more to add, below what is there or on its way.
        MediaButton.tile(
          key: const ValueKey('add'),
          multiple: true,
          gameId: widget.gameId,
          kind: MediaKind.image,
          name: null,
          title: count == 0 ? l10n.addMedia(MediaKind.image.name) : l10n.addAnotherPicture,
          subtitle: count == 1 ? l10n.morePicturesHint : null,
          onPicked: _add,
          onChanged: (_) {},
        ),
        MediaButton.tile(
          gameId: widget.gameId,
          kind: MediaKind.audio,
          name: media.music,
          title: media.music == null ? l10n.addMedia(MediaKind.audio.name) : l10n.sound,
          onChanged: (name) => _emit(media.copyWith(music: name)),
        ),
        // Started from the controller like the music, in the picture's place.
        MediaButton.tile(
          gameId: widget.gameId,
          kind: MediaKind.video,
          name: media.video,
          title: media.video == null ? l10n.addMedia(MediaKind.video.name) : l10n.video,
          onChanged: (name) => _emit(media.copyWith(video: name)),
        ),
      ],
    );
  }
}

/// A picture being uploaded, where it will be once it is up: the file from
/// this device and how far it has got, or that it waits its turn.
class _UploadRow extends StatelessWidget {
  const _UploadRow({super.key, required this.upload, required this.title, required this.indent});

  final _Upload upload;
  final String title;

  /// Lined up with the pictures that have a drag handle.
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? 40 : 8, 6, 8, 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Opacity(
              opacity: 0.6,
              child: Image.file(File(upload.path), width: 56, height: 40, fit: BoxFit.cover, cacheWidth: 160,
                  errorBuilder: (_, _, _) => Container(width: 56, height: 40, color: scheme.surfaceContainerHighest)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ValueListenableBuilder<double?>(
              valueListenable: upload.progress,
              builder: (context, progress, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          // Waiting its turn: an empty bar.
                          value: progress == null ? 0 : (progress == 0 ? null : progress),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        progress == null ? context.l10n.waitingToUpload : context.l10n.uploadingPercent((progress * 100).round()),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One small button for an item's media: shows what it has, and opens
/// [MediaSetFields] in a dialog. Files dropped on it go in straight away:
/// pictures are added, a sound or a clip takes the place of the one there.
class MediaSetButton extends StatefulWidget {
  const MediaSetButton({super.key, required this.gameId, required this.media, required this.onChanged});

  final String gameId;
  final MediaSet media;
  final ValueChanged<MediaSet> onChanged;

  @override
  State<MediaSetButton> createState() => _MediaSetButtonState();
}

class _MediaSetButtonState extends State<MediaSetButton> {
  /// What is set, as changed here; see [_MediaSetFieldsState._media].
  late MediaSet _media = widget.media;

  bool _dragging = false;

  /// Dropped files still to upload, and how far the current one is.
  final List<String> _waiting = [];
  double? _progress;

  @override
  void didUpdateWidget(MediaSetButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.media != oldWidget.media) _media = widget.media;
  }

  void _emit(MediaSet next) {
    _media = next;
    if (mounted) setState(() {});
    widget.onChanged(next);
  }

  Future<void> _open(BuildContext context) async {
    var current = _media;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.media),
          content: SizedBox(
            width: 420,
            child: MediaSetFields(
              gameId: widget.gameId,
              media: current,
              onChanged: (next) {
                // An upload can finish after the dialog was closed: still saved.
                current = next;
                _emit(next);
                if (context.mounted) setState(() {});
              },
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.done))],
        ),
      ),
    );
  }

  Future<void> _dropped(List<String> paths) async {
    final fitting = [
      for (final path in paths)
        if (MediaKind.values.any((kind) => kind.accepts(path))) path,
    ];
    if (fitting.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.fileTypeNotSupported)));
      return;
    }
    final busy = _waiting.isNotEmpty || _progress != null;
    setState(() => _waiting.addAll(fitting));
    if (busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    while (_waiting.isNotEmpty) {
      final path = _waiting.removeAt(0);
      final kind = MediaKind.values.firstWhere((kind) => kind.accepts(path));
      if (mounted) setState(() => _progress = 0);
      final name = await uploadMedia(messenger, l10n, widget.gameId, kind, path, onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      });
      if (name == null) continue;
      final media = _media;
      // A replaced sound or clip is referred to by nothing any more.
      final replaced = switch (kind) {
        MediaKind.audio => media.music,
        MediaKind.video => media.video,
        MediaKind.image => null,
      };
      _emit(switch (kind) {
        MediaKind.image => media.copyWith(images: [...media.images, name]),
        MediaKind.audio => media.copyWith(music: name),
        MediaKind.video => media.copyWith(video: name),
      });
      if (replaced != null) MediaService.instance.delete(widget.gameId, replaced);
    }
    if (mounted) setState(() => _progress = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = _media;
    final icons = [
      if (media.images.isNotEmpty) MediaKind.image.presentIcon,
      if (media.music != null) MediaKind.audio.presentIcon,
      if (media.video != null) MediaKind.video.presentIcon,
    ];
    final count = media.images.length;
    final uploading = _progress != null;
    final button = IconButton(
      tooltip: _dragging ? context.l10n.dropToAdd : context.l10n.media,
      onPressed: () => _open(context),
      icon: _dragging
          ? Icon(Icons.add, color: scheme.onPrimaryContainer)
          : icons.isEmpty
          ? const Icon(Icons.perm_media_outlined)
          : Badge(
              isLabelVisible: count > 1,
              label: Text('$count'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [for (final icon in icons) Icon(icon, size: icons.length > 1 ? 18 : 24, color: scheme.primary)],
              ),
            ),
    );
    return DropTarget(
      // Only while its page is on top, as for [MediaButton].
      enable: ModalRoute.of(context)?.isCurrent ?? true,
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        _dropped([for (final file in details.files) file.path]);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _dragging ? scheme.primaryContainer : Colors.transparent,
          border: Border.all(color: _dragging ? scheme.primary : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            button,
            // Uploading what was dropped: a ring around it, and how many wait.
            if (uploading)
              IgnorePointer(
                child: SizedBox.square(
                  dimension: 40,
                  child: CircularProgressIndicator(value: _progress == 0 ? null : _progress, strokeWidth: 3),
                ),
              ),
            if (uploading && _waiting.isNotEmpty)
              Positioned(
                right: 0,
                bottom: 0,
                child: Badge(label: Text('+${_waiting.length}')),
              ),
          ],
        ),
      ),
    );
  }
}
