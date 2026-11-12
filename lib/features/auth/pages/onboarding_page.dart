import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:quiz_show/core/animated_background.dart';
import 'package:quiz_show/core/incoming_links.dart';
import 'package:quiz_show/features/auth/user_service.dart';
import 'package:quiz_show/features/auth/widgets/auth_form.dart';
import 'package:quiz_show/features/player/pages/join_session_page.dart';
import 'package:quiz_show/features/session/session_links.dart';
import 'package:quiz_show/l10n/l10n.dart';

// Hosted on GitHub Pages (see /docs). jekyll-relative-links serves these as .html.
const String _termsUrl = 'https://equirinya.github.io/quiz_studio/terms.html';
const String _privacyUrl = 'https://equirinya.github.io/quiz_studio/privacy.html';

class FeatureSpec {
  const FeatureSpec(this.icon, this.label, this.blurb);

  final IconData icon;
  final String label;
  final String blurb;
}

List<FeatureSpec> onboardingFeatures(AppLocalizations l10n) => [
  FeatureSpec(Icons.quiz, l10n.featureBuildTitle, l10n.featureBuildText),
  FeatureSpec(Icons.tv, l10n.featurePresentTitle, l10n.featurePresentText),
  FeatureSpec(Icons.touch_app, l10n.featureBuzzersTitle, l10n.featureBuzzersText),
  FeatureSpec(Icons.music_note, l10n.featureMusicTitle, l10n.featureMusicText),
];

enum _Step { showcase, login, name }

