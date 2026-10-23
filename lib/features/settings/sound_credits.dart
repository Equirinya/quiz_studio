import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the sounds that come with the app are from, and under what terms.
/// Keep in step with assets/sounds/CREDITS.md.
class SoundSource {
  const SoundSource({required this.name, required this.licence, this.url, required this.sounds});

  final String name;
  final String licence;

  /// Where the source is published; none for sounds made for the app.
  final String? url;
  final List<SoundCredit> sounds;
}

class SoundCredit {
  const SoundCredit(this.label, {this.original, this.url});

  /// As the app shows it.
  final String label;

  /// The title or file name at the source, when it differs.
  final String? original;

  /// The sound's own page at the source.
  final String? url;
}

const List<SoundSource> soundSources = [
  SoundSource(
    name: "Made for Quiz Studio",
    licence: "Part of the app",
    sounds: [
      SoundCredit("Soft noise, White noise"),
      SoundCredit("Ding ding, Bwomp, Pop, Fanfare, Brass stab"),
      SoundCredit("Woodblock, Riser, Pop up, Game-show buzzer"),
      SoundCredit("Buzzers: Buzzer, Soft"),
    ],
  ),
  SoundSource(
    name: "Made by Nikita Zaloga",
    licence: "Part of the app",
    sounds: [
      SoundCredit("Music: Quiz theme, Chill, Thrilling"),
      SoundCredit("Right answer, Fanfare"),
      SoundCredit("Buzzers: Power, Light"),
    ],
  ),
  SoundSource(
    name: "Kenney: Voiceover Pack",
    licence: "CC0 1.0 (public domain)",
    url: "https://opengameart.org/content/voiceover-pack-40-lines",
    sounds: [
      SoundCredit("\"Correct!\", \"Wrong!\" (female and male)"),
      SoundCredit("\"Congratulations!\", \"It's a tie\" (female)"),
      SoundCredit("\"Ready\", \"Set\", \"Go!\", \"Hurry up!\", \"Final round\", \"Game over\" (male)"),
    ],
  ),
  SoundSource(
    name: "Kenney: Interface Sounds",
    licence: "CC0 1.0 (public domain)",
    url: "https://opengameart.org/content/interface-sounds",
    sounds: [
      SoundCredit("Confirm", original: "confirmation_001"),
      SoundCredit("Error, low; Error, short", original: "error_006, error_004"),
      SoundCredit("Select", original: "select_004"),
      SoundCredit("Pluck, Rise, Soft rise", original: "pluck_001, maximize_008, maximize_006"),
    ],
  ),
  SoundSource(
    name: "Big Sound Bank",
    licence: "CC0 (public domain)",
    url: "https://bigsoundbank.com",
    sounds: [
      SoundCredit("Counter bell", original: "Counter Bell #5", url: "https://bigsoundbank.com/counter-bell-5-s2533.html"),
      SoundCredit("Applause", original: "Applause from 40 People #7", url: "https://bigsoundbank.com/applause-from-40-people-7-s3523.html"),
      SoundCredit("Applause, short", original: "Applause Concert Bar #4", url: "https://bigsoundbank.com/applause-concert-bar-4-s2482.html"),
      SoundCredit("Drumroll", original: "Drum roll 1 S", url: "https://bigsoundbank.com/drum-roll-1-s-s2400.html"),
      SoundCredit("Ba-dum-tss", original: "Battery joke #3", url: "https://bigsoundbank.com/battery-joke-3-s2410.html"),
      SoundCredit("Ticking clock; Ticking clock, 10 seconds", original: "Tic Tac Mechanical Alarm Clock #3", url: "https://bigsoundbank.com/tic-tac-mechanical-alarm-clock-3-s2656.html"),
    ],
  ),
];

/// Lists every sound that comes with the app with its source, so anyone can
/// check where it is from.
class SoundCreditsPage extends StatelessWidget {
  const SoundCreditsPage({super.key});

  static Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Sound credits")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            "The sounds that come with Quiz Studio were made for it or are free to use in any project (CC0). "
            "Tap a source to see where it is from.",
            style: theme.textTheme.bodyMedium,
          ),
          for (final source in soundSources) ...[
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(source.name, style: theme.textTheme.titleMedium),
              subtitle: Text(source.licence),
              trailing: source.url == null ? null : const Icon(Icons.open_in_new),
              onTap: source.url == null ? null : () => _open(source.url!),
            ),
            for (final sound in source.sounds)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 12),
                title: Text(sound.label),
                subtitle: sound.original == null ? null : Text(sound.original!),
                trailing: sound.url == null ? null : const Icon(Icons.open_in_new, size: 18),
                onTap: sound.url == null ? null : () => _open(sound.url!),
              ),
          ],
        ],
      ),
    );
  }
}
