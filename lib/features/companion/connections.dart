import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quiz_show/game/game.dart';

/// The four group colours, easiest first, as people know them from the
/// newspaper puzzle. Dark ink reads on all four in light and dark mode.
const List<Color> connectionColors = [Color(0xFFF9DF6D), Color(0xFFA0C35A), Color(0xFFB0C4EF), Color(0xFFBA81C5)];
const Color connectionInk = Color(0xFF1C1B1A);
const List<String> connectionColorNames = ['Yellow', 'Green', 'Blue', 'Purple'];

Color connectionColor(int level) => connectionColors[level.clamp(0, connectionColors.length - 1)];

/// A group as the grid shows it: found by the team, or put on the big screen.
class GridGroup {
  const GridGroup({required this.level, required this.name, required this.words, required this.positions, this.found = true});

  factory GridGroup.of(GroupView view, {bool found = true}) =>
      GridGroup(level: view.level, name: view.name, words: view.words, positions: view.positions, found: found);

  /// From the full content, for the presenter and the gamemaster.
  factory GridGroup.fromSpec(CompanionSpec spec, int level, List<int> order) {
    final group = level < spec.groups.length ? spec.groups[level] : const ConnectionGroup();
    return GridGroup(
      level: level,
      name: group.name,
      words: group.words,
      positions: [for (var i = 0; i < kConnectionsGroupSize; i++) order.indexOf(level * kConnectionsGroupSize + i)],
    );
  }

  final int level;
  final String name;
  final List<String> words;

  /// Where its words are in the shown order.
  final List<int> positions;

  /// False for a group the team did not find and only saw revealed.
  final bool found;
}

/// The 4 × 4 board. Groups that are found sit as coloured bars at the top,
/// in the order they were found; the other words fill the rows below. When
/// a group is found its four tiles glide into their row and turn into the
/// bar; when the order of the rest changes, the tiles glide to their new
/// places.
class ConnectionsGrid extends StatelessWidget {
  const ConnectionsGrid({
    super.key,
    required this.words,
    this.groups = const [],
    this.layout,
    this.selected = const {},
    this.onTap,
    this.shake = 0,
    this.gap = 8,
    this.fontSize = 16,
  });

  /// The sixteen words, in the shown order; the index is a word's position.
  final List<String> words;
  final List<GridGroup> groups;

  /// The order the remaining words are laid out in, as positions; the shown
  /// order when null. Lets a team shuffle its board.
  final List<int>? layout;
  final Set<int> selected;
  final ValueChanged<int>? onTap;

  /// Counts up on every wrong guess; the selected tiles shake each time.
  final int shake;
  final double gap;
  final double fontSize;

  static const Duration slide = Duration(milliseconds: 520);

