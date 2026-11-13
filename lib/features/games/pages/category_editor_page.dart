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
import 'package:quiz_show/l10n/l10n.dart';

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
    final name = await promptText(context, title: context.l10n.renameCategory, initial: category.name, label: context.l10n.name);
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
          title: Text(context.l10n.shareCategory),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(context.l10n.shareCategoryText),
                for (final uid in limited)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: UserName(uid),
                    subtitle: uid == creator ? Text(context.l10n.createdThisCategory) : null,
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
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.done))],
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
  static String _sharedSummary(AppLocalizations l10n, Category category) {
    final count = category.data['access'] is List ? (category.data['access'] as List).length : 0;
    return count == 0 ? l10n.notShared : l10n.sharedWith(count);
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
            body: Center(child: Text(context.l10n.categoryNotAvailable)),
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
            title: Text(category.name.isEmpty ? context.l10n.unnamed : category.name),
            actions: [IconButton(icon: const Icon(Icons.edit_outlined), tooltip: context.l10n.rename, onPressed: () => _rename(category))],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addQuestion(category),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.addQuestion),
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
                      title: context.l10n.musicAndSounds,
                      summary: soundsSummary(context.l10n, category.sounds, inherited: context.l10n.usesBoards),
                      isSet: category.sounds.slots.isNotEmpty || category.sounds.effects.isNotEmpty,
                      onTap: () => showSoundsDialog(
                        context,
                        gameId: widget.gameId,
                        title: context.l10n.soundsForCategory,
                        data: category.data,
                        save: (update) => guarded(context, () => _repo.updateCategory(widget.gameId, category.id, update)),
                      ),
                    ),
                    SettingTile(
                      icon: Icons.style_outlined,
                      title: context.l10n.cards,
                      summary: cardsSummary(context.l10n, category.cards, none: context.l10n.onlyBoardsAndGames),
                      isSet: category.cards.isNotEmpty,
                      onTap: () => showCardsDialog(
                        context,
                        gameId: widget.gameId,
                        title: context.l10n.cardsForCategory,
                        cards: category.cards,
                        save: (cards) => guarded(context, () => _repo.updateCategory(widget.gameId, category.id, {'cards': cards})),
                      ),
                    ),
                    if (_canShare(snapshot.data!, category))
                      SettingTile(
                        icon: Icons.person_add_alt,
                        title: context.l10n.share,
                        summary: _sharedSummary(context.l10n, category),
                        isSet: _sharedSummary(context.l10n, category) != context.l10n.notShared,
                        onTap: () => _share(snapshot.data!, category),
                      ),
                  ],
                ),
              ),
              if (category.questions.isEmpty)
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text(context.l10n.noQuestionsYet)),
                ),
              Builder(builder: (context) {
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
              }),
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
      : widget.question.rankStep != null && widget.question.closest
      ? _Scoring.closest
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
    _Scoring.closest when _closable => _Scoring.closest,
    _ => _Scoring.fixed,
  };

  /// Numbers and sliders on the devices can go by how close teams came.
  bool get _closable => switch (_q.companion?.kind) {
    CompanionKind.number || CompanionKind.slider => !_q.hasBets,
    _ => false,
  };

  bool get _byPlace => _effectiveScoring == _Scoring.ranked || _effectiveScoring == _Scoring.closest;

  void _setScoring(_Scoring scoring) {
    setState(() => _scoring = scoring);
    _save({
      'wager': scoring == _Scoring.points,
      'amountBet': scoring == _Scoring.amount ? _amountBet() : null,
      'rankStep': scoring == _Scoring.ranked || scoring == _Scoring.closest ? (int.tryParse(_rankStep.text) ?? 100).clamp(0, 100000) : null,
      'closest': scoring == _Scoring.closest ? true : null,
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
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.l10n.couldNotSave)));
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
    final sure = await confirm(context, title: context.l10n.deleteQuestion, message: context.l10n.deleteQuestionText, action: context.l10n.delete);
    if (!sure) return;
    _pending.clear();
    await GameRepository.instance.deleteQuestion(widget.gameId, widget.categoryId, _q.id);
  }

  Widget _points(TextEditingController controller, String label, String field, {String? helper}) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label, isDense: true, helperText: helper),
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

  /// Put in order: how it is scored, shown at once while the write is queued.
  late OrderScoring _orderScoring = widget.question.ordering?.scoring ?? OrderScoring.places;

  /// Survey duel and Word groups never take points away, nor does a lost bet
  /// of points cost more than the bet.
  bool get _hasMinus =>
      _effectiveScoring != _Scoring.points &&
      _effectiveScoring != _Scoring.closest &&
      _q.type != QuestionType.feud &&
      _q.type != QuestionType.connections &&
      _q.type != QuestionType.lastStanding;

  /// "Free question · slider on the devices · by order"
  String get _subtitle {
    final companion = _q.companion;
    final l10n = context.l10n;
    final devices = switch (_q.type) {
      QuestionType.connections || QuestionType.matching || QuestionType.ordering => null,
      QuestionType.rapidFire || QuestionType.topAnswers => companion == null ? null : l10n.onTheDevices,
      _ => companion == null ? null : l10n.kindOnTheDevices(l10n.inline(l10n.companionKind(companion.kind))),
    };
    final scoring = switch (_effectiveScoring) {
      _Scoring.points => l10n.teamsBetShort,
      _Scoring.amount => l10n.teamsBetHowManyShort,
      _Scoring.ranked => l10n.byOrderShort,
      _Scoring.closest => l10n.byClosenessShort,
      _Scoring.fixed => null,
    };
    return [l10n.questionType(_q.type), ?devices, ?scoring].join(" · ");
  }

  String get _scoringSummary {
    final plus = _q.pointsPlus;
    final minus = _hasMinus && _q.pointsMinus > 0 ? _q.pointsMinus : null;
    final l10n = context.l10n;
    return switch (_effectiveScoring) {
      _Scoring.fixed => [if (_q.type.wagerable) l10n.fixed, minus == null ? "+$plus" : "+$plus / −$minus"].join(" · "),
      _Scoring.points => l10n.pointsBetSummary(plus > kMinBetLimit ? plus : kMinBetLimit),
      _Scoring.amount => "${l10n.betOnHowMany} · ${minus == null ? l10n.plusEach(plus) : l10n.plusMinusEach(plus, minus)}",
      _Scoring.ranked => [l10n.byOrderSummary(plus, _q.rankStep ?? 0), if (minus != null) l10n.wrongMinus(minus)].join(" · "),
      _Scoring.closest => l10n.byClosenessSummary(plus, _q.rankStep ?? 0),
    };
  }

  String get _mediaSummary {
    final l10n = context.l10n;
    final sounds = soundsSummary(l10n, _q.sounds, inherited: "");
    final parts = [if (_q.image != null) l10n.picture, if (_q.music != null) l10n.music, if (sounds.isNotEmpty) sounds];
    return parts.isEmpty ? l10n.noOwnMedia : parts.join(" · ");
  }

  Widget _scoringSection(ThemeData theme) {
    final scoring = _effectiveScoring;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_q.type.wagerable) ...[
          FillDropdown<_Scoring>(
            label: l10n.rule,
            value: scoring,
            entries: [
              for (final option in _Scoring.values)
                if ((option != _Scoring.amount || _q.type == QuestionType.free) && (option != _Scoring.closest || _closable))
                  DropdownMenuEntry(value: option, label: l10n.scoringRuleName(option.name)),
            ],
            onSelected: (option) {
              if (option != null) _setScoring(option);
            },
          ),
          const SizedBox(height: 6),
          Text(switch (scoring) {
            _Scoring.fixed => l10n.scoringFixedText,
            _Scoring.ranked => l10n.scoringRankedText,
            _Scoring.closest => _q.companion?.solution == null ? l10n.scoringClosenessNoSolution : l10n.scoringClosenessText,
            _Scoring.points => l10n.scoringPointsText(_q.pointsPlus > kMinBetLimit ? _q.pointsPlus : kMinBetLimit),
            _Scoring.amount => l10n.scoringAmountText,
          }, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
        ],
        // Put in order: what a share of the points is for.
        if (_q.type == QuestionType.ordering) ...[
          Text(l10n.orderScoringTitle, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          SegmentedButton<OrderScoring>(
            showSelectedIcon: false,
            segments: [for (final by in OrderScoring.values) ButtonSegment(value: by, label: Text(l10n.orderScoring(by.name)))],
            selected: {_orderScoring},
            onSelectionChanged: (picked) {
              setState(() => _orderScoring = picked.single);
              _save({'orderScoring': picked.single.name});
            },
          ),
          const SizedBox(height: 6),
          Text(l10n.orderScoringText(_orderScoring.name), style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
        ],
        if (scoring == _Scoring.amount) ...[
          TextField(
            controller: _betPrompt,
            decoration: InputDecoration(
              labelText: l10n.betQuestion,
              hintText: l10n.betQuestionHint,
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
            _points(
              _plus,
              switch (scoring) {
                _Scoring.points => l10n.points,
                _Scoring.amount => l10n.eachPlus,
                _Scoring.ranked || _Scoring.closest => l10n.firstPlacePlus,
                _Scoring.fixed when _q.type == QuestionType.rapidFire => l10n.eachItemPlus,
                _Scoring.fixed when _q.type == QuestionType.lastStanding => l10n.winnerPlus,
                _Scoring.fixed when _q.type == QuestionType.topAnswers => l10n.eachAnswerPlus,
                _Scoring.fixed => l10n.ifRightPlus,
              },
              'pointsPlus',
              // Given per item: the boards show everything there is to win.
              helper: _q.boardPoints != _q.pointsPlus ? l10n.onTheBoard(_q.boardPoints) : null,
            ),
            if (_hasMinus) _points(_minus, scoring == _Scoring.amount ? l10n.eachMinus : l10n.ifWrongMinus, 'pointsMinus'),
            if (_byPlace)
              TextField(
                controller: _rankStep,
                decoration: InputDecoration(labelText: l10n.lessPerPlace, isDense: true),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (text) => _save({'rankStep': (int.tryParse(text) ?? 0).clamp(0, 100000)}),
              ),
            if (scoring == _Scoring.amount)
              TextField(
                controller: _betMax,
                decoration: InputDecoration(labelText: l10n.highestBet, isDense: true),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _save({'amountBet': _amountBet()}),
              ),
          ],
        ),
        if (_byPlace)
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
        row(MediaKind.image, _q.image, context.l10n.noPicture, 'image'),
        row(MediaKind.audio, _q.music, context.l10n.noMusic, 'music'),
        ListTile(
          contentPadding: const EdgeInsets.only(left: 8),
          leading: const Icon(Icons.queue_music),
          title: Text(context.l10n.musicAndEffects),
          subtitle: Text(soundsSummary(context.l10n, _q.sounds, inherited: context.l10n.theCategorys)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showSoundsDialog(context, gameId: widget.gameId, title: context.l10n.soundsForQuestion, data: _q.data, save: _save),
        ),
      ],
    );
  }

  /// The question itself and the type's content beside (wide) or above the
  /// sections with how it is played.
  Widget _arrange(bool wide, bool roomy, Widget? typeSettings, Widget typeContent) {
    final theme = Theme.of(context);
    // A Fragenhagel, matching, put in order and top answers bring their own settings.
    final answering =
        typeSettings ??
        (_q.type == QuestionType.rapidFire ||
                _q.type == QuestionType.matching ||
                _q.type == QuestionType.ordering ||
                _q.type == QuestionType.topAnswers
            ? null
            : CompanionEditor(key: ValueKey('companion-${_q.type}'), gameId: widget.gameId, question: _q, save: _save));
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FillDropdown<QuestionType>(
          label: context.l10n.type,
          value: _q.type,
          leadingIcon: Icon(questionTypeIcon(_q.type)),
          entries: [
            // In the order of [QuestionType]: one answer, lists, puzzles, rounds.
            for (final type in QuestionType.values)
              if (type != QuestionType.unsupported || _q.type == type)
                DropdownMenuEntry(value: type, label: context.l10n.questionType(type), leadingIcon: Icon(questionTypeIcon(type))),
          ],
          onSelected: (type) {
            if (type != null && type != QuestionType.unsupported) _save({'type': type.name});
          },
        ),
        const SizedBox(height: 4),
        Text(questionTypeExplanation(context.l10n, _q.type), style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          decoration: InputDecoration(labelText: context.l10n.question),
          minLines: 1,
          maxLines: 4,
          onChanged: (value) => _save({'question': value}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _hint,
          decoration: InputDecoration(labelText: context.l10n.answerHint, helperText: context.l10n.onlyGamemasterSees),
          minLines: 1,
          maxLines: 4,
          onChanged: (value) => _save({'answerHint': value}),
        ),
        const SizedBox(height: 8),
        if (_showLabel) ...[
          TextField(
            controller: _description,
            decoration: InputDecoration(labelText: context.l10n.label, helperText: context.l10n.labelHelper),
            onChanged: (value) => _save({'description': value}),
          ),
          const SizedBox(height: 8),
        ] else
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const Icon(Icons.add),
              label: Text(context.l10n.label),
              tooltip: context.l10n.labelTooltip,
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
            title: context.l10n.howTeamsAnswer,
            summary: answeringSummary(context.l10n, _q),
            open: _isOpen('answer', roomy),
            onToggle: () => _toggle('answer', roomy),
            child: answering,
          ),
        EditorSection(
          icon: Icons.scoreboard_outlined,
          title: context.l10n.scoring,
          summary: _scoringSummary,
          open: _isOpen('scoring', roomy),
          onToggle: () => _toggle('scoring', roomy),
          child: _scoringSection(theme),
        ),
        EditorSection(
          icon: Icons.perm_media_outlined,
          title: context.l10n.mediaAndSound,
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
                child: Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.drag_indicator, semanticLabel: context.l10n.moveQuestion),
                ),
              ),
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                _q.boardPoints.toString(),
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
        title: Text(_q.text.isEmpty ? context.l10n.newQuestion : _q.text, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(_subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_expanded) ...[
              IconButton(
                icon: const Icon(Icons.visibility_outlined),
                tooltip: context.l10n.preview,
                onPressed: () {
                  _flush();
                  showQuestionPreview(context, gameId: widget.gameId, categoryId: widget.categoryId, question: _q);
                },
              ),
              IconButton(icon: const Icon(Icons.delete_outline), tooltip: context.l10n.deleteQuestion, onPressed: _delete),
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
  ranked("By order: fastest first"),
  closest("By closeness: nearest first");

  const _Scoring(this.label);

  final String label;
}
