import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/features/games/widgets/question_type_editors.dart';
import 'package:quiz_show/features/games/widgets/sounds_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quiz_show/features/auth/widgets/user_name.dart';
import 'package:quiz_show/game/game.dart';

/// One category and its questions.
class CategoryEditorPage extends StatefulWidget {
  const CategoryEditorPage({super.key, required this.gameId, required this.categoryId});

  final String gameId;
  final String categoryId;

  @override
  State<CategoryEditorPage> createState() => _CategoryEditorPageState();
}

class _CategoryEditorPageState extends State<CategoryEditorPage> {
  late final Stream<GameSnapshot> _game = GameRepository.instance.watchGame(widget.gameId);

  /// The question to open expanded: the one just added.
  String? _fresh;

  GameRepository get _repo => GameRepository.instance;

  Future<void> _rename(Category category) async {
    final name = await promptText(context, title: "Rename category", initial: category.name, label: "Name");
    if (name == null || !mounted) return;
    await guarded(context, () => _repo.updateCategory(widget.gameId, category.id, {'name': name}));
  }

  /// Full members and the category's creator decide who else sees it.
  bool _canShare(GameSnapshot game, Category category) {
    final limited = game.data[GameRole.limited.name];
    if (limited is! List || limited.isEmpty) return false;
    return game.role.seesEverything || category.data['createdBy'] == FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _share(GameSnapshot game, Category category) {
    final limited = List<String>.from(game.data[GameRole.limited.name] as List);
    final shared = {...(category.data['access'] as List? ?? const []).whereType<String>()};
    final creator = category.data['createdBy'];
    return showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Share category"),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text("Members with limited access only see the categories switched on here."),
                for (final uid in limited)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: UserName(uid),
                    subtitle: uid == creator ? const Text("Created this category") : null,
                    value: uid == creator || shared.contains(uid),
                    onChanged: uid == creator
                        ? null
                        : (value) {
                            setState(() => value ? shared.add(uid) : shared.remove(uid));
                            guarded(context, () => _repo.shareCategory(widget.gameId, category.id, uid, value));
                          },
                  ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Done"))],
        ),
      ),
    );
  }

  Future<void> _addQuestion(Category category) async {
    // Continue the category's point ladder instead of starting at zero.
    final last = category.questions.lastOrNull;
    final previous = category.questions.length > 1 ? category.questions[category.questions.length - 2] : null;
    final step = last == null ? 100 : (previous == null ? last.pointsPlus : last.pointsPlus - previous.pointsPlus);
    await guarded(context, () async {
      final id = await _repo.addQuestion(
        widget.gameId,
        category.id,
        pointsPlus: (last?.pointsPlus ?? 0) + (step > 0 ? step : 100),
        pointsMinus: last?.pointsMinus ?? 0,
      );
      if (mounted) setState(() => _fresh = id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameSnapshot>(
      stream: _game,
      builder: (context, snapshot) {
        final category = snapshot.data?.content.category(widget.categoryId);
        if (snapshot.hasError || (snapshot.hasData && category == null)) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text("This category is not available.")));
        }
        if (category == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CupertinoActivityIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(category.name.isEmpty ? "Unnamed" : category.name),
            actions: [
              if (_canShare(snapshot.data!, category))
                IconButton(
                  icon: const Icon(Icons.person_add_alt),
                  tooltip: "Share with limited members",
                  onPressed: () => _share(snapshot.data!, category),
                ),
              IconButton(
                icon: const Icon(Icons.queue_music),
                tooltip: "Music and effects",
                onPressed: () => showSoundsDialog(
                  context,
                  gameId: widget.gameId,
                  title: "Sounds for this category",
                  data: category.data,
                  save: (update) => guarded(context, () => _repo.updateCategory(widget.gameId, category.id, update)),
                ),
              ),
              IconButton(icon: const Icon(Icons.edit_outlined), tooltip: "Rename", onPressed: () => _rename(category)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addQuestion(category),
            icon: const Icon(Icons.add),
            label: const Text("Add question"),
          ),
          body: category.questions.isEmpty
              ? const Center(child: Text("No questions yet."))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                  children: [
                    for (final question in category.questions)
                      QuestionCard(
                        key: ValueKey(question.id),
                        gameId: widget.gameId,
                        categoryId: category.id,
                        question: question,
                        initiallyExpanded: question.id == _fresh,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// Edits one question. Text is written a moment after typing stops, so the
/// stream echoing a change back never moves the cursor.
class QuestionCard extends StatefulWidget {
  const QuestionCard({
    super.key,
    required this.gameId,
    required this.categoryId,
    required this.question,
    this.initiallyExpanded = false,
  });

  final String gameId;
  final String categoryId;
  final Question question;
  final bool initiallyExpanded;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  late final TextEditingController _text = TextEditingController(text: widget.question.text);
  late final TextEditingController _description = TextEditingController(text: widget.question.description ?? '');
  late final TextEditingController _hint = TextEditingController(text: widget.question.answerHint ?? '');
  late final TextEditingController _plus = TextEditingController(text: widget.question.pointsPlus.toString());
  late final TextEditingController _minus = TextEditingController(text: widget.question.pointsMinus.toString());

  final Map<String, dynamic> _pending = {};
  Timer? _timer;

  Question get _q => widget.question;

  /// Queues a write; fields changed in quick succession go out together.
  void _save(Map<String, dynamic> data) {
    _pending.addAll(data);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), _flush);
  }

  void _flush() {
    _timer?.cancel();
    if (_pending.isEmpty) return;
    final data = Map<String, dynamic>.of(_pending);
    _pending.clear();
    GameRepository.instance.updateQuestion(widget.gameId, widget.categoryId, _q.id, data).catchError((Object _) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text("Could not save.")));
    });
  }

  @override
  void dispose() {
    _flush();
    for (final controller in [_text, _description, _hint, _plus, _minus]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _delete() async {
    final sure = await confirm(context, title: "Delete question", message: "This question will be deleted.", action: "Delete");
    if (!sure) return;
    _pending.clear();
    await GameRepository.instance.deleteQuestion(widget.gameId, widget.categoryId, _q.id);
  }

  Widget _points(TextEditingController controller, String label, String field) => SizedBox(
        width: 110,
        child: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) => _save({field: int.tryParse(value) ?? 0}),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            _q.pointsPlus.toString(),
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        title: Text(_q.text.isEmpty ? "New question" : _q.text, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(_q.type.uiString),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownMenu<QuestionType>(
                label: const Text("Type"),
                initialSelection: _q.type,
                dropdownMenuEntries: [
                  for (final type in QuestionType.values)
                    if (type != QuestionType.unsupported || _q.type == type) DropdownMenuEntry(value: type, label: type.uiString),
                ],
                onSelected: (type) {
                  if (type != null && type != QuestionType.unsupported) _save({'type': type.name});
                },
              ),
              _points(_plus, "Points if right", 'pointsPlus'),
              _points(_minus, "Points if wrong", 'pointsMinus'),
              MediaButton(
                gameId: widget.gameId,
                kind: MediaKind.image,
                name: _q.image,
                onChanged: (name) => _save({'image': name}),
              ),
              MediaButton(
                gameId: widget.gameId,
                kind: MediaKind.audio,
                name: _q.music,
                onChanged: (name) => _save({'music': name}),
              ),
              IconButton(
                icon: const Icon(Icons.queue_music),
                tooltip: "Music and effects",
                onPressed: () => showSoundsDialog(
                  context,
                  gameId: widget.gameId,
                  title: "Sounds for this question",
                  data: _q.data,
                  save: _save,
                ),
              ),
              IconButton(icon: const Icon(Icons.delete_outline), tooltip: "Delete question", onPressed: _delete),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            decoration: const InputDecoration(labelText: "Question"),
            minLines: 1,
            maxLines: 4,
            onChanged: (value) => _save({'question': value}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: "Label", helperText: "Small badge shown on the question card"),
            onChanged: (value) => _save({'description': value}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hint,
            decoration: const InputDecoration(labelText: "Answer hint", helperText: "Only the gamemaster sees this"),
            minLines: 1,
            maxLines: 4,
            onChanged: (value) => _save({'answerHint': value}),
          ),
          const SizedBox(height: 12),
          Text(questionTypeExplanation(_q.type), style: theme.textTheme.bodySmall),
          QuestionTypeEditor(
            key: ValueKey(_q.type),
            gameId: widget.gameId,
            question: _q,
            save: _save,
            onImported: (text, answerHint) {
              _text.text = text;
              _hint.text = answerHint;
            },
          ),
        ],
      ),
    );
  }
}