  @override
  Widget build(BuildContext context) {
    final count = words.length;
    if (count == 0) return const SizedBox();
    final grouped = <int, (int row, int column, GridGroup group)>{};
    for (final (row, group) in groups.take(kConnectionsGroups).indexed) {
      for (final (column, position) in group.positions.indexed) {
        grouped[position] = (row, column, group);
      }
    }
    final rest = [for (final p in layout ?? List<int>.generate(count, (i) => i)) if (!grouped.containsKey(p) && p < count) p];
    final place = <int, (int, int)>{
      for (final entry in grouped.entries) entry.key: (entry.value.$1, entry.value.$2),
      for (final (i, p) in rest.indexed) p: (groups.length + i ~/ kConnectionsGroupSize, i % kConnectionsGroupSize),
    };
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - gap * 3) / 4;
        final height = box.maxHeight.isFinite ? (box.maxHeight - gap * 3) / 4 : width * 0.62;
        Rect cell(int row, int column) => Rect.fromLTWH(column * (width + gap), row * (height + gap), width, height);
        return SizedBox(
          width: box.maxWidth,
          height: height * 4 + gap * 3,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var p = 0; p < count; p++)
                if (place[p] != null)
                  AnimatedPositioned.fromRect(
                    key: ValueKey('word-$p'),
                    duration: slide,
                    curve: Curves.easeInOutCubic,
                    rect: cell(place[p]!.$1, place[p]!.$2),
                    child: _WordTile(
                      text: words[p],
                      fontSize: fontSize,
                      selected: selected.contains(p),
                      group: grouped[p]?.$3,
                      shake: selected.contains(p) ? shake : 0,
                      onTap: onTap == null || grouped.containsKey(p) ? null : () => onTap!(p),
                    ),
                  ),
              for (final (row, group) in groups.take(kConnectionsGroups).indexed)
                Positioned.fromRect(
                  key: ValueKey('bar-${group.level}'),
                  rect: Rect.fromLTWH(0, row * (height + gap), box.maxWidth, height),
                  child: _GroupBar(group: group, fontSize: fontSize),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({required this.text, required this.fontSize, required this.selected, required this.shake, this.group, this.onTap});

  final String text;
  final double fontSize;
  final bool selected;
  final GridGroup? group;
  final int shake;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final idle = dark ? const Color(0xFF3B3A36) : const Color(0xFFEFEFE6);
    final background = group != null
        ? connectionColor(group!.level)
        : selected
            ? (dark ? const Color(0xFFE8E6DC) : const Color(0xFF5A594E))
            : idle;
    final ink = group != null
        ? connectionInk
        : selected
            ? (dark ? connectionInk : Colors.white)
            : scheme.onSurface;
    final tile = AnimatedScale(
      // Pressed in a little while chosen, like a key that is held down.
      scale: selected ? 0.94 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(fontSize * 0.5)),
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.3),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: ink, letterSpacing: 0.3),
          ),
        ),
      ),
    );
    final shown = group == null
        ? tile
        // Under its bar once it has arrived; gone, so no edge peeks out.
        : TweenAnimationBuilder<double>(
            key: const ValueKey('grouped'),
            tween: Tween(begin: 1, end: 0),
            duration: ConnectionsGrid.slide + const Duration(milliseconds: 380),
            curve: const Interval(0.8, 1),
            builder: (context, t, child) => Opacity(opacity: t, child: child),
            child: tile,
          );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: shake == 0
          ? shown
          : TweenAnimationBuilder<double>(
              // A new key restarts the shake for every wrong guess.
              key: ValueKey('shake-$shake'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              builder: (context, t, child) =>
                  Transform.translate(offset: Offset(sin(t * pi * 6) * (1 - t) * fontSize * 0.6, 0), child: child),
              child: shown,
            ),
    );
  }
}

/// A found group: its colour, its name and its four words. It grows out of
/// the tiles once they have arrived in its row.
class _GroupBar extends StatelessWidget {
  const _GroupBar({required this.group, required this.fontSize});

