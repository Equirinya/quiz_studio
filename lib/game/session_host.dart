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
  SessionHost({SessionState initial = const SessionState(), GameContent? game, int Function()? clock})
      : _state = initial,
        _game = game,
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch) {
    _armTimer();
  }

  /// The host's time in milliseconds; replaceable in tests.
  final int Function() _clock;

  /// Locks the running answer round when its time is up.
  Timer? _roundTimer;
  int? _armedFor;

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

  /// The view for one team's devices, with what only that team may see.
  Map<String, dynamic> publicStateFor(String? teamId) => publicView(_state, _game, teamId: teamId);

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
    final result = reduce(_state, command, _game, now: _clock());
    if (!result.accepted) return false;
    final changed = !identical(result.state, _state);
    _state = result.state;
    if (changed) {
      _armTimer();
      _states.add(_state);
    }
    for (final effect in result.effects) {
      _effects.add(effect);
    }
    return true;
  }

  /// Keeps one timer running for the answer round that has a deadline. Also
  /// covers a show resumed after a restart: a deadline already passed locks
  /// the round at once.
  void _armTimer() {
    final round = _state.answerRound;
    final endsAt = round != null && round.open ? round.endsAtMillis : null;
    if (endsAt == _armedFor) return;
    _roundTimer?.cancel();
    _armedFor = endsAt;
    if (endsAt == null) return;
    final remaining = endsAt - _clock();
    _roundTimer = Timer(Duration(milliseconds: remaining < 0 ? 0 : remaining), () {
      _armedFor = null;
      dispatch(const LockAnswers());
    });
  }

  Future<void> dispose() async {
    _roundTimer?.cancel();
    await _states.close();
    await _effects.close();
  }
}
