import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// The pictures, sound and video of a question or of one item, one row each.
/// Any number of pictures; they are shown side by side on the big screen.
class MediaSetFields extends StatelessWidget {
  const MediaSetFields({super.key, required this.gameId, required this.media, required this.onChanged});

  final String gameId;
  final MediaSet media;
  final ValueChanged<MediaSet> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final images = media.images;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < images.length; i++)
          MediaButton.tile(
            key: ValueKey('$i/${images[i]}'),
            gameId: gameId,
            kind: MediaKind.image,
            name: images[i],
            title: images.length > 1 ? l10n.pictureN(i + 1) : l10n.picture,
            onChanged: (name) => onChanged(media.copyWith(images: [...images.take(i), ?name, ...images.skip(i + 1)])),
          ),
        // Always one more to add.
        MediaButton.tile(
          key: ValueKey('add/${images.length}'),
          gameId: gameId,
          kind: MediaKind.image,
          name: null,
          title: images.isEmpty ? l10n.addMedia(MediaKind.image.name) : l10n.addAnotherPicture,
          subtitle: images.isEmpty ? null : l10n.morePicturesHint,
          onChanged: (name) {
            if (name != null) onChanged(media.copyWith(images: [...images, name]));
          },
        ),
        MediaButton.tile(
          gameId: gameId,
          kind: MediaKind.audio,
          name: media.music,
          title: media.music == null ? l10n.addMedia(MediaKind.audio.name) : l10n.sound,
          onChanged: (name) => onChanged(media.copyWith(music: name)),
        ),
        // Started from the controller like the music, in the picture's place.
        MediaButton.tile(
          gameId: gameId,
          kind: MediaKind.video,
          name: media.video,
          title: media.video == null ? l10n.addMedia(MediaKind.video.name) : l10n.video,
          subtitle: l10n.videoHint,
          onChanged: (name) => onChanged(media.copyWith(video: name)),
        ),
      ],
    );
  }
}

/// One small button for an item's media: shows what it has, and opens
/// [MediaSetFields] in a dialog.
class MediaSetButton extends StatelessWidget {
  const MediaSetButton({super.key, required this.gameId, required this.media, required this.onChanged});

  final String gameId;
  final MediaSet media;
  final ValueChanged<MediaSet> onChanged;

  Future<void> _open(BuildContext context) async {
    var current = media;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.media),
          content: SizedBox(
            width: 420,
            child: MediaSetFields(
              gameId: gameId,
              media: current,
              onChanged: (next) {
                setState(() => current = next);
                onChanged(next);
              },
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.done))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icons = [
      if (media.images.isNotEmpty) MediaKind.image.presentIcon,
      if (media.music != null) MediaKind.audio.presentIcon,
      if (media.video != null) MediaKind.video.presentIcon,
    ];
    final count = media.images.length;
    return IconButton(
      tooltip: context.l10n.media,
      onPressed: () => _open(context),
      icon: icons.isEmpty
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
  }
}
