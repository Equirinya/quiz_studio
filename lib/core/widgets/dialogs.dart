import 'package:flutter/material.dart';
import 'package:quiz_show/l10n/l10n.dart';

/// Asks for one line of text. Returns null when cancelled or left empty.
/// Asks for a text. [multiline] gives room for several lines, entered with
/// Enter; saving is then only by the button.
Future<String?> promptText(BuildContext context, {required String title, String initial = '', String? label, bool multiline = false}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) {
      void submit() {
        final text = controller.text.trim();
        Navigator.of(context).pop(text.isEmpty ? null : text);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: multiline ? 3 : 1,
          maxLines: multiline ? 8 : 1,
          keyboardType: multiline ? TextInputType.multiline : null,
          decoration: InputDecoration(labelText: label, alignLabelWithHint: multiline),
          onSubmitted: multiline ? null : (_) => submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: submit, child: Text(context.l10n.save)),
        ],
      );
    },
  );
}

/// Asks before something that cannot be undone.
Future<bool> confirm(BuildContext context, {required String title, required String message, required String action}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.l10n.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}

/// Runs [action] and reports a failure in a snackbar instead of dropping it.
Future<void> guarded(BuildContext context, Future<void> Function() action, {String? failure}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final message = failure ?? context.l10n.thatDidntWork;
  try {
    await action();
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}
