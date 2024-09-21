import 'package:flutter/material.dart';
import 'package:quiz_show/pages/settings.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 128),
      children: [
        const AboutSettingsTile(),
        ListTile(
          title: const Text("Kontakt"),
          subtitle: const Text("Schreibe mir für Feedback, Bug Reports oder Feature Requests"),
          leading: const Icon(Icons.mail_outline),
          onTap: () => launchUrl(Uri.parse("mailto:equirinya@gmail.com")),
        ),
        // ListTile(
        //   title: Text("Datenschutz"),
        //   subtitle: Text("Datenschutzerklärung"),
        //   leading: Icon(Icons.shield_outlined),
        //   onTap: () => launchUrl(Uri.parse("https://raw.githubusercontent.com/Equirinya/moodiary/master/privacy_policy.md")),
        // ),
        //TODO explanation how and which data is stored
        //https://www.flaticon.com/de/kostenlose-icons/quiz
      ],
    );
  }
}
