import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/widgets/cards_dialog.dart';
import 'package:quiz_show/features/games/widgets/companion_editor.dart';
import 'package:quiz_show/features/games/widgets/editor_section.dart';
import 'package:quiz_show/features/games/widgets/media_button.dart';
import 'package:quiz_show/features/games/widgets/settings_strip.dart';
import 'package:quiz_show/features/games/widgets/question_preview.dart';
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

  /// The order just dragged into place, until the saved one shows it too.
  List<String>? _order;

  List<Question> _ordered(List<Question> questions) {
    final order = _order;
    if (order == null) return questions;
    final ids = [for (final q in questions) q.id];
    if (ids.length != order.length || !ids.every(order.contains)) return questions;
    if (Iterable<int>.generate(ids.length).every((i) => ids[i] == order[i])) {
      _order = null;
      return questions;
    }
    return [for (final id in order) questions.firstWhere((q) => q.id == id)];
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
        // A category in its own order keeps it: the new question goes last.
        data: {if (last?.position != null) 'questionIndex': last!.position! + 1},
      );
      if (mounted) setState(() => _fresh = id);
    });
  }

  /// Who of the limited members sees this category besides its creator.
  static String _sharedSummary(Category category) {
    final count = category.data['access'] is List ? (category.data['access'] as List).length : 0;
    return count == 0 ? "Not shared" : (count == 1 ? "With 1 person" : "With $count people");
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameSnapshot>(
      stream: _game,
      builder: (context, snapshot) {
        final category = snapshot.data?.content.category(widget.categoryId);
        if (snapshot.hasError || (snapshot.hasData && category == null)) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text("This category is not available.")),
          );
        }
        if (category == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CupertinoActivityIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(category.name.isEmpty ? "Unnamed" : category.name),
            actions: [IconButton(icon: const Icon(Icons.edit_outlined), tooltip: "Rename", onPressed: () => _rename(category))],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addQuestion(category),
            icon: const Icon(Icons.add),
            label: const Text("Add question"),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
            children: [
              // What this category brings beyond its questions.
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: SettingsStrip(
                  tiles: [
                    SettingTile(
                      icon: Icons.queue_music,
                      title: "Music & sounds",
                      summary: soundsSummary(category.sounds, inherited: "Uses the board's"),
                      isSet: category.sounds.slots.isNotEmpty || category.sounds.effects.isNotEmpty,
                      onTap: () => showSoundsDialog(
                        context,
                        gameId: widget.gameId,
                        title: "Sounds for this category",
                        data: category.data,
                        save: (update) => guarded(context, () => _repo.updateCategory(widget.gameId, category.id, update)),
                      ),
                    ),
                    SettingTile(
                      icon: Icons.style_outlined,
                      title: "Cards",
                      summary: cardsSummary(category.cards, none: "Only the board's and game's"),
                      isSet: category.cards.isNotEmpty,
                      onTap: () => showCardsDialog(
                        context,
                        gameId: widget.gameId,
                        title: "Cards for this category",
                        cards: category.cards,
                        save: (cards) => guarded(context, () => _repo.updateCategory(widget.gameId, category.id, {'cards': cards})),
                      ),
                    ),
                    if (_canShare(snapshot.data!, category))
                      SettingTile(
                        icon: Icons.person_add_alt,
                        title: "Share",
                        summary: _sharedSummary(category),
                        isSet: _sharedSummary(category) != "Not shared",
                        onTap: () => _share(snapshot.data!, category),
                      ),
                  ],
                ),
              ),
              if (category.questions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text("No questions yet.")),
                ),
              Builder(
                builder: (context) {
                  final questions = _ordered(category.questions);
                  return ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: questions.length,
                    // onReorderItem replaces this from Flutter 3.41 on; kept for older SDKs in CI.
                    // ignore: deprecated_member_use
                    onReorder: (from, to) {
                      if (to > from) to--;
                      final ids = [for (final q in questions) q.id];
                      ids.insert(to, ids.removeAt(from));
                      setState(() => _order = ids);
                      guarded(context, () => _repo.reorderQuestions(widget.gameId, category.id, ids));
                    },
                    itemBuilder: (context, i) => QuestionCard(
                      key: ValueKey(questions[i].id),
                      gameId: widget.gameId,
                      categoryId: category.id,
                      question: questions[i],
                      initiallyExpanded: questions[i].id == _fresh,
                      reorderIndex: questions.length > 1 ? i : null,
                    ),
                  );
                },
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
    this.reorderIndex,
  });

  final String gameId;
  final String categoryId;
  final Question question;
  final bool initiallyExpanded;

  /// Its place in a reorderable list; null without a drag handle.
  final int? reorderIndex;

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

  /// Kept here so the switch moves at once, before the write comes back.
  late _Scoring _scoring = widget.question.amountBet != null
      ? _Scoring.amount
      : widget.question.wager
      ? _Scoring.points
      : widget.question.rankStep != null
      ? _Scoring.ranked
      : _Scoring.fixed;
  late final TextEditingController _rankStep = TextEditingController(text: (widget.question.rankStep ?? 100).toString());
  late final TextEditingController _betPrompt = TextEditingController(text: widget.question.amountBet?.prompt ?? '');
  late final TextEditingController _betMax = TextEditingController(text: (widget.question.amountBet?.max ?? kDefaultAmountMax).toString());

  /// How the question is scored as far as its type allows.
  _Scoring get _effectiveScoring => switch (_scoring) {
    _Scoring.amount when _q.type == QuestionType.free => _Scoring.amount,
    _Scoring.points || _Scoring.amount when _q.type.wagerable => _Scoring.points,
    _Scoring.ranked when _q.type.wagerable => _Scoring.ranked,
    _ => _Scoring.fixed,
  };

  void _setScoring(_Scoring scoring) {
    setState(() => _scoring = scoring);
    _save({
      'wager': scoring == _Scoring.points,
      'amountBet': scoring == _Scoring.amount ? _amountBet() : null,
      'rankStep': scoring == _Scoring.ranked ? (int.tryParse(_rankStep.text) ?? 100).clamp(0, 100000) : null,
    });
  }

  Map<String, dynamic> _amountBet() =>
      AmountBet(prompt: _betPrompt.text, max: (int.tryParse(_betMax.text) ?? kDefaultAmountMax).clamp(1, 999)).toMap();

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
    for (final controller in [_text, _description, _hint, _plus, _minus, _betPrompt, _betMax, _rankStep]) {
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

  Widget _points(TextEditingController controller, String label, String field) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label, isDense: true),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onChanged: (value) => _save({field: int.tryParse(value) ?? 0}),
  );

  /// Open or closed by the user; otherwise open where there is room (not on
  /// a phone), except media.
  final Map<String, bool> _sections = {};

  bool _isOpen(String section, bool roomy) => _sections[section] ?? (roomy && section != 'media');

  void _toggle(String section, bool roomy) => setState(() => _sections[section] = !_isOpen(section, roomy));

  late bool _expanded = widget.initiallyExpanded;
  late bool _showLabel = (widget.question.description ?? '').isNotEmpty;

  /// Survey duel and Word groups never take points away, nor does a lost bet
  /// of points cost more than the bet.
  bool get _hasMinus =>
      _effectiveScoring != _Scoring.points && _q.type != QuestionType.feud && _q.type != QuestionType.connections;

  /// "Free question · slider on the devices · by order"
  String get _subtitle {
    final companion = _q.companion;
    final devices = switch (_q.type) {
      QuestionType.connections || QuestionType.matching => null,
      QuestionType.rapidFire || QuestionType.topAnswers => companion == null ? null : "on the devices",
      _ => companion == null ? null : "${companion.kind.uiString.toLowerCase()} on the devices",
    };
    final scoring = switch (_effectiveScoring) {
      _Scoring.points => "teams bet",
      _Scoring.amount => "teams bet how many",
      _Scoring.ranked => "by order",
      _Scoring.fixed => null,
    };
    return [_q.type.uiString, ?devices, ?scoring].join(" · ");
  }

  String get _scoringSummary {
    final plus = _q.pointsPlus;
    final minus = _hasMinus && _q.pointsMinus > 0 ? _q.pointsMinus : null;
    return switch (_effectiveScoring) {
      _Scoring.fixed => [
        if (_q.type.wagerable) "Fixed",
        minus == null ? "+$plus" : "+$plus / −$minus",
      ].join(" · "),
      _Scoring.points => "Teams bet their points · at least ${plus > kMinBetLimit ? plus : kMinBetLimit} to bet",
      _Scoring.amount => "Bet on how many · ${minus == null ? "+$plus each" : "+$plus / −$minus each"}",
      _Scoring.ranked => [
        "By order · $plus, then −${_q.rankStep ?? 0} per place",
        if (minus != null) "wrong −$minus",
      ].join(" · "),
    };
  }

  String get _mediaSummary {
    final sounds = soundsSummary(_q.sounds, inherited: "");
    final parts = [if (_q.image != null) "Picture", if (_q.music != null) "Music", if (sounds.isNotEmpty) sounds];
    return parts.isEmpty ? "No picture, music or sounds of its own" : parts.join(" · ");
  }

  Widget _scoringSection(ThemeData theme) {
    final scoring = _effectiveScoring;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_q.type.wagerable) ...[
          FillDropdown<_Scoring>(
            label: "Rule",
            value: scoring,
            entries: [
              for (final option in _Scoring.values)
                if (option != _Scoring.amount || _q.type == QuestionType.free) DropdownMenuEntry(value: option, label: option.label),
            ],
            onSelected: (option) {
              if (option != null) _setScoring(option);
            },
          ),
          const SizedBox(height: 6),
          Text(switch (scoring) {
            _Scoring.fixed => "Every team plays for the same points.",
            _Scoring.ranked =>
              "The first team gets the most points, each after it a bit less. The order is the order teams locked in a "
                  "right answer on their devices, or the order you tap them in, e.g. as they finish on stage. "
                  "Wrong answers lose the minus points.",
            _Scoring.points =>
              "Before the question, each team bets some of its points: a right answer wins the bet, a wrong one loses it. "
                  "Teams may bet up to their score, or up to ${_q.pointsPlus > kMinBetLimit ? _q.pointsPlus : kMinBetLimit} "
                  "if they have less.",
            _Scoring.amount =>
              "First only the bet question is shown and each team says how many it can do. Then the question runs; "
                  "you decide per team whether it reached its number. Reached: the points for each one. "
                  "Missed: the minus points for each one.",
          }, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
        ],
        if (scoring == _Scoring.amount) ...[
          TextField(
            controller: _betPrompt,
            decoration: const InputDecoration(
              labelText: "Bet question",
              hintText: "How many science fiction films can you name?",
              isDense: true,
            ),
            minLines: 1,
            maxLines: 3,
            onChanged: (_) => _save({'amountBet': _amountBet()}),
          ),
          const SizedBox(height: 12),
        ],
        FieldGrid(
          minWidth: 130,
          children: [
            _points(_plus, switch (scoring) {
              _Scoring.points => "Points",
              _Scoring.amount => "Each +",
              _Scoring.ranked => "1st place +",
              _Scoring.fixed => "If right +",
            }, 'pointsPlus'),
            if (_hasMinus) _points(_minus, scoring == _Scoring.amount ? "Each −" : "If wrong −", 'pointsMinus'),
            if (scoring == _Scoring.ranked)
              TextField(
                controller: _rankStep,
                decoration: const InputDecoration(labelText: "Less per place", isDense: true),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (text) => _save({'rankStep': (int.tryParse(text) ?? 0).clamp(0, 100000)}),
              ),
            if (scoring == _Scoring.amount)
              TextField(
                controller: _betMax,
                decoration: const InputDecoration(labelText: "Highest bet", isDense: true),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _save({'amountBet': _amountBet()}),
              ),
          ],
        ),
        if (scoring == _Scoring.ranked)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "${[for (var place = 0; place < 4; place++) placePoints(_q, place)].join(" · ")} …",
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }

  Widget _media(ThemeData theme) {
    Widget row(MediaKind kind, String? name, String none, String field) => Row(
      children: [
        MediaButton(gameId: widget.gameId, kind: kind, name: name, onChanged: (name) => _save({field: name})),
        const SizedBox(width: 4),
        Expanded(child: Text(name ?? none, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(MediaKind.image, _q.image, "No picture", 'image'),
        row(MediaKind.audio, _q.music, "No music", 'music'),
        ListTile(
          contentPadding: const EdgeInsets.only(left: 8),
          leading: const Icon(Icons.queue_music),
          title: const Text("Music & effects"),
          subtitle: Text(soundsSummary(_q.sounds, inherited: "The category's")),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showSoundsDialog(context, gameId: widget.gameId, title: "Sounds for this question", data: _q.data, save: _save),
        ),
      ],
    );
  }

  /// The question itself and the type's content beside (wide) or above the
  /// sections with how it is played.
  Widget _arrange(bool wide, bool roomy, Widget? typeSettings, Widget typeContent) {
    final theme = Theme.of(context);
    // A Fragenhagel, matching and top answers bring their own settings.
    final answering =
        typeSettings ??
        (_q.type == QuestionType.rapidFire || _q.type == QuestionType.matching || _q.type == QuestionType.topAnswers
            ? null
            : CompanionEditor(key: ValueKey('companion-${_q.type}'), gameId: widget.gameId, question: _q, save: _save));
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FillDropdown<QuestionType>(
          label: "Type",
          value: _q.type,
          entries: [
            for (final type in QuestionType.values)
              if (type != QuestionType.unsupported || _q.type == type) DropdownMenuEntry(value: type, label: type.uiString),
          ],
          onSelected: (type) {
            if (type != null && type != QuestionType.unsupported) _save({'type': type.name});
          },
        ),
        const SizedBox(height: 4),
        Text(questionTypeExplanation(_q.type), style: theme.textTheme.bodySmall),
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
          controller: _hint,
          decoration: const InputDecoration(labelText: "Answer hint", helperText: "Only the gamemaster sees this"),
          minLines: 1,
          maxLines: 4,
          onChanged: (value) => _save({'answerHint': value}),
        ),
        const SizedBox(height: 8),
        if (_showLabel) ...[
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: "Label", helperText: "Small badge shown on the question card"),
            onChanged: (value) => _save({'description': value}),
          ),
          const SizedBox(height: 8),
        ] else
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const Icon(Icons.add),
              label: const Text("Label"),
              tooltip: "A small badge shown on the question card",
              onPressed: () => setState(() => _showLabel = true),
            ),
          ),
        typeContent,
      ],
    );
    final sections = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (answering != null)
          EditorSection(
            icon: Icons.touch_app_outlined,
            title: "How teams answer",
            summary: answeringSummary(_q),
            open: _isOpen('answer', roomy),
            onToggle: () => _toggle('answer', roomy),
            child: answering,
          ),
        EditorSection(
          icon: Icons.scoreboard_outlined,
          title: "Scoring",
          summary: _scoringSummary,
          open: _isOpen('scoring', roomy),
          onToggle: () => _toggle('scoring', roomy),
          child: _scoringSection(theme),
        ),
        EditorSection(
          icon: Icons.perm_media_outlined,
          title: "Media & sound",
          summary: _mediaSummary,
          open: _isOpen('media', roomy),
          onToggle: () => _toggle('media', roomy),
          child: _media(theme),
        ),
      ],
    );
    if (!wide) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [main, const SizedBox(height: 8), sections]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: main),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: sections),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
        shape: const Border(),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.reorderIndex != null)
              ReorderableDragStartListener(
                index: widget.reorderIndex!,
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.drag_indicator, semanticLabel: "Move question"),
                ),
              ),
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                _q.pointsPlus.toString(),
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
        title: Text(_q.text.isEmpty ? "New question" : _q.text, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(_subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_expanded) ...[
              IconButton(
                icon: const Icon(Icons.visibility_outlined),
                tooltip: "Preview",
                onPressed: () {
                  _flush();
                  showQuestionPreview(context, gameId: widget.gameId, categoryId: widget.categoryId, question: _q);
                },
              ),
              IconButton(icon: const Icon(Icons.delete_outline), tooltip: "Delete question", onPressed: _delete),
            ],
            Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 860;
              final roomy = box.maxWidth >= 560;
              return QuestionTypeEditor(
                key: ValueKey(_q.type),
                gameId: widget.gameId,
                question: _q,
                save: _save,
                onImported: (text, answerHint) {
                  _text.text = text;
                  _hint.text = answerHint;
                },
                layout: (settings, content) => _arrange(wide, roomy, settings, content),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// How a question is scored: fixed points, bets of points, or bets on how
/// many a team can do.
enum _Scoring {
  fixed("Fixed points"),
  points("Teams bet their points"),
  amount("Teams bet how many they can do"),
  ranked("By order: fastest first");

  const _Scoring(this.label);

  final String label;
}
