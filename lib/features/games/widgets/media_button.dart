import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/games/media_service.dart';

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

/// Attaches one media file to a document field: tap to pick and upload, tap
/// again to remove. [onChanged] receives the stored file name, or null.
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

class _MediaButtonState extends State<MediaButton> {
  bool _busy = false;

  bool get _attached => widget.name != null && widget.name!.isNotEmpty;

  Future<void> _add() async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await widget.kind.pick();
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    try {
      widget.onChanged(await MediaService.instance.upload(widget.gameId, path));
    } on UnsupportedError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message ?? "This file type is not supported.")));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text("Could not upload the ${widget.kind.noun}.")));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove() async {
    final sure = await confirm(
      context,
      title: "Remove ${widget.kind.noun}",
      message: "The ${widget.kind.noun} will be removed from this question.",
      action: "Remove",
    );
    if (!sure) return;
    final old = widget.name!;
    widget.onChanged(null);
    MediaService.instance.delete(widget.gameId, old);
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox(width: 48, height: 48, child: Center(child: CupertinoActivityIndicator()));
    }
    return IconButton(
      tooltip: _attached ? "Remove ${widget.kind.noun}" : "Add ${widget.kind.noun}",
      icon: Icon(_attached ? widget.kind.presentIcon : widget.kind.addIcon),
      color: _attached ? Theme.of(context).colorScheme.primary : null,
      onPressed: _attached ? _remove : _add,
    );
  }
}
