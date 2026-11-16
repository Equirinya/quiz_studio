import 'package:flutter/material.dart';

import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// Large uploads (a video, a long recording) in a card at the bottom of the
/// screen, over whatever page is open, until they are done: the editor can
/// be left while they go on.
class UploadsNotice extends StatelessWidget {
  const UploadsNotice({super.key, required this.child});

  final Widget child;

  static String _size(int bytes) {
    final mb = bytes / (1024 * 1024);
    return mb >= 1000 ? '${(mb / 1024).toStringAsFixed(1)} GB' : '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<List<MediaUpload>>(
          valueListenable: MediaService.instance.uploads,
          builder: (context, uploads, _) {
            final large = uploads.where((upload) => upload.large).toList();
            return Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Center(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: large.isEmpty
                        ? const SizedBox(width: double.infinity)
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Card(
                              elevation: 6,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [for (final upload in large) _UploadRow(upload: upload, size: _size)],
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _UploadRow extends StatelessWidget {
  const _UploadRow({required this.upload, required this.size});

  final MediaUpload upload;
  final String Function(int bytes) size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: upload.progress,
      builder: (context, progress, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.cloud_upload_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.uploadingFile(upload.label), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: progress == 0 ? null : progress, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 4),
                  Text(
                    '${context.l10n.uploadSizeOf(size((upload.totalBytes * progress).round()), size(upload.totalBytes))} · ${(progress * 100).round()} %',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
