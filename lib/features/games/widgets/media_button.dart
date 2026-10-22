import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/session/pages/video_card.dart';

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

/// Attaches one media file to a document field. Without a file: a button to
/// pick and upload one. With one: a preview (the picture itself, a play
/// button for a sound, the clip's icon) that opens it large, with Replace
/// and Remove. [onChanged] receives the stored file name, or null.
class MediaButton extends StatefulWidget {
  const MediaButton({super.key, required this.gameId, required this.kind, required this.name, required this.onChanged});

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

  bool get _attached => widget.name != null && widget.name!.isNotEmpty;

  Future<void> _add() async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await widget.kind.pick();
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    final old = widget.name;
    try {
      widget.onChanged(await MediaService.instance.upload(widget.gameId, path));
      // A replaced file is referred to by nothing any more.
      if (old != null && old.isNotEmpty) MediaService.instance.delete(widget.gameId, old);
    } on UnsupportedError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message ?? "This file type is not supported.")));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text("Could not upload the ${widget.kind.noun}.")));
    }
    if (mounted) setState(() => _busy = false);
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_busy) {
      return const SizedBox(width: 48, height: 48, child: Center(child: CupertinoActivityIndicator()));
    }
    if (!_attached) {
      return IconButton(tooltip: "Add ${widget.kind.noun}", icon: Icon(widget.kind.addIcon), onPressed: _add);
    }
    switch (widget.kind) {
      case MediaKind.image:
        return Tooltip(
          message: "Picture: tap to see it large, replace or remove it",
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
                  tooltip: on ? "Stop" : "Listen",
                  color: scheme.primary,
                  icon: Icon(on ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                  onPressed: () => _toggleSound(widget.gameId, widget.name!),
                ),
                IconButton(
                  tooltip: "Replace or remove the sound",
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
          tooltip: "Video: tap to watch, replace or remove it",
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
              label: Text(on ? "Stop" : "Listen"),
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
        MediaKind.image => "Picture",
        MediaKind.audio => "Sound",
        MediaKind.video => "Video",
      }),
      content: Column(mainAxisSize: MainAxisSize.min, children: [Center(child: preview)]),
      actions: [
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          onPressed: () => Navigator.of(context).pop('remove'),
          icon: const Icon(Icons.delete_outline),
          label: const Text("Remove"),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop('replace'),
          icon: Icon(kind.addIcon),
          label: const Text("Replace"),
        ),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Done")),
      ],
    );
  }
}
