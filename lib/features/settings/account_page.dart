import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/features/assistant/assistant.dart';
import 'package:quiz_show/features/assistant/assistant_card.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/auth/user_service.dart';
import 'package:quiz_show/features/auth/widgets/auth_form.dart';
import 'package:quiz_show/features/settings/account_deletion.dart';
import 'package:quiz_show/features/settings/sound_credits.dart';
import 'package:quiz_show/l10n/l10n.dart';

const String _termsUrl = 'https://equirinya.github.io/quiz_studio/terms.html';
const String _privacyUrl = 'https://equirinya.github.io/quiz_studio/privacy.html';
const String _contactMail = 'mailto:equirinya@gmail.com';

/// The signed-in user's account, and what there is to know about the app.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? _username;
  String? _version;

  @override
  void initState() {
    super.initState();
    UserService.instance.loadUsername().then((name) {
      if (mounted) setState(() => _username = name);
    }, onError: (Object _) {});
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    }, onError: (Object _) {});
  }

  Future<void> _rename() async {
    final l10n = context.l10n;
    final name = await promptText(context, title: l10n.yourName, initial: _username ?? '', label: l10n.theNameOthersSee);
    if (name == null || !mounted) return;
    if (name.length < kUsernameMinLength || name.length > kUsernameMaxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.nameLength(kUsernameMinLength, kUsernameMaxLength))),
      );
      return;
    }
    await guarded(context, () async {
      await UserService.instance.rename(name);
      if (mounted) setState(() => _username = name);
    });
  }

  Future<void> _upgrade() async {
    final l10n = context.l10n;
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
        child: SingleChildScrollView(
          child: AuthForm(
            mode: AuthFormMode.register,
            title: l10n.addEmailAndPassword,
            subtitle: l10n.upgradeSubtitle,
            submitText: l10n.save,
            autofocus: true,
            onSubmit: (email, password) => UserService.instance.addEmailAndPassword(email, password, l10n),
            onSuccess: () => Navigator.of(context).pop(true),
          ),
        ),
      ),
    );
    if (done == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.upgradeDone)));
    }
  }

  Future<void> _signOut(bool guest) async {
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    final sure = await confirm(
      context,
      title: l10n.signOut,
      message: guest
          ? l10n.signOutGuestWarning
          : l10n.signOutInfo,
      action: l10n.signOut,
    );
    if (!sure) return;
    navigator.popUntil((route) => route.isFirst);
    // The assistant acts as the signed-in user; it ends with the sign-in.
    await Assistant.instance.stop();
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _delete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final password = await showDialog<String>(context: context, builder: (_) => DeleteAccountDialog(email: user.email));
    if (password == null || !mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(content: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 20), Expanded(child: Text(l10n.deletingAccount))])),
      ),
    );
    try {
      await Assistant.instance.stop();
      await deleteAccount(password: user.email == null ? null : password);
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
    } on FirebaseAuthException catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(deletionErrorMessage(l10n, e.code))));
    } catch (_) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountNotDeletedConnection)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.account)),
      body: AccountView(
        username: _username,
        email: user?.email,
        guest: user?.isAnonymous ?? true,
        version: _version,
        onRename: _rename,
        onUpgrade: _upgrade,
        onSignOut: () => _signOut(user?.isAnonymous ?? true),
        onDelete: _delete,
        assistant: Assistant.supported ? const AssistantSection() : null,
      ),
    );
  }
}

/// The account page's content, from plain values.
class AccountView extends StatelessWidget {
  const AccountView({
    super.key,
    required this.username,
    required this.email,
    required this.guest,
    required this.version,
    required this.onRename,
    required this.onUpgrade,
    required this.onSignOut,
    this.onDelete,
    this.assistant,
  });

  final String? username;
  final String? email;
  final bool guest;
  final String? version;
  final VoidCallback onRename;
  final VoidCallback onUpgrade;
  final VoidCallback onSignOut;

  /// Deleting the account; null hides it.
  final VoidCallback? onDelete;

