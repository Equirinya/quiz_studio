import 'package:flutter/material.dart';

/// Asks for one line of text. Returns null when cancelled or left empty.
Future<String?> promptText(BuildContext context, {required String title, String initial = '', String? label}) {
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
          decoration: InputDecoration(labelText: label),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
          FilledButton(onPressed: submit, child: const Text("Save")),
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
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}

/// Runs [action] and reports a failure in a snackbar instead of dropping it.
Future<void> guarded(BuildContext context, Future<void> Function() action, {String failure = "That didn't work."}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await action();
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(failure)));
  }
}