  final GridGroup group;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final color = connectionColor(group.level);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: ConnectionsGrid.slide + const Duration(milliseconds: 380),
      curve: const Interval(0.55, 1, curve: Curves.easeOutBack),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          // A group the team did not find is shown, but paler.
          color: group.found ? color : Color.lerp(color, Theme.of(context).colorScheme.surface, 0.45),
          borderRadius: BorderRadius.circular(fontSize * 0.5),
        ),
        padding: EdgeInsets.symmetric(horizontal: fontSize, vertical: fontSize * 0.2),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                group.name.toUpperCase(),
                style: TextStyle(fontSize: fontSize * 1.05, fontWeight: FontWeight.w900, color: connectionInk),
              ),
              Text(
                group.words.map((w) => w.toUpperCase()).join(", "),
                style: TextStyle(fontSize: fontSize * 0.95, color: connectionInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How far a team got: a square per group in the colour it found, in the
/// order found, and its mistakes.
class ConnectionsProgressRow extends StatelessWidget {
  const ConnectionsProgressRow({
    super.key,
    required this.solved,
    required this.mistakes,
    required this.allowed,
    this.size = 18,
  });

  final List<int> solved;
  final int mistakes;
  final int allowed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < kConnectionsGroups; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            width: size,
            height: size,
            margin: EdgeInsets.only(right: size * 0.2),
            decoration: BoxDecoration(
              color: i < solved.length ? connectionColor(solved[i]) : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(size * 0.25),
              border: i < solved.length ? null : Border.all(color: scheme.outlineVariant),
            ),
          ),
        SizedBox(width: size * 0.4),
        for (var i = 0; i < allowed; i++)
          Padding(
            padding: EdgeInsets.only(right: size * 0.05),
            child: Icon(
              i < mistakes ? Icons.close : Icons.circle,
              size: i < mistakes ? size : size * 0.45,
              color: i < mistakes ? scheme.error : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}

/// The puzzle on a team's own device: pick four words, send them, and see
/// at once whether they belong together. The host decides; this screen
/// never knows the groups before they are found or revealed.
class ConnectionsPlay extends StatefulWidget {
  const ConnectionsPlay({super.key, required this.view, required this.teamId, required this.send});

  final PublicView view;
  final String teamId;
  final void Function(Command) send;

  @override
  State<ConnectionsPlay> createState() => _ConnectionsPlayState();
}

class _ConnectionsPlayState extends State<ConnectionsPlay> {
  final Set<int> _selected = {};
  List<int>? _layout;
  int _shake = 0;
  String? _message;
  Timer? _messageTimer;

  // This device's own reckoning, updated the moment a guess is made: group
  // levels found in order, wrong guesses (sorted places) and which of them
  // were one away. The host counts the same guesses for the points.
  List<int> _found = [];
  List<List<int>> _wrong = [];
  List<bool> _oneAway = [];

  PublicView get _view => widget.view;

  ConnectionsView? get _host => _view.ownConnections;

  List<GroupView> get _groups => _view.connectionGroups;

  int get _steps => _found.length + _wrong.length;

  bool get _finished => _found.length == kConnectionsGroups || _wrong.length >= _view.connectionMistakesAllowed;

  bool get _locked => _view.hasLocked(widget.teamId);

  bool get _playable => _view.answersOpen && !_finished && !_locked;

  @override
  void initState() {
    super.initState();
    // Back after a restart or a lost connection: carry on where the host is.
    _adopt(_host);
  }

  void _adopt(ConnectionsView? host) {
    if (host == null) return;
    _found = [for (final group in host.solved) group.level];
    _wrong = [for (final guess in host.wrong) [...guess]..sort()];
    _oneAway = [...host.oneAway];
  }

  @override
  void didUpdateWidget(ConnectionsPlay old) {
    super.didUpdateWidget(old);
    final host = _host;
    if (host == null) return;
    final hostSteps = host.solved.length + host.mistakes;
    // The host knows more when another device of the team guessed too, and
    // has the last word once the round is over.
    if (hostSteps > _steps || (!_view.answersOpen && hostSteps != _steps)) {
      final found = _found.length;
      final wrong = _wrong.length;
      _adopt(host);
      _react(found, wrong);
    }
  }

  static const _praise = ["Perfect!", "Great!", "Nice!", "Solid!"];

  /// Feedback for what changed since [found] groups and [wrong] mistakes.
  void _react(int found, int wrong) {
    if (_found.length > found) {
      final level = _found.last;
      _selected.removeAll(_groups.where((g) => g.level == level).expand((g) => g.positions));
      HapticFeedback.mediumImpact();
      _say(_found.length == kConnectionsGroups ? "All four found!" : _praise[_found.length % _praise.length]);
    } else if (_wrong.length > wrong) {
      _shake++;
      HapticFeedback.heavyImpact();
      final left = _view.connectionMistakesAllowed - _wrong.length;
      _say(left <= 0 ? "No tries left" : (_oneAway.isNotEmpty && _oneAway.last ? "One away…" : "Not a group"));
    }
  }

  void _say(String message) {
    _messageTimer?.cancel();
    setState(() => _message = message);
    _messageTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _message = null);
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  void _toggle(int position) {
    if (!_playable) return;
    setState(() {
      if (!_selected.remove(position) && _selected.length < kConnectionsGroupSize) _selected.add(position);
    });
  }

  void _shuffle() {
    final remaining = List<int>.generate(_view.connectionWords.length, (i) => i)..shuffle();
    setState(() => _layout = remaining);
  }

  bool _same(List<int> a, List<int> b) => a.length == b.length && Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

  void _submit() {
    if (_selected.length != kConnectionsGroupSize) return;
    final guess = _selected.toList()..sort();
    if (_wrong.any((wrong) => _same(wrong, guess))) {
      _say("Already guessed");
      return;
    }
    widget.send(GuessConnection(widget.teamId, guess));
    // Judged right here, so the board answers at once; the host does the
    // same with the guess for the points.
    final match = _groups.where((g) => _same([...g.positions]..sort(), guess)).firstOrNull;
    if (_groups.length != kConnectionsGroups) return; // The host's answer will tell.
    final found = _found.length;
    final wrong = _wrong.length;
    setState(() {
      if (match != null) {
        _found = [..._found, match.level];
      } else {
        _wrong = [..._wrong, guess];
        _oneAway = [..._oneAway, _groups.any((g) => g.positions.where(guess.contains).length == kConnectionsGroupSize - 1)];
      }
    });
    _react(found, wrong);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final found = [
      for (final level in _found)
        for (final group in _groups.where((g) => g.level == level)) GridGroup.of(group),
    ];
    final foundLevels = {for (final g in found) g.level};
    final groups = [
      ...found,
      // Once the gamemaster reveals the rest, the team sees it too.
      for (final group in _view.revealedGroups)
        if (!foundLevels.contains(group.level)) GridGroup.of(group, found: false),
    ];
    final allowed = _view.connectionMistakesAllowed;
    final mistakes = _wrong.length;
    final status = _found.length == kConnectionsGroups
        ? "All four groups found"
        : _finished
            ? "No tries left. Wait for the solution"
            : _locked
                ? "Locked in with ${_found.length} of 4"
                : !_view.answersOpen
                    ? "Time is up"
                    : null;
    return Column(
      children: [
        SizedBox(
          height: 36,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(animation), child: child),
            ),
            child: _message == null && status == null
                ? const SizedBox(key: ValueKey('none'))
                : Container(
                    key: ValueKey(_message ?? status),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(18)),
                    child: Text(_message ?? status!, style: TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w600)),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        // The controls stay right under the board, wherever it ends.
        Flexible(
          child: AspectRatio(
            aspectRatio: 1.45,
            child: ConnectionsGrid(
              words: _view.connectionWords,
              groups: groups,
              layout: _layout,
              selected: _playable ? _selected : const {},
              onTap: _playable ? _toggle : null,
              shake: _shake,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Mistakes remaining:", style: theme.textTheme.bodyMedium),
            const SizedBox(width: 8),
            for (var i = 0; i < allowed; i++)
              AnimatedScale(
                scale: i < allowed - mistakes ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInBack,
                child: Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(color: scheme.onSurfaceVariant, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _playable ? _shuffle : null, child: const _OneLine("Shuffle")),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _playable && _selected.isNotEmpty ? () => setState(_selected.clear) : null,
                child: const _OneLine("Deselect all"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _playable && _selected.length == kConnectionsGroupSize ? _submit : null,
                child: const _OneLine("Submit"),
              ),
            ),
          ],
        ),
        if (_view.lockable && _playable)
          TextButton.icon(
            onPressed: () => widget.send(LockAnswer(widget.teamId)),
            icon: const Icon(Icons.flag_outlined),
            label: const Text("We're done"),
          ),
      ],
    );
  }
}

/// A button label that shrinks rather than wraps on a narrow phone.
class _OneLine extends StatelessWidget {
  const _OneLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));
}
