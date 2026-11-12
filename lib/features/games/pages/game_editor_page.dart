import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/pages/category_editor_page.dart';
import 'package:quiz_show/features/games/pages/game_access_page.dart';
import 'package:quiz_show/features/games/pages/map_editor_page.dart';
import 'package:quiz_show/features/games/widgets/cards_dialog.dart';
import 'package:quiz_show/features/games/widgets/group_colors_dialog.dart';
import 'package:quiz_show/features/games/widgets/settings_strip.dart';
import 'package:quiz_show/features/games/widgets/sounds_dialog.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/l10n.dart';

extension BoardTypeIcon on BoardType {
  IconData get icon => switch (this) {
    BoardType.display => Icons.art_track_rounded,
    BoardType.wheel => Icons.pie_chart_outline,
    BoardType.map => Icons.route,
  };
}

/// The structure of one game: its category groups and their categories.
/// Questions are edited one level down, in [CategoryEditorPage].
class GameEditorPage extends StatefulWidget {
  const GameEditorPage({super.key, required this.gameId});

  final String gameId;

  @override
  State<GameEditorPage> createState() => _GameEditorPageState();
}

class _GameEditorPageState extends State<GameEditorPage> {
  late final Stream<GameSnapshot> _game = GameRepository.instance.watchGame(widget.gameId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameSnapshot>(
      stream: _game,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.l10n.gameNotAvailable)),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CupertinoActivityIndicator()),
          );
        }
        return GameEditorView(snapshot: data);
      },
    );
  }
}

/// [GameEditorPage] once the game is loaded: the game's own settings as
/// labelled tiles, then its boards with their categories.
class GameEditorView extends StatefulWidget {
  const GameEditorView({super.key, required this.snapshot});

  final GameSnapshot snapshot;

  @override
  State<GameEditorView> createState() => _GameEditorViewState();
}

class _GameEditorViewState extends State<GameEditorView> {
  GameRepository get _repo => GameRepository.instance;

