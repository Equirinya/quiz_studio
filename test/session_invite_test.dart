import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/session/pages/sessions_page.dart';
import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/features/session/session_repository.dart';
import 'package:quiz_show/game/game.dart';
import 'package:quiz_show/l10n/app_localizations.dart';

void main() {
  group('invite link', () {
    const invite = SessionInviteLink(sessionId: 'S1', token: 'tok_9');

    test('reads back from the app link and the web link', () {
      for (final text in [invite.link, invite.webLink, '  ${invite.webLink}  ']) {
        final parsed = SessionInviteLink.tryParse(text)!;
        expect(parsed.sessionId, 'S1');
        expect(parsed.token, 'tok_9');
      }
      expect(invite.webLink, startsWith('https://'));
    });

    test('is not mistaken for a join code, nor the other way round', () {
      const controller = SessionJoinLink(sessionId: 'S1', token: 'tok', role: Role.controller);
      const player = SessionJoinLink(sessionId: 'S1', token: 'tok', role: Role.player, teamId: 'red');
      expect(SessionJoinLink.tryParse(invite.link), isNull, reason: 'older versions must reject it');
      expect(SessionInviteLink.tryParse(controller.link), isNull);
      expect(SessionInviteLink.tryParse(player.link), isNull);
      expect(SessionInviteLink.tryParse('quiz-studio://join/G1/I1'), isNull, reason: 'a game invite');
      expect(SessionInviteLink.tryParse('quiz-studio://session/S1/invite/a/b'), isNull);
      expect(SessionInviteLink.tryParse('quiz-studio://session/S1/invite/x y'), isNull);
    });

    test('controls the session with its own token', () {
      final join = invite.joinLink;
      expect(join.role, Role.controller);
      expect(join.token, 'tok_9');
      expect(join.teamId, isNull);
    });
  });

  test('the invite token is told apart from the QR code tokens', () {
    expect(isInviteToken({'role': 'controller', 'invite': true}), isTrue);
    expect(isInviteToken({'role': 'controller'}), isFalse);
    expect(isInviteToken({'role': 'player', 'teamId': 'red'}), isFalse);
  });

  test('a session document gives its host and the invited users', () {
    final summary = sessionSummaryOf('S1', {
      'host': 'alice',
      'name': 'Pub quiz',
      'invited': ['bob', 7, 'carol'],
    });
    expect(summary.host, 'alice');
    expect(summary.invited, ['bob', 'carol']);
    final old = sessionSummaryOf('S2', {'host': 'alice', 'name': ''});
    expect(old.invited, isEmpty, reason: 'sessions from before invites have no list');
  });

  test('sessions are sorted newest first', () {
    final sorted = sortSessions([
      const SessionSummary(id: 'a', name: '', createdAtMillis: 1),
      const SessionSummary(id: 'b', name: '', createdAtMillis: 3),
      const SessionSummary(id: 'c', name: ''),
      const SessionSummary(id: 'd', name: '', createdAtMillis: 2),
    ]);
    expect([for (final s in sorted) s.id], ['b', 'd', 'a', 'c']);
  });

  group('sessions list', () {
    Widget list({
      List<SessionSummary> sessions = const [],
      List<SessionSummary> invited = const [],
      ValueChanged<SessionSummary>? onInvite,
      ValueChanged<SessionSummary>? onControlInvited,
      ValueChanged<SessionSummary>? onLeave,
    }) =>
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SessionsList(
              sessions: sessions,
              invitedSessions: invited,
              gameNames: const {'g1': 'Pub quiz'},
              onControl: (_) {},
              onPresent: (_) {},
              onChangeGame: (_) {},
              onDelete: (_) {},
              onInvite: onInvite,
              onControlInvited: onControlInvited,
              onLeave: onLeave,
            ),
          ),
        );

    testWidgets('offers to invite to the own sessions', (tester) async {
      SessionSummary? invitedTo;
      await tester.pumpWidget(list(
        sessions: const [SessionSummary(id: 's1', name: 'Pub quiz', gameId: 'g1')],
        onInvite: (session) => invitedTo = session,
      ));
      await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invite'));
      await tester.pumpAndSettle();
      expect(invitedTo?.id, 's1');
    });

    testWidgets('shows the sessions shared with the user, to control or leave', (tester) async {
      SessionSummary? controlled, left;
      await tester.pumpWidget(list(
        invited: const [SessionSummary(id: 'x1', name: 'Their quiz', gameId: 'other', host: 'alice')],
        onControlInvited: (session) => controlled = session,
        onLeave: (session) => left = session,
      ));
      await tester.pump();
      expect(find.text('Shared with you'), findsOneWidget);
      expect(find.text('Their quiz'), findsOneWidget, reason: 'named after the game even without access to it');
      expect(find.text('Present'), findsNothing, reason: 'only the host presents');
      expect(find.textContaining('one evening'), findsNothing, reason: 'not the empty list');

      await tester.tap(find.text('Control'));
      expect(controlled?.id, 'x1');

      await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave session'));
      await tester.pumpAndSettle();
      expect(left?.id, 'x1');
    });
  });
}
