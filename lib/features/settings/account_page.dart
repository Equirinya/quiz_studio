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
    final name = await promptText(context, title: "Your name", initial: _username ?? '', label: "The name others see");
    if (name == null || !mounted) return;
    if (name.length < kUsernameMinLength || name.length > kUsernameMaxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("A name needs between $kUsernameMinLength and $kUsernameMaxLength characters.")),
      );
      return;
    }
    await guarded(context, () async {
      await UserService.instance.rename(name);
      if (mounted) setState(() => _username = name);
    });
  }

  Future<void> _upgrade() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
        child: SingleChildScrollView(
          child: AuthForm(
            mode: AuthFormMode.register,
            title: "Add email and password",
            subtitle: "Your games stay with this account. Afterwards you can sign in to it on your other devices.",
            submitText: "Save",
            autofocus: true,
            onSubmit: UserService.instance.addEmailAndPassword,
            onSuccess: () => Navigator.of(context).pop(true),
          ),
        ),
      ),
    );
    if (done == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Done. This account now has an email address.")));
    }
  }

  Future<void> _signOut(bool guest) async {
    final navigator = Navigator.of(context);
    final sure = await confirm(
      context,
      title: "Sign out",
      message: guest
          ? "You are signed in as a guest. Signing out loses this account and the games only it can access. "
              "Add an email address first to keep them."
          : "You can sign in again with your email address and password.",
      action: "Sign out",
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
    final password = await showDialog<String>(context: context, builder: (_) => DeleteAccountDialog(email: user.email));
    if (password == null || !mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Expanded(child: Text("Deleting your account…"))])),
      ),
    );
    try {
      await Assistant.instance.stop();
      await deleteAccount(password: user.email == null ? null : password);
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text("Your account and its data are deleted.")));
    } on FirebaseAuthException catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(deletionErrorMessage(e.code))));
    } catch (_) {
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text("The account could not be deleted. Check the connection and try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text("Account")),
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
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(username ?? "…"),
          subtitle: const Text("The name other players and co-authors see"),
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
                Text("Guest account", style: theme.textTheme.titleMedium?.copyWith(color: scheme.onTertiaryContainer)),
                const SizedBox(height: 4),
                Text(
                  "Your games live only on this device's account. Add an email address and password to keep them "
                  "safe and to sign in on your other devices, for example the PC that presents and the phone that controls.",
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onTertiaryContainer),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onUpgrade,
                  icon: const Icon(Icons.mail_outline),
                  label: const Text("Add email and password"),
                ),
              ],
            ),
          )
        else
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(email ?? ""),
            subtitle: const Text("Sign in with this address on your other devices"),
          ),
        ListTile(leading: const Icon(Icons.logout), title: const Text("Sign out"), onTap: onSignOut),
        if (onDelete != null)
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text("Delete account", style: TextStyle(color: scheme.error)),
            subtitle: const Text("Your profile, your own games and your sessions"),
            onTap: onDelete,
          ),
        if (assistant != null) ...[const Divider(height: 32), assistant!],
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.mail_outlined),
          title: const Text("Contact"),
          subtitle: const Text("Feedback, bug reports and feature requests"),
          onTap: () => _open(_contactMail),
        ),
        ListTile(leading: const Icon(Icons.gavel_outlined), title: const Text("Terms"), onTap: () => _open(_termsUrl)),
        ListTile(leading: const Icon(Icons.shield_outlined), title: const Text("Privacy"), onTap: () => _open(_privacyUrl)),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text("About and licences"),
          subtitle: Text(version == null ? "Quiz Studio" : "Quiz Studio $version"),
          onTap: () => showLicensePage(context: context, applicationName: "Quiz Studio", applicationVersion: version),
        ),
        ListTile(
          leading: const Icon(Icons.library_music_outlined),
          title: const Text("Sound credits"),
          subtitle: const Text("Where the built-in sounds are from"),
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
    return AlertDialog(
      icon: Icon(Icons.delete_forever_outlined, color: scheme.error),
      title: const Text("Delete account?"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "This deletes your profile, the games only you are in, with their pictures and sounds, and the sessions you host. "
            "Games you share stay with the others; if you are their only admin, a co-author becomes admin. "
            "This cannot be undone.",
          ),
          if (needsPassword) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: "Password", helperText: widget.email),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: needsPassword && _password.text.isEmpty ? null : () => Navigator.of(context).pop(needsPassword ? _password.text : ''),
          child: const Text("Delete"),
        ),
      ],
    );
  }
}

/// What to tell someone whose account could not be deleted.
String deletionErrorMessage(String code) => switch (code) {
      'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' => "That password is not right.",
      'too-many-requests' => "Too many tries. Wait a moment and try again.",
      'requires-recent-login' => "Sign out, sign in again and then delete the account.",
      'network-request-failed' => "No connection. Try again when you are online.",
      _ => "The account could not be deleted. Try again.",
    };