/// First-run flow. A new user picks a display name and gets an anonymous
/// account; an existing user signs in with email and password.
///
/// This is shown in place of the app, not pushed as a route: the host swaps it
/// out when [onFinished] is called.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.onFinished, this.nameOnly = false});

  final VoidCallback onFinished;

  /// Someone is already signed in but has no profile yet: ask for the name
  /// only and keep the account they have.
  final bool nameOnly;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late _Step step = widget.nameOnly ? _Step.name : _Step.showcase;

  final TextEditingController _usernameCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    // A session code scanned with the camera app goes straight in, no
    // account to set up first.
    IncomingLinks.instance.pending.addListener(_onLink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onLink());
  }

  @override
  void dispose() {
    IncomingLinks.instance.pending.removeListener(_onLink);
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _onLink() {
    final link = IncomingLinks.instance.pending.value;
    // Game invites need an account; they wait for the home page.
    if (!mounted || link == null || SessionJoinLink.tryParse(link) == null) return;
    IncomingLinks.instance.take();
    _joinAsGuest(link: link);
  }

  bool _joining = false;

  /// A team's device needs no name and no profile: an anonymous account is
  /// enough to join, and without the internet it joins over the local
  /// network anyway. Becoming a gamemaster later only asks for a name.
  Future<void> _joinAsGuest({String? link}) async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      if (FirebaseAuth.instance.currentUser == null) await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {
      // Offline: the code's local addresses still work.
    }
    if (!mounted) return;
    setState(() => _joining = false);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => JoinSessionPage(initialLink: link, asGuest: true)));
  }

  // ── navigation ─────────────────────────────────────────────────────────────

  bool get _canGoBack => step != _Step.showcase && !widget.nameOnly;

  void _back() {
    if (!_canGoBack) return;
    setState(() {
      _error = null;
      step = _Step.showcase;
    });
  }

  void _toLogin() => setState(() {
        _error = null;
        step = _Step.login;
      });

  Future<void> _useOtherAccount() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  bool get _nameValid => _usernameCtrl.text.trim().length >= kUsernameMinLength;

  // ── account ────────────────────────────────────────────────────────────────

  /// Signs in an existing account from the login step. Returns `null` on
  /// success or a user-facing error message.
  Future<String?> _signIn(String email, String password) async {
    final l10n = context.l10n;
    if (email.isEmpty || !email.contains('@')) {
      return l10n.enterValidEmail;
    }
    if (password.isEmpty) {
      return l10n.enterPassword;
    }
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return l10n.noAccountForEmail;
        case 'wrong-password':
        case 'invalid-credential':
          return l10n.wrongEmailOrPassword;
        case 'invalid-email':
          return l10n.invalidEmailShort;
        case 'user-disabled':
          return l10n.accountDisabled;
        case 'too-many-requests':
          return l10n.tooManyAttempts;
        case 'network-request-failed':
          return l10n.notConnected;
        default:
          return l10n.signInFailed;
      }
    } catch (_) {
      return l10n.signInFailed;
    }
    return null;
  }

  /// Creates the (anonymous) account, unless someone is signed in already, and
  /// the user's profile. An email and password can be added later in settings.
  Future<void> _createAccount() async {
    if (_loading || !_nameValid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await _signInAndCreateProfile();
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }
    widget.onFinished();
  }

  Future<String?> _signInAndCreateProfile() async {
    final l10n = context.l10n;
    final auth = FirebaseAuth.instance;
    try {
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'network-request-failed':
          return l10n.notConnected;
        case 'operation-not-allowed':
          return l10n.anonymousSignInDisabled;
        default:
          return l10n.couldNotStart;
      }
    } catch (_) {
      return l10n.unknownError;
    }

    try {
      await UserService.instance.createProfile(_usernameCtrl.text.trim());
    } catch (_) {
      return l10n.couldNotSaveName;
    }
    return null;
  }

  Future<void> _openLink(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: Theme(
          data: onboardingTheme(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              animatedBackground(),
              ColoredBox(color: Colors.black.withAlpha(50)),
              SafeArea(
                // Keeps the flow phone-shaped on a desktop window or a tablet.
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        if (step != _Step.name) _logo(context),
                        Expanded(child: _content()),
                        _bottomBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final side = min(min(size.width, size.height) / 7, 96.0);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: side,
            width: side,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
              child: Image.asset("assets/icon/icon_transparent.png"),
            ),
          ),
          Text(
            "Quiz Studio",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    switch (step) {
      case _Step.showcase:
        return _ShowcasePage(
          onLogin: _toLogin,
          onStart: () => setState(() => step = _Step.name),
          onJoin: _joining ? null : _joinAsGuest,
        );
      case _Step.login:
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: AuthForm(
            mode: AuthFormMode.login,
            submitText: context.l10n.login,
            reserveErrorSpace: true,
            onSubmit: _signIn,
            onSuccess: widget.onFinished,
          ),
        );
      case _Step.name:
        return _namePage();
    }
  }

  Widget _namePage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _logo(context),
                const SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    context.l10n.chooseYourName,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: TextField(
                    controller: _usernameCtrl,
                    enabled: !_loading,
                    autofocus: true,
                    maxLength: kUsernameMaxLength,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.name],
                    onSubmitted: (_) => _createAccount(),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person_outline),
                      hintText: context.l10n.theNameOthersWillSee,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: _termsText(),
                ),
                // Someone who only plays along never needs a name.
                if (widget.nameOnly)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: _joining ? null : _joinAsGuest,
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.black87),
                        label: Text(context.l10n.justJoinAShow, style: const TextStyle(color: Colors.black87)),
                      ),
                    ),
                  ),
                // Signed in to an account that has no name yet: maybe the
                // wrong one. Signing out leads back to the welcome screen.
                if (widget.nameOnly)
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : _useOtherAccount,
                      child: Text(context.l10n.useDifferentAccount, style: const TextStyle(color: Colors.black87)),
                    ),
                  )
                // A guest who came to set up quizzes may have an account after all.
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: TextButton(
                        onPressed: _loading ? null : _toLogin,
                        child: Text(context.l10n.haveAnAccount, style: const TextStyle(color: Colors.black87)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _termsText() {
    const base = TextStyle(color: Colors.black87, fontSize: 13);
    const link = TextStyle(color: Color(0xFF0A3F8F), fontSize: 13, decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: context.l10n.termsBefore),
          TextSpan(text: context.l10n.termsLink, style: link, recognizer: TapGestureRecognizer()..onTap = () => _openLink(_termsUrl)),
          TextSpan(text: context.l10n.termsBetween),
          TextSpan(text: context.l10n.privacyLink, style: link, recognizer: TapGestureRecognizer()..onTap = () => _openLink(_privacyUrl)),
          TextSpan(text: context.l10n.termsAfter),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _bottomBar() {
    if (step == _Step.showcase) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null && _error!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
            ),
          Row(
            children: [
              if (_canGoBack)
                IconButton(
                  onPressed: _loading ? null : _back,
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  tooltip: context.l10n.back,
                ),
              if (step == _Step.name)
                Expanded(
                  child: FilledButton(
                    onPressed: !_loading && _nameValid ? _createAccount : null,
                    child: _loading ? const CupertinoActivityIndicator() : Text(context.l10n.letsPlay),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

ThemeData onboardingTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.white,
      dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      brightness: Brightness.light,
    ).copyWith(
      onSurfaceVariant: Colors.black,
      onSurface: Colors.black,
      secondary: Colors.black,
      outline: Colors.black,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      fillColor: Colors.white.withAlpha(230),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

// ───────────────────────────────────────────────────────────────────────────
// Showcase page: large feature pills + the two entry buttons.
// ───────────────────────────────────────────────────────────────────────────

class _ShowcasePage extends StatelessWidget {
  const _ShowcasePage({required this.onLogin, required this.onStart, required this.onJoin});

  final VoidCallback onLogin;
  final VoidCallback onStart;

  /// A team's device: scan the code, nothing else.
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            children: [
              for (final f in onboardingFeatures(context.l10n)) _FeaturePill(feature: f),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Column(
            children: [
              FilledButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(context.l10n.joinAShow),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: onStart, child: Text(context.l10n.createOwnQuizzes)),
              const SizedBox(height: 4),
              TextButton(onPressed: onLogin, child: Text(context.l10n.haveAnAccount)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.feature});

  final FeatureSpec feature;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), shape: BoxShape.circle),
                  child: Icon(feature.icon, color: Colors.black87, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.label,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(feature.blurb, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
