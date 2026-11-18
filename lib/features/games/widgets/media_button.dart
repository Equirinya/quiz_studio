import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/session/pages/video_card.dart';
import 'package:quiz_show/l10n/l10n.dart';

const XTypeGroup _audioByExtension = XTypeGroup(label: 'Audio', extensions: <String>['mp3', 'wav', 'm4a', 'aac', 'flac']);
const XTypeGroup _audioByUniformType = XTypeGroup(label: 'Audio', uniformTypeIdentifiers: <String>['public.audio']);

const XTypeGroup _videoByExtension = XTypeGroup(label: 'Video', extensions: <String>['mp4', 'm4v', 'mov', 'webm', 'mkv']);
const XTypeGroup _videoByUniformType = XTypeGroup(label: 'Video', uniformTypeIdentifiers: <String>['public.movie']);

enum MediaKind {
  image("image", Icons.add_photo_alternate_outlined, Icons.image),
  audio("sound", Icons.music_note_outlined, Icons.music_note),
  video("video", Icons.video_call_outlined, Icons.movie);

  const MediaKind(this.noun, this.addIcon, this.presentIcon);

  final String noun;
  final IconData addIcon;
  final IconData presentIcon;

  static const _extensions = {
    MediaKind.image: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic', 'heif'],
    MediaKind.audio: ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'oga', 'opus'],
    MediaKind.video: ['mp4', 'm4v', 'mov', 'webm', 'mkv'],
  };

  /// Whether a file dragged in from outside looks like one of these.
  bool accepts(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 && _extensions[this]!.contains(path.substring(dot + 1).toLowerCase());
  }

  /// Lets the user choose several pictures at once; empty when they cancel.
  /// Other kinds choose one.
  Future<List<String>> pickMany() async {
    if (this != MediaKind.image) return [?await pick()];
    return [for (final file in await ImagePicker().pickMultiImage()) file.path];
  }

  /// Lets the user choose a file; null when they cancel.
  Future<String?> pick() async {
    switch (this) {
      case MediaKind.image:
        return (await ImagePicker().pickImage(source: ImageSource.gallery))?.path;
      case MediaKind.audio:
        final group = Platform.isIOS || Platform.isMacOS ? _audioByUniformType : _audioByExtension;
        return (await openFile(acceptedTypeGroups: [group]))?.path;
      case MediaKind.video:
        final group = Platform.isIOS || Platform.isMacOS ? _videoByUniformType : _videoByExtension;
        return (await openFile(acceptedTypeGroups: [group]))?.path;
    }
  }
}

/// Uploads [path] for [gameId] and returns its stored name; null when it
/// failed, after saying why in a snack bar.
Future<String?> uploadMedia(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  String gameId,
  MediaKind kind,
  String path, {
  void Function(double progress)? onProgress,
}) async {
  try {
    return await MediaService.instance.upload(gameId, path, onProgress: onProgress);
  } on UploadTooLarge catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.fileTooLarge(error.maxMegabytes))));
  } on UnsupportedError catch (error) {
    messenger.showSnackBar(SnackBar(content: Text((error.message ?? '').startsWith('Ogg') ? l10n.oggNotSupported : l10n.fileTypeNotSupported)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotUploadMedia(kind.name))));
  }
  return null;
}

/// Attaches one media file to a document field. Without a file: a button to
/// pick and upload one. With one: a preview (the picture itself, a play
/// button for a sound, the clip's icon) that opens it large, with Replace
/// and Remove. [onChanged] receives the stored file name, or null.
class MediaButton extends StatefulWidget {
  const MediaButton({super.key, required this.gameId, required this.kind, required this.name, required this.onChanged})
      : title = null,
        subtitle = null,
        multiple = false,
        onPicked = null;

  /// A whole row to tap, for forms: the preview, [title] and [subtitle]
  /// beside it, a play button for a sound and a remove button. Tapping an
  /// empty one picks a file, a filled one opens it large.
  const MediaButton.tile({
    super.key,
    required this.gameId,
    required this.kind,
    required this.name,
    required this.onChanged,
    required String this.title,
    this.subtitle,
    this.multiple = false,
    this.onPicked,
  });

  /// Several files may be dropped on it at once: each is uploaded in turn
  /// and [onChanged] is called for each. For "add another picture".
  final bool multiple;

  /// Set to upload elsewhere: the files chosen or dropped go here instead,
  /// and this one stays a button to add with. For "add another picture",
  /// whose uploads show as rows of their own.
  final ValueChanged<List<String>>? onPicked;

  /// Set for [MediaButton.tile].
  final String? title;
  final String? subtitle;

  final String gameId;
  final MediaKind kind;

  /// The file currently attached, if any.
  final String? name;
  final ValueChanged<String?> onChanged;

  @override
  State<MediaButton> createState() => _MediaButtonState();
}

/// One player for every sound previewed in the editor, so starting one stops
/// the other.
final ValueNotifier<String?> _playingSound = ValueNotifier(null);
AudioPlayer? _soundPreview;

