import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/features/assistant/assistant.dart';
import 'package:quiz_show/features/assistant/assistant_card.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/auth/user_service.dart';
import 'package:quiz_show/features/auth/widgets/auth_form.dart';
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
    this.assistant,
  });

  final String? username;
  final String? email;
  final bool guest;
  final String? version;
  final VoidCallback onRename;
  final VoidCallback onUpgrade;
  final VoidCallback onSignOut;

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
