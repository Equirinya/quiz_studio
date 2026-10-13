/// The one place a session's state lives while a show runs. Whatever the
/// transport, commands end up here and states go out from here.
library;

import 'dart:async';

import 'commands.dart';
import 'content.dart';
import 'public_view.dart';
import 'reducer.dart';
import 'session_state.dart';

class SessionHost {
  SessionHost({SessionState initial = const SessionState(), GameContent? game})
      : _state = initial,
        _game = game;

  SessionState _state;
  GameContent? _game;

  final StreamController<SessionState> _states = StreamController<SessionState>.broadcast(sync: true);
  final StreamController<Effect> _effects = StreamController<Effect>.broadcast(sync: true);

  SessionState get state => _state;

  GameContent? get game => _game;

  /// Every state after the current one. Listeners are called synchronously,
  /// in the order commands were dispatched.
  Stream<SessionState> get states => _states.stream;

  /// One-shot events for the presenter, e.g. sounds to play.
  Stream<Effect> get effects => _effects.stream;

  /// What player devices may see of the current state.
  Map<String, dynamic> get publicState => publicView(_state, _game);

  /// Swaps in new content, e.g. after the game was edited or another game
  /// was loaded. A question that no longer exists is closed without marking
  /// it played.
  void setGame(GameContent? game) {
    _game = game;
    final current = _state.current;
    if (current != null && game?.question(current) == null) {
      dispatch(const CloseQuestion(markPlayed: false));
    } else {
      // The public view depends on the content, so everyone gets a fresh one.
      _states.add(_state);
    }
  }

  /// Applies [command] on behalf of [sender]. Returns false when the sender
  /// may not issue it or it makes no sense right now; nothing changes then.
  bool dispatch(Command command, {Sender sender = const Sender.host()}) {
    if (_states.isClosed || !mayIssue(sender, command)) return false;
    final result = reduce(_state, command, _game);
    if (!result.accepted) return false;
    final changed = !identical(result.state, _state);
    _state = result.state;
    if (changed) _states.add(_state);
    for (final effect in result.effects) {
      _effects.add(effect);
    }
    return true;
  }

  Future<void> dispose() async {
    await _states.close();
    await _effects.close();
  }
}