Future<void> _toggleSound(String gameId, String name) async {
  final player = _soundPreview ??= AudioPlayer()..onPlayerComplete.listen((_) => _playingSound.value = null);
  await player.stop();
  final key = '$gameId/$name';
  if (_playingSound.value == key) {
    _playingSound.value = null;
    return;
  }
  _playingSound.value = key;
  try {
    await MediaService.instance.ensureCached(gameId, name);
    await player.play(DeviceFileSource(MediaService.instance.localFile(gameId, name).path));
  } catch (_) {
    _playingSound.value = null;
  }
}

class _MediaButtonState extends State<MediaButton> {
  bool _busy = false;

  /// 0..1 of the upload sent, while there is one.
  double? _progress;

  bool get _attached => widget.name != null && widget.name!.isNotEmpty;

  /// A file dragged over this one right now.
  bool _dragging = false;

  /// Files dropped from the computer: the ones of this kind, uploaded as if
  /// picked.
  Future<void> _dropped(List<String> paths) async {
    final fitting = paths.where(widget.kind.accepts).toList();
    if (fitting.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.fileTypeNotSupported)));
      return;
    }
    if (widget.onPicked case final picked?) {
      picked(widget.multiple ? fitting : fitting.take(1).toList());
      return;
    }
    // Dropped while one is still uploading: they wait their turn. A single
    // file replaces whatever was waiting.
    setState(() => widget.multiple ? _waiting.addAll(fitting) : (_waiting..clear()..add(fitting.first)));
    if (_uploading) return;
    _uploading = true;
    while (_waiting.isNotEmpty && mounted) {
      final next = _waiting.removeAt(0);
      await _add(next);
    }
    _uploading = false;
  }

  /// Dropped files not uploaded yet, first first.
  final List<String> _waiting = [];
  bool _uploading = false;

  Future<void> _add([String? dropped]) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (dropped == null && widget.onPicked != null) {
      final paths = widget.multiple ? await widget.kind.pickMany() : [?await widget.kind.pick()];
      if (paths.isNotEmpty) widget.onPicked!(paths);
      return;
    }
    final path = dropped ?? await widget.kind.pick();
    if (path == null || !mounted) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    final old = widget.name;
    final uploaded = await uploadMedia(
      messenger,
      l10n,
      widget.gameId,
      widget.kind,
      path,
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      },
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _progress = null;
      });
    }
    // Also when this button is gone by now (its dialog or card closed): the
    // file is up, so it is put in place.
    if (uploaded != null) {
      widget.onChanged(uploaded);
      // A replaced file is referred to by nothing any more.
      if (old != null && old.isNotEmpty) MediaService.instance.delete(widget.gameId, old);
    }
  }

  Future<void> _remove() async {
    final old = widget.name!;
    widget.onChanged(null);
    MediaService.instance.delete(widget.gameId, old);
  }

  /// The file large, with what can be done with it.
  Future<void> _open() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => _MediaDialog(gameId: widget.gameId, kind: widget.kind, name: widget.name!),
    );
    if (!mounted) return;
    if (choice == 'replace') await _add();
    if (choice == 'remove') await _remove();
  }

  Widget _tile(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget box(Widget child, {bool filled = false}) => Container(
      width: 56,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
    final Widget leading = _busy
        ? box(
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(value: _progress == null || _progress == 0 ? null : _progress, strokeWidth: 3),
            ),
          )
        : !_attached
        ? box(Icon(widget.kind.addIcon, color: scheme.onSurfaceVariant))
        : widget.kind == MediaKind.image
        ? _CachedImage(gameId: widget.gameId, name: widget.name!, width: 56, height: 40)
        : box(Icon(widget.kind.presentIcon, color: scheme.onPrimaryContainer), filled: true);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _busy ? null : (_attached ? _open : _add),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(color: _attached ? null : scheme.primary),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _progress == null || _progress == 0 ? null : _progress,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            [
                              context.l10n.uploadingPercent(((_progress ?? 0) * 100).round()),
                              if (_waiting.isNotEmpty) context.l10n.nMoreWaiting(_waiting.length),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ] else if (widget.subtitle case final subtitle?)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (_attached && widget.kind == MediaKind.audio && !_busy)
                ValueListenableBuilder<String?>(
                  valueListenable: _playingSound,
                  builder: (context, playing, _) {
                    final on = playing == '${widget.gameId}/${widget.name}';
                    return IconButton(
                      tooltip: on ? context.l10n.stop : context.l10n.listen,
                      color: scheme.primary,
                      icon: Icon(on ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                      onPressed: () => _toggleSound(widget.gameId, widget.name!),
                    );
                  },
                ),
              if (_attached && !_busy)
                IconButton(
                  tooltip: context.l10n.remove,
                  icon: const Icon(Icons.close),
                  onPressed: _remove,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only while its page is on top: a drop target hears drops even under
    // a dialog, and the dialog's own fields should get them.
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    final scheme = Theme.of(context).colorScheme;
    return DropTarget(
      enable: onTop,
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        _dropped([for (final file in details.files) file.path]);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _dragging ? scheme.primaryContainer.withValues(alpha: 0.6) : Colors.transparent,
          border: Border.all(color: _dragging ? scheme.primary : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            _content(context),
            // What letting go will do: replace the file there, or add one.
            if (_dragging)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_attached ? Icons.swap_horiz : Icons.add, color: scheme.onPrimaryContainer),
                        if (widget.title != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _attached ? context.l10n.dropToReplace : context.l10n.dropToAdd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.title != null) return _tile(context);
    if (_busy) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(value: _progress == null || _progress == 0 ? null : _progress, strokeWidth: 3),
          ),
        ),
      );
    }
    if (!_attached) {
      return IconButton(tooltip: context.l10n.addMedia(widget.kind.name), icon: Icon(widget.kind.addIcon), onPressed: () => _add());
    }
    switch (widget.kind) {
      case MediaKind.image:
        return Tooltip(
          message: context.l10n.pictureTooltip,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _open,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: _CachedImage(gameId: widget.gameId, name: widget.name!, width: 56, height: 40),
            ),
          ),
        );
      case MediaKind.audio:
        // Listening is one tap away; the rest is behind the edit button.
        return ValueListenableBuilder<String?>(
          valueListenable: _playingSound,
          builder: (context, playing, _) {
            final on = playing == '${widget.gameId}/${widget.name}';
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: on ? context.l10n.stop : context.l10n.listen,
                  color: scheme.primary,
                  icon: Icon(on ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                  onPressed: () => _toggleSound(widget.gameId, widget.name!),
                ),
                IconButton(
                  tooltip: context.l10n.replaceOrRemoveSound,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _open,
                ),
              ],
            );
          },
        );
      case MediaKind.video:
        return IconButton(
          tooltip: context.l10n.videoTooltip,
          color: scheme.primary,
          icon: Icon(widget.kind.presentIcon),
          onPressed: _open,
        );
    }
  }
}

