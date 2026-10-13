import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/core/animated_background.dart';
import 'package:quiz_show/features/auth/pages/onboarding_page.dart';
import 'package:quiz_show/features/auth/user_service.dart';

enum _Profile { unknown, missing, present }

/// Shows [child] only to a signed-in user who has a profile; everyone else
/// gets the onboarding flow.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _authSub;
  User? _user = FirebaseAuth.instance.currentUser;

  /// True from the moment nobody is signed in until onboarding reports it is
  /// done. Onboarding signs in before it has written the profile, so the auth
  /// stream alone would pull the flow away mid-step.
  late bool _onboarding = _user == null;

  _Profile _profile = _Profile.unknown;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
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
      _user = FirebaseAuth.instance.currentUser;
      _onboarding = false;
      _profile = _Profile.unknown;
    });
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _Profile result;
    try {
      final username = await UserService.instance.loadUsername();
      result = username == null ? _Profile.missing : _Profile.present;
      if (username != null) {
        UserService.instance.onLogin(username).catchError((Object error) {
          if (kDebugMode) print('Auth gate: login bookkeeping failed: $error');
        });
      }
    } catch (error) {
      // An unreadable profile must not lock a signed-in user out of the app.
      if (kDebugMode) print('Auth gate: profile read failed: $error');
      result = _Profile.present;
    }
    if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
    setState(() => _profile = result);
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
