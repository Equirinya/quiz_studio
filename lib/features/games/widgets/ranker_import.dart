import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// A Feud question built from a ranker.com list.
class RankerImport {
  const RankerImport({required this.title, required this.answers, required this.percentages, required this.answerHint});

  final String title;
  final List<String> answers;
  final List<double> percentages;
  final String answerHint;
}

final RegExp _rankerUrl =
    RegExp(r'^https?://(www\.)?ranker\.com/(list/[^/]+/[^/]+|crowdranked-list/[^/]+)', caseSensitive: false);

bool isRankerListUrl(String url) => _rankerUrl.hasMatch(url.trim());

/// Finds the numeric list id in a ranker list page.
String? rankerListId(String pageHtml) =>
    RegExp(r'"listId"\s*:\s*(\d+)', caseSensitive: false).firstMatch(pageHtml)?.group(1) ??
    RegExp(r'imgix\.ranker\.com/list_img_v2/\d+/(\d+)', caseSensitive: false).firstMatch(pageHtml)?.group(1);

/// Turns ranked items into Feud answers. The top ten become answers; their
/// share is the vote score above the first item left out, so the weakest
/// answer is worth little rather than a tenth. The rest go into the answer
/// hint as reference for the gamemaster.
RankerImport buildRankerImport({
  required String title,
  required String source,
  required List<({String name, double score})> items,
}) {
  final split = items.length < 11 ? items.length - 1 : 10;
  final shown = items.sublist(0, split);
  final rest = items.sublist(split);
  final baseline = rest.isEmpty ? 0.0 : rest.first.score;
  final raw = [for (final item in shown) (item.score - baseline).clamp(0.0, double.infinity).toDouble()];
  final total = raw.fold(0.0, (sum, value) => sum + value);
  final hint = StringBuffer(source);
  if (rest.isNotEmpty) {
    hint.write('\n\nReference items (not shown):');
    for (final (i, item) in rest.indexed) {
      hint.write('\n${split + i + 1}. ${item.name}');
    }
  }
  return RankerImport(
    title: title,
    answers: [for (final item in shown) item.name],
    percentages: [for (final value in raw) total <= 0 ? 100.0 / shown.length : value / total * 100.0],
    answerHint: hint.toString(),
  );
}

Future<RankerImport> fetchRankerImport(String url, {http.Client? client}) async {
  final get = client?.get ?? http.get;
  // The site only serves the full page, list id included, to link previewers.
  final page = await get(Uri.parse(url), headers: {"User-Agent": "Twitterbot"});
  if (page.statusCode != 200) throw Exception("The page could not be loaded (${page.statusCode}).");
  final listId = rankerListId(page.body);
  if (listId == null) throw Exception("No list was found on that page.");

  final info = await get(Uri.parse('https://api.ranker.com/lists/$listId'));
  if (info.statusCode != 200) throw Exception("The list could not be loaded (${info.statusCode}).");
  final infoJson = jsonDecode(info.body) as Map<String, dynamic>;
  final title = (infoJson['name'] ?? infoJson['displayName'] ?? infoJson['title'] ?? 'Imported list').toString();

  final itemsResponse = await get(Uri.parse('https://api.ranker.com/lists/$listId/items?limit=20'));
  if (itemsResponse.statusCode != 200) throw Exception("The list items could not be loaded (${itemsResponse.statusCode}).");
  final listItems = (jsonDecode(itemsResponse.body) as Map<String, dynamic>)['listItems'] as List? ?? const [];
  if (listItems.length < 2) throw Exception("The list has too few entries.");

  return buildRankerImport(
    title: title,
    source: 'Ranker: $url (listId:$listId)',
    items: [
      for (final item in listItems.cast<Map<String, dynamic>>())
        (
          name: ((item['node'] as Map<String, dynamic>?)?['name'] ?? item['name'] ?? '').toString(),
          score: ((item['voteScore'] ?? 0) as num).toDouble(),
        ),
    ],
  );
}

/// Asks for a ranker.com list URL and returns the question built from it.
Future<RankerImport?> showRankerImportDialog(BuildContext context) =>
    showDialog<RankerImport>(context: context, builder: (_) => const _RankerImportDialog());

class _RankerImportDialog extends StatefulWidget {
  const _RankerImportDialog();

  @override
  State<_RankerImportDialog> createState() => _RankerImportDialogState();
}

class _RankerImportDialogState extends State<_RankerImportDialog> {
  final TextEditingController _url = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final url = _url.text.trim();
    if (!isRankerListUrl(url)) {
      setState(() => _error = "Enter a ranker.com list URL, e.g. https://www.ranker.com/list/best-smells/jacob-shelton");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await fetchRankerImport(url);
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is Exception ? error.toString().replaceFirst('Exception: ', '') : "The import failed.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Import from Ranker"),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("The top ten entries of the list replace this question's answers."),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              autofocus: true,
              enabled: !_loading,
              decoration: const InputDecoration(labelText: "Ranker list URL"),
              onSubmitted: (_) => _import(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(), child: const Text("Cancel")),
        FilledButton(
          onPressed: _loading ? null : _import,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Import"),
        ),
      ],
    );
  }
}
