import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/core/animated_background.dart';
import 'package:quiz_show/features/auth/pages/onboarding_page.dart';
import 'package:quiz_show/features/auth/user_service.dart';

enum _Profile { unknown, missing, present }

/// Who is signed in, as far as the gate cares.
typedef GateUser = ({String uid, bool anonymous});

/// What the gate reads: Firebase in the app, a fake in tests.
class AuthGateBackend {
  const AuthGateBackend();

  GateUser? _of(User? user) => user == null ? null : (uid: user.uid, anonymous: user.isAnonymous);

  GateUser? get currentUser => _of(FirebaseAuth.instance.currentUser);

  Stream<GateUser?> changes() => FirebaseAuth.instance.authStateChanges().map(_of);

  /// The stored display name, or null when there is no profile yet.
  Future<String?> loadUsername() => UserService.instance.loadUsername();

  Future<void> onLogin(String username) => UserService.instance.onLogin(username);
}

/// Shows [child] only to a signed-in user who has a profile; everyone else
/// gets the onboarding flow.
///
/// A guest account (anonymous, no profile) comes from joining a show as a
/// team's device. It gets the whole welcome screen again on the next launch,
/// so it can join again, set up its own quizzes or sign in to an existing
/// account. Only a real account without a profile is asked for the name alone.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child, this.backend = const AuthGateBackend()});

  final Widget child;

  /// Replaced in tests.
  final AuthGateBackend backend;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<GateUser?>? _authSub;
  late GateUser? _user = widget.backend.currentUser;

  /// True from the moment nobody (or only a guest) is signed in until
  /// onboarding reports it is done. Onboarding signs in before it has written
  /// the profile, so the auth stream alone would pull the flow away mid-step.
  late bool _onboarding = _user == null;

  _Profile _profile = _Profile.unknown;

  @override
  void initState() {
    super.initState();
    _authSub = widget.backend.changes().listen((user) {
      if (!mounted) return;
      final changed = user?.uid != _user?.uid;
      setState(() {
        _user = user;
        if (user == null) {
          _onboarding = true;
          _profile = _Profile.unknown;
        }
      });
      if (user != null && !_onboarding && (changed || _profile == _Profile.unknown)) _checkProfile();
    });
    if (_user != null) _checkProfile();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _onboardingFinished() {
    setState(() {
      _user = widget.backend.currentUser;
      _onboarding = false;
      _profile = _Profile.unknown;
    });
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final uid = widget.backend.currentUser?.uid;
    if (uid == null) return;
    _Profile result;
    try {
      final username = await widget.backend.loadUsername();
      result = username == null ? _Profile.missing : _Profile.present;
      if (username != null) {
        widget.backend.onLogin(username).catchError((Object error) {
          if (kDebugMode) print('Auth gate: login bookkeeping failed: $error');
        });
      }
    } catch (error) {
      // An unreadable profile must not lock a signed-in user out of the app.
      if (kDebugMode) print('Auth gate: profile read failed: $error');
      result = _Profile.present;
    }
    final user = widget.backend.currentUser;
    if (!mounted || user?.uid != uid) return;
    setState(() {
      _profile = result;
      // A guest back on the welcome screen keeps their account: joining
      // again reuses it, a name makes it their own, a sign-in replaces it.
      if (result == _Profile.missing && user!.anonymous) _onboarding = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null || _onboarding) {
      return WelcomePage(key: const ValueKey('welcome'), onFinished: _onboardingFinished);
    }
    switch (_profile) {
      case _Profile.unknown:
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [animatedBackground(), const Center(child: CupertinoActivityIndicator())],
          ),
        );
      case _Profile.missing:
        return WelcomePage(key: const ValueKey('name'), nameOnly: true, onFinished: _onboardingFinished);
      case _Profile.present:
        return widget.child;
    }
  }
}