/// A game's picture from the local cache, fetched first when it is missing.
class _CachedImage extends StatefulWidget {
  const _CachedImage({required this.gameId, required this.name, required this.width, required this.height, this.fit = BoxFit.cover});

  final String gameId;
  final String name;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  State<_CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<_CachedImage> {
  late Future<File?> _file = _load();

  Future<File?> _load() async {
    try {
      await MediaService.instance.ensureCached(widget.gameId, widget.name);
      final file = MediaService.instance.localFile(widget.gameId, widget.name);
      return file.existsSync() ? file : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(_CachedImage old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) _file = _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: FutureBuilder<File?>(
          future: _file,
          builder: (context, snapshot) {
            final file = snapshot.data;
            if (file != null) return Image.file(file, fit: widget.fit);
            return ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: snapshot.connectionState == ConnectionState.done
                  ? Icon(Icons.image_outlined, color: scheme.outline)
                  : const Center(child: CupertinoActivityIndicator()),
            );
          },
        ),
      ),
    );
  }
}

class _MediaDialog extends StatelessWidget {
  const _MediaDialog({required this.gameId, required this.kind, required this.name});

  final String gameId;
  final MediaKind kind;
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget preview = switch (kind) {
      MediaKind.image => _CachedImage(gameId: gameId, name: name, width: 560, height: 360, fit: BoxFit.contain),
      MediaKind.audio => ValueListenableBuilder<String?>(
          valueListenable: _playingSound,
          builder: (context, playing, _) {
            final on = playing == '$gameId/$name';
            return FilledButton.tonalIcon(
              onPressed: () => _toggleSound(gameId, name),
              icon: Icon(on ? Icons.stop : Icons.play_arrow),
              label: Text(on ? context.l10n.stop : context.l10n.listen),
            );
          },
        ),
      MediaKind.video => SizedBox(
          width: 560,
          height: 315,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: Colors.black,
              child: FutureBuilder<void>(
                future: MediaService.instance.ensureCached(gameId, name),
                builder: (context, snapshot) {
                  final file = MediaService.instance.ready ? MediaService.instance.localFile(gameId, name) : null;
                  if (snapshot.connectionState != ConnectionState.done || file == null || !file.existsSync()) {
                    return const Center(child: CupertinoActivityIndicator());
                  }
                  return VideoCard(file: file, onFinished: () {});
                },
              ),
            ),
          ),
        ),
    };
    return AlertDialog(
      title: Text(switch (kind) {
        MediaKind.image => context.l10n.picture,
        MediaKind.audio => context.l10n.sound,
        MediaKind.video => context.l10n.video,
      }),
      content: Column(mainAxisSize: MainAxisSize.min, children: [Center(child: preview)]),
      actions: [
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          onPressed: () => Navigator.of(context).pop('remove'),
          icon: const Icon(Icons.delete_outline),
          label: Text(context.l10n.remove),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop('replace'),
          icon: Icon(kind.addIcon),
          label: Text(context.l10n.replace),
        ),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.done)),
      ],
    );
  }
}