  /// Everything in the game, answers included, for pasting elsewhere.
  Future<void> _copyAsText(GameContent game) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: gameAsText(game)));
    messenger.showSnackBar(SnackBar(content: Text(l10n.copiedGame)));
  }

  Future<void> _rename(GameContent game) async {
    final name = await promptText(context, title: context.l10n.renameGame, initial: game.name, label: context.l10n.name);
    if (name == null || !mounted) return;
    await guarded(context, () => _repo.updateGame(game.id, {'name': name}));
  }

  Future<void> _delete(GameContent game) async {
    final sure = await confirm(
      context,
      title: context.l10n.deleteGame,
      message: context.l10n.deleteGameText(game.name),
      action: context.l10n.delete,
    );
    if (!sure || !mounted) return;
    Navigator.of(context).pop();
    await _repo.deleteGame(game);
  }

  Future<void> _leave(GameContent game) async {
    final sure = await confirm(
      context,
      title: context.l10n.leaveGame,
      message: context.l10n.leaveGameText(game.name),
      action: context.l10n.leave,
    );
    if (!sure || !mounted) return;
    Navigator.of(context).pop();
    await _repo.leaveGame(game.id);
  }

  void _reorderGroups(GameContent game, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final ids = [for (final group in game.groups) group.id];
    // The ungrouped categories always stay on top and have no document.
    final pinned = game.groups.isNotEmpty && game.groups.first.isUngrouped ? 1 : 0;
    if (oldIndex < pinned || newIndex < pinned) return;
    ids.insert(newIndex, ids.removeAt(oldIndex));
    guarded(context, () => _repo.reorderGroups(game.id, ids.sublist(pinned)));
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.snapshot;
    final game = data.content;
    final canEditStructure = data.role.seesEverything;
    final settings = [
      if (canEditStructure)
        SettingTile(
          icon: Icons.queue_music,
          title: context.l10n.musicAndSounds,
          summary: soundsSummary(context.l10n, game.sounds, inherited: context.l10n.noneYet),
          isSet: game.sounds.slots.isNotEmpty || game.sounds.effects.isNotEmpty,
          onTap: () => showSoundsDialog(
            context,
            gameId: game.id,
            title: context.l10n.soundsForGame,
            isGame: true,
            data: data.data,
            save: (update) => guarded(context, () => _repo.updateGame(game.id, update)),
          ),
        ),
      if (canEditStructure)
        SettingTile(
          icon: Icons.style_outlined,
          title: context.l10n.cards,
          summary: cardsSummary(context.l10n, game.cards),
          isSet: CueCard.listFrom(data.data['cards']).isNotEmpty,
          onTap: () => showCardsDialog(
            context,
            gameId: game.id,
            title: context.l10n.cardsForGame,
            cards: game.cards,
            save: (cards) => guarded(context, () => _repo.updateGame(game.id, {'cards': cards})),
          ),
        ),
      if (data.role == GameRole.admin)
        SettingTile(
          icon: Icons.group_outlined,
          title: context.l10n.people,
          summary: _peopleSummary(context.l10n, data.data),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameAccessPage(gameId: game.id))),
        ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(game.name.isEmpty ? context.l10n.unnamed : game.name),
        actions: [
          // The rarely needed ones, so the title keeps its room on a phone.
          PopupMenuButton<VoidCallback>(
            tooltip: context.l10n.more,
            onSelected: (action) => action(),
            itemBuilder: (context) => [
              if (canEditStructure)
                PopupMenuItem(
                  value: () => _rename(game),
                  child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(context.l10n.rename)),
                ),
              PopupMenuItem(
                value: () => _copyAsText(game),
                child: ListTile(leading: const Icon(Icons.copy_all_outlined), title: Text(context.l10n.copyAsText)),
              ),
              if (data.role == GameRole.admin)
                PopupMenuItem(
                  value: () => _delete(game),
                  child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(context.l10n.deleteGame)),
                )
              else
                PopupMenuItem(
                  value: () => _leave(game),
                  child: ListTile(leading: const Icon(Icons.logout), title: Text(context.l10n.leaveGame)),
                ),
            ],
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        buildDefaultDragHandles: false,
        header: settings.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: SettingsStrip(tiles: settings),
              ),
        itemCount: game.groups.length,
        // onReorderItem replaces this from Flutter 3.41 on; kept for older SDKs in CI.
        // ignore: deprecated_member_use
        onReorder: (oldIndex, newIndex) => _reorderGroups(game, oldIndex, newIndex),
        itemBuilder: (context, index) => _GroupCard(
          key: ValueKey(game.groups[index].id),
          game: game,
          group: game.groups[index],
          listIndex: index,
          canEditStructure: canEditStructure,
        ),
        footer: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canEditStructure)
                for (final type in BoardType.values)
                  OutlinedButton.icon(
                    onPressed: () => guarded(context, () => _repo.addGroup(game.id, type, game.groups.where((g) => !g.isUngrouped).length, name: context.l10n.newBoard(type.name))),
                    icon: Icon(type.icon),
                    label: Text(context.l10n.addBoard(type.name)),
                  )
              else if (game.groups.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(context.l10n.nothingSharedYet, textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _peopleSummary(AppLocalizations l10n, Map<String, dynamic> game) {
    int count(String key) => game[key] is List ? (game[key] as List).length : 0;
    final total = count('admin') + count('full') + count('limited');
    return total == 1 ? l10n.onlyYou : l10n.memberCount(total);
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({super.key, required this.game, required this.group, required this.listIndex, required this.canEditStructure});

  final GameContent game;
  final CategoryGroup group;
  final int listIndex;
  final bool canEditStructure;

  GameRepository get _repo => GameRepository.instance;

  Future<void> _rename(BuildContext context) async {
    final name = await promptText(context, title: context.l10n.renameGroup, initial: group.name, label: context.l10n.name);
    if (name == null || !context.mounted) return;
    await guarded(context, () => _repo.updateGroup(game.id, group.id, {'name': name}));
  }

  Future<void> _editDisplayText(BuildContext context) async {
    final text = await promptText(context, title: context.l10n.displayText, initial: group.text ?? '', label: context.l10n.shownOnBoard);
    if (text == null || !context.mounted) return;
    await guarded(context, () => _repo.updateGroup(game.id, group.id, {'text': text}));
  }

  /// "Wheel · 3 categories · own music · 2 cards"
  String _summary(AppLocalizations l10n) {
    final count = group.categories.length;
    return [
      l10n.boardType(group.type),
      l10n.categoryCount(count),
      if (group.sounds.slots.isNotEmpty || group.sounds.effects.isNotEmpty) l10n.ownSounds,
      if (group.cards.isNotEmpty) l10n.cardCount(group.cards.length),
    ].join(" · ");
  }

  void _arrangeMap(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MapEditorPage(gameId: game.id, groupId: group.id),
    ),
  );

  void _update(BuildContext context, Map<String, dynamic> data) => guarded(context, () => _repo.updateGroup(game.id, group.id, data));

  /// Everything about this board in one list, each with what is set now.
  Future<void> _openSettings(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      // The sheet keeps the board as it was opened; switches remember
      // their own state until the list below catches up.
      var splitFields = group.splitPointFields;
      var mapLabels = mapShowsLabels(group);
      void close() => Navigator.of(sheet).pop();
      return StatefulBuilder(
        builder: (sheet, setSheet) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text("${group.name.isEmpty ? context.l10n.unnamed : group.name} · ${context.l10n.boardType(group.type)}", style: theme.textTheme.titleLarge),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.l10n.name),
              subtitle: Text(group.name.isEmpty ? context.l10n.unnamed : group.name),
              onTap: () {
                close();
                _rename(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text(context.l10n.musicAndSounds),
              subtitle: Text(soundsSummary(context.l10n, group.sounds, inherited: context.l10n.usesGames)),
              onTap: () {
                close();
                showSoundsDialog(
                  context,
                  gameId: game.id,
                  title: context.l10n.soundsForBoard,
                  data: group.data,
                  save: (update) => _update(context, update),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: Text(context.l10n.cards),
              subtitle: Text(cardsSummary(context.l10n, group.cards, none: context.l10n.onlyGames)),
              onTap: () {
                close();
                showCardsDialog(
                  context,
                  gameId: game.id,
                  title: context.l10n.cardsForBoard,
                  cards: group.cards,
                  save: (cards) => _update(context, {'cards': cards}),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.palette_outlined, color: group.color == null ? null : Color(group.color!)),
              title: Text(context.l10n.colours),
              subtitle: Text(group.color == null ? context.l10n.appsColours : context.l10n.ownColours),
              onTap: () {
                close();
                showGroupColorsDialog(
                  context,
                  group: group,
                  save: (color, accent) => _update(context, {'color': color, 'accentColor': accent}),
                );
              },
            ),
            if (group.type == BoardType.display)
              ListTile(
                leading: const Icon(Icons.short_text),
                title: Text(context.l10n.textOnBoard),
                subtitle: Text((group.text ?? '').isEmpty ? context.l10n.none : group.text!, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () {
                  close();
                  _editDisplayText(context);
                },
              ),
            if (group.type == BoardType.wheel)
              SwitchListTile(
                secondary: const Icon(Icons.call_split),
                title: Text(context.l10n.splitPointFields),
                subtitle: Text(context.l10n.splitPointFieldsText),
                value: splitFields,
                onChanged: (value) {
                  setSheet(() => splitFields = value);
                  _update(context, {'splitPointFields': value});
                },
              ),
            if (group.type == BoardType.map) ...[
              ListTile(
                leading: const Icon(Icons.open_with),
                title: Text(context.l10n.arrangeMap),
                subtitle: Text(context.l10n.arrangeMapShort),
                onTap: () {
                  close();
                  _arrangeMap(context);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.label_outline),
                title: Text(context.l10n.labelsInsteadOfPoints),
                subtitle: Text(context.l10n.labelsInsteadOfPointsText),
                value: mapLabels,
                onChanged: (value) {
                  setSheet(() => mapLabels = value);
                  _update(context, {'mapLabels': value ? 'label' : 'points'});
                },
              ),
            ],
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete_outline, color: group.categories.isEmpty ? theme.colorScheme.error : null),
              title: Text(context.l10n.deleteBoard),
              subtitle: group.categories.isEmpty ? null : Text(context.l10n.deleteBoardFirst),
              enabled: group.categories.isEmpty,
              onTap: () {
                close();
                guarded(context, () => _repo.deleteGroup(game.id, group.id));
              },
            ),
          ],
        ),
      );
    },
  );

  Future<void> _addCategory(BuildContext context) async {
    await guarded(context, () async {
      final id = await _repo.addCategory(game.id, groupId: group.id, index: group.categories.length, name: context.l10n.newCategory);
      if (context.mounted) _openCategory(context, id);
    });
  }

  void _openCategory(BuildContext context, String categoryId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryEditorPage(gameId: game.id, categoryId: categoryId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editable = canEditStructure && !group.isUngrouped;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(group.type.icon, color: group.color == null ? theme.colorScheme.onSurfaceVariant : Color(group.color!)),
            title: Text(
              group.isUngrouped ? context.l10n.ungroupedCategories : (group.name.isEmpty ? context.l10n.unnamed : group.name),
              style: theme.textTheme.titleMedium,
            ),
            subtitle: group.isUngrouped ? null : Text(_summary(context.l10n)),
            onTap: editable ? () => _openSettings(context) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Labelled where there is room; a phone gets the icon alone.
                if (editable && MediaQuery.sizeOf(context).width >= 600)
                  TextButton.icon(
                    onPressed: () => _openSettings(context),
                    icon: const Icon(Icons.tune),
                    label: Text(context.l10n.boardSettings),
                  )
                else if (editable)
                  IconButton.filledTonal(
                    onPressed: () => _openSettings(context),
                    icon: const Icon(Icons.tune),
                    tooltip: context.l10n.boardSettings,
                  ),
                if (editable)
                  ReorderableDragStartListener(
                    index: listIndex,
                    child: Tooltip(
                      message: context.l10n.moveBoard,
                      child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle)),
                    ),
                  ),
              ],
            ),
          ),
          // Laid out by hand, so it stays one tap away.
          if (editable && group.type == BoardType.map)
            ListTile(
              dense: true,
              leading: const Icon(Icons.open_with),
              title: Text(context.l10n.arrangeMap),
              subtitle: Text(context.l10n.arrangeMapLong),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _arrangeMap(context),
            ),
          for (final (index, category) in group.categories.indexed)
            _CategoryTile(
              game: game,
              group: group,
              category: category,
              index: index,
              canEditStructure: canEditStructure,
              onOpen: () => _openCategory(context, category.id),
            ),
          _CategoryDropZone(
            enabled: canEditStructure,
            onDrop: (dragged) =>
                guarded(context, () => _repo.moveCategory(game, dragged.id, group.id, _dropIndex(dragged, group, group.categories.length))),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => _addCategory(context),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.addCategory),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A category on its way to another place, on its board or another one.