  /// The assistant switch, on computers.
  final Widget? assistant;

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(username ?? "…"),
          subtitle: Text(l10n.nameSubtitle),
          trailing: const Icon(Icons.edit_outlined),
          onTap: onRename,
        ),
        if (guest)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.guestAccount, style: theme.textTheme.titleMedium?.copyWith(color: scheme.onTertiaryContainer)),
                const SizedBox(height: 4),
                Text(
                  l10n.guestAccountText,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onTertiaryContainer),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onUpgrade,
                  icon: const Icon(Icons.mail_outline),
                  label: Text(l10n.addEmailAndPassword),
                ),
              ],
            ),
          )
        else
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(email ?? ""),
            subtitle: Text(l10n.emailSubtitle),
          ),
        ListTile(leading: const Icon(Icons.logout), title: Text(l10n.signOut), onTap: onSignOut),
        if (onDelete != null)
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text(l10n.deleteAccount, style: TextStyle(color: scheme.error)),
            subtitle: Text(l10n.deleteAccountSubtitle),
            onTap: onDelete,
          ),
        if (assistant != null) ...[const Divider(height: 32), assistant!],
        const Divider(height: 32),
        const LanguageTile(),
        ListTile(
          leading: const Icon(Icons.mail_outlined),
          title: Text(l10n.contact),
          subtitle: Text(l10n.contactSubtitle),
          onTap: () => _open(_contactMail),
        ),
        ListTile(leading: const Icon(Icons.gavel_outlined), title: Text(l10n.terms), onTap: () => _open(_termsUrl)),
        ListTile(leading: const Icon(Icons.shield_outlined), title: Text(l10n.privacy), onTap: () => _open(_privacyUrl)),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.aboutAndLicences),
          subtitle: Text(version == null ? "Quiz Studio" : "Quiz Studio $version"),
          onTap: () => showLicensePage(context: context, applicationName: "Quiz Studio", applicationVersion: version),
        ),
        ListTile(
          leading: const Icon(Icons.library_music_outlined),
          title: Text(l10n.soundCredits),
          subtitle: Text(l10n.soundCreditsSubtitle),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SoundCreditsPage())),
        ),
      ],
    );
  }
}

/// Asks before deleting the account, and for the password of one with an
/// email address. Pops with the password ('' for a guest), or null.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.email});

  final String? email;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final needsPassword = widget.email != null;
    final l10n = context.l10n;
    return AlertDialog(
      icon: Icon(Icons.delete_forever_outlined, color: scheme.error),
      title: Text(l10n.deleteAccountQuestion),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deleteAccountText),
          if (needsPassword) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.password, helperText: widget.email),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: needsPassword && _password.text.isEmpty ? null : () => Navigator.of(context).pop(needsPassword ? _password.text : ''),
          child: Text(l10n.delete),
        ),
      ],
    );
  }
}

/// What to tell someone whose account could not be deleted.
String deletionErrorMessage(AppLocalizations l10n, String code) => switch (code) {
      'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' => l10n.wrongPassword,
      'too-many-requests' => l10n.tooManyTries,
      'requires-recent-login' => l10n.requiresRecentLogin,
      'network-request-failed' => l10n.noConnectionTryOnline,
      _ => l10n.accountNotDeleted,
    };

/// The app's language: the system's, German or English.
class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key});

  static String _name(AppLocalizations l10n, Locale? locale) => switch (locale?.languageCode) {
    'de' => l10n.languageGerman,
    'en' => l10n.languageEnglish,
    _ => l10n.languageSystem,
  };

  Future<void> _pick(BuildContext context) async {
    final l10n = context.l10n;
    final current = AppLanguage.locale.value;
    const choices = <Locale?>[null, Locale('de'), Locale('en')];
    final picked = await showDialog<(Locale?,)>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          for (final choice in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop((choice,)),
              child: Row(
                children: [
                  Expanded(child: Text(_name(l10n, choice))),
                  if (choice?.languageCode == current?.languageCode) const Icon(Icons.check),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null) await AppLanguage.set(picked.$1);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: AppLanguage.locale,
    builder: (context, locale, _) => ListTile(
      leading: const Icon(Icons.translate),
      title: Text(context.l10n.language),
      subtitle: Text(_name(context.l10n, locale)),
      onTap: () => _pick(context),
    ),
  );
}