class _DraggedCategory {
  const _DraggedCategory(this.id, this.groupId, this.index, this.name);

  final String id;
  final String groupId;
  final int index;
  final String name;
}

/// Where [dragged] ends up when dropped in front of place [before] of
/// [group]: on its own board it first leaves its old place.
int _dropIndex(_DraggedCategory dragged, CategoryGroup group, int before) =>
    dragged.groupId == group.id && dragged.index < before ? before - 1 : before;

/// Takes a dragged category; shows a line where it will land.
class _CategoryDropZone extends StatelessWidget {
  const _CategoryDropZone({required this.enabled, required this.onDrop, required this.child});

  final bool enabled;
  final void Function(_DraggedCategory dragged) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return DragTarget<_DraggedCategory>(
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(width: 3, color: candidates.isEmpty ? Colors.transparent : Theme.of(context).colorScheme.primary)),
        ),
        child: child,
      ),
    );
  }
}

enum _CategoryAction { up, down, move, follows, delete }

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.game,
    required this.group,
    required this.category,
    required this.index,
    required this.canEditStructure,
    required this.onOpen,
  });

  final GameContent game;
  final CategoryGroup group;
  final Category category;
  final int index;
  final bool canEditStructure;
  final VoidCallback onOpen;

  GameRepository get _repo => GameRepository.instance;

  Future<void> _moveToGroup(BuildContext context) async {
    final target = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.moveToAnotherBoard),
        children: [
          for (final other in game.groups.where((g) => g.id != group.id && !g.isUngrouped))
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(other.id),
              child: Row(
                children: [
                  Icon(other.type.icon),
                  const SizedBox(width: 12),
                  Expanded(child: Text(other.name)),
                ],
              ),
            ),
        ],
      ),
    );
    if (target == null || !context.mounted) return;
    final end = game.group(target)?.categories.length ?? 0;
    await guarded(context, () => _repo.moveCategory(game, category.id, target, end));
  }

  /// Map boards: which bubble this category is drawn after. Several
  /// categories after the same one make a branch; the map editor can also
  /// give a bubble several arrows in, to join branches again.
  Future<void> _chooseFollows(BuildContext context) async {
    const previous = '\u0000previous';
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.comesAfterTitle(category.name)),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.of(context).pop(previous), child: Text(context.l10n.categoryBeforeIt)),
          SimpleDialogOption(onPressed: () => Navigator.of(context).pop(''), child: Text(context.l10n.startsNewChain)),
          for (final other in group.categories.where((c) => c.id != category.id))
            SimpleDialogOption(onPressed: () => Navigator.of(context).pop(other.id), child: Text(other.name)),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    // One arrow in, in place of whatever arrows it had; the map editor can
    // add more.
    final layout = mapLayoutWithAfter(group.data['mapLayout'], category.id, choice == previous ? null : [if (choice.isNotEmpty) choice]);
    await guarded(context, () => _repo.updateGroup(game.id, group.id, {'mapLayout': layout}));
  }

  Future<void> _delete(BuildContext context) async {
    final sure = await confirm(
      context,
      title: context.l10n.deleteCategory,
      message: context.l10n.deleteCategoryText(category.name, category.questions.length),
      action: context.l10n.delete,
    );
    if (!sure || !context.mounted) return;
    await guarded(context, () => _repo.deleteCategory(game.id, category));
  }

  @override
  Widget build(BuildContext context) {
    final questions = category.questions.length;
    final hasOtherGroups = game.groups.any((g) => g.id != group.id && !g.isUngrouped);
    final checkbox = Tooltip(
      message: category.active ? context.l10n.inPlayTip : context.l10n.notInPlayTip,
      child: Checkbox(
        value: category.active,
        onChanged: (value) => guarded(context, () => _repo.updateCategory(game.id, category.id, {'active': value ?? true})),
      ),
    );
    final dragged = _DraggedCategory(category.id, group.id, index, category.name.isEmpty ? context.l10n.unnamed : category.name);
    final tile = ListTile(
      // Grabbed by the handle and dropped on another place, on this board or
      // on another one.
      leading: !canEditStructure
          ? checkbox
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Draggable<_DraggedCategory>(
                  data: dragged,
                  feedback: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(dragged.name, style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Icon(Icons.drag_indicator, semanticLabel: context.l10n.moveCategory, color: Theme.of(context).colorScheme.outline),
                  ),
                ),
                checkbox,
              ],
            ),
      title: Text(category.name.isEmpty ? context.l10n.unnamed : category.name),
      subtitle: Text("${context.l10n.questionCount(questions)}${category.active ? "" : " · ${context.l10n.notInPlay}"}"),
      onTap: onOpen,
      trailing: PopupMenuButton<_CategoryAction>(
        onSelected: (action) {
          switch (action) {
            case _CategoryAction.up:
              guarded(context, () => _repo.moveCategory(game, category.id, group.id, index - 1));
            case _CategoryAction.down:
              guarded(context, () => _repo.moveCategory(game, category.id, group.id, index + 1));
            case _CategoryAction.move:
              _moveToGroup(context);
            case _CategoryAction.follows:
              _chooseFollows(context);
            case _CategoryAction.delete:
              _delete(context);
          }
        },
        itemBuilder: (context) => [
          if (canEditStructure && index > 0) PopupMenuItem(value: _CategoryAction.up, child: ListTile(leading: const Icon(Icons.arrow_upward), title: Text(context.l10n.moveUp))),
          if (canEditStructure && index < group.categories.length - 1)
            PopupMenuItem(value: _CategoryAction.down, child: ListTile(leading: const Icon(Icons.arrow_downward), title: Text(context.l10n.moveDown))),
          if (canEditStructure && hasOtherGroups) PopupMenuItem(value: _CategoryAction.move, child: ListTile(leading: const Icon(Icons.drive_file_move_outlined), title: Text(context.l10n.moveToAnotherBoardMenu))),
          if (canEditStructure && group.type == BoardType.map && group.categories.length > 1)
            PopupMenuItem(value: _CategoryAction.follows, child: ListTile(leading: const Icon(Icons.account_tree_outlined), title: Text(context.l10n.comesAfterMenu))),
          PopupMenuItem(value: _CategoryAction.delete, child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(context.l10n.delete))),
        ],
      ),
    );
    return _CategoryDropZone(
      enabled: canEditStructure,
      onDrop: (dropped) {
        if (dropped.id == category.id) return;
        guarded(context, () => _repo.moveCategory(game, dropped.id, group.id, _dropIndex(dropped, group, index)));
      },
      child: tile,
    );
  }
}
