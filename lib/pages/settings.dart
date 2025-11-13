import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:quiz_show/pages/about.dart';
import 'package:quiz_show/pages/games.dart';
import 'package:quiz_show/pages/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'buzzer_connection.dart';

Future<void> openSettings(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsPage(),));

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});


  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SharedPreferences prefs;
  bool initialized = false;

  @override
  void initState() {
    () async {
      prefs = await SharedPreferences.getInstance();
      setState(() {
        initialized = true;
      });
    }
    ();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const CupertinoActivityIndicator();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          if(!(Platform.isAndroid || Platform.isIOS)) const SettingsSubPage.fullPage(
              title: "Games", subtitle: "Edit and create new Quizzes", icon: Icons.quiz, body: GamesPage()),
          if(!Platform.isAndroid || Platform.isIOS) const SettingsSubPage.fullPage(title: "Session", subtitle: "Game, Teams", icon: Icons.gamepad_outlined, body: SessionPage()),
          if(Platform.isWindows) SettingsSubPage.fullPage(
              title: "Buzzer",
              subtitle: "Sensitivity and team-mapping",
              icon: MdiIcons.bullseye,
              body: const BuzzerConnectionPage()),
          SettingsSubPage(title: "Account", subtitle: "Nutzername, Profilbild, Ausloggen", icon: Icons.person_outline, categories: [
            SettingsSubPageCategory(
              title: null,
              settings: [
                //TODO account settings
                // StringSetting(
                //     setting: "username",
                //     title: "Nutzername",
                //     icon: Icons.person_outline,
                //     fallback: "Gast"),
                // ListTile(
                //   title: Text("Profilbild ändern"),
                //   leading: Icon(Icons.image_outlined),
                //   onTap: () {
                //     //TODO change profile picture
                //   },
                // ),
                ListTile(
                  title: const Text("Ausloggen"),
                  leading: const Icon(Icons.logout),
                  onTap: () {
                    FirebaseAuth.instance.signOut();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
            ),
          ]),
          const SettingsSubPage.fullPage(
            title: "Über",
            subtitle: "Lizenzen, Information und Feedback",
            icon: Icons.info_outline,
            body: AboutPage(),
          )
        ],
      ),
    );
  }
}

class SettingsSubPage extends StatelessWidget {
  final Widget body;
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool openOnLoad;

  SettingsSubPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required List<Widget> categories,
    this.openOnLoad = false,
  }) : body = ListView(
    padding: const EdgeInsets.only(bottom: 128),
    children: categories,
  );

  const SettingsSubPage.fullPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.body,
    this.openOnLoad = false,
  });

  @override
  Widget build(BuildContext context) {
    if (openOnLoad)
      Future.delayed(const Duration(milliseconds: 500),
              () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => Scaffold(body: body))));
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      leading: Icon(icon),
      trailing: Icon(Icons.chevron_right_rounded),
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) =>
                Scaffold(
                  appBar: AppBar(
                    title: Text(title),
                  ),
                  body: body,
                ),
          )),
    );
  }
}

class SettingsSubPageCategory extends StatelessWidget {
  const SettingsSubPageCategory({super.key, required this.title, required this.settings});

  final String? title;
  final List<Widget> settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 16, bottom: 8),
            child: Text(
              title!,
              style: Theme
                  .of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Theme
                  .of(context)
                  .colorScheme
                  .primary),
            ),
          ),
        ...settings
      ],
    );
  }
}

class BoolSetting extends StatefulWidget {
  const BoolSetting({super.key,
    required this.setting,
    this.fallback = false,
    this.callback,
    required this.title,
    this.subtitle,
    required this.icon});

  final String setting;
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool fallback;
  final Function(bool value)? callback;

  @override
  State<BoolSetting> createState() => _BoolSettingState();
}

class _BoolSettingState extends State<BoolSetting> {
  late SharedPreferences prefs;
  bool initialized = false;

  @override
  void initState() {
    asyncInitState();
    super.initState();
  }

  void asyncInitState() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const ListTile(title: CupertinoActivityIndicator());
    return SwitchListTile(
      title: Text(widget.title),
      subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
      secondary: Icon(widget.icon),
      value: prefs.getBool(widget.setting) ?? widget.fallback,
      onChanged: (value) {
        prefs.setBool(widget.setting, value);
        if (widget.callback != null) widget.callback!(value);
        setState(() {});
      },
    );
  }
}

class StringSetting extends StatefulWidget {
  const StringSetting(
      {super.key, required this.setting, this.fallback = "", required this.title, this.subtitle, required this.icon});

  final String setting;
  final String title;
  final String? subtitle;
  final IconData icon;
  final String fallback;

  @override
  State<StringSetting> createState() => _StringSettingState();
}

class _StringSettingState extends State<StringSetting> {
  late SharedPreferences prefs;
  bool initialized = false;

  @override
  void initState() {
    asyncInitState();
    super.initState();
  }

  void asyncInitState() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const ListTile(title: CupertinoActivityIndicator());
    return ListTile(
        title: Text(widget.title),
        subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
        leading: Icon(widget.icon),
        onTap: () =>
            showDialog(
                context: context,
                builder: (context) {
                  TextEditingController controller =
                  TextEditingController(text: prefs.getString(widget.setting) ?? widget.fallback);
                  return StatefulBuilder(
                      builder: (context, setState) =>
                          AlertDialog(
                            icon: Icon(widget.icon),
                            title: Text(widget.title),
                            content: TextField(
                              controller: controller,
                            ),
                            actions: [
                              TextButton(
                                  style:
                                  TextButton.styleFrom(backgroundColor: Theme
                                      .of(context)
                                      .colorScheme
                                      .primaryContainer),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    prefs.setString(widget.setting, controller.text);
                                  },
                                  child: const Text("Bestätigen")),
                              TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text("Abbrechen"))
                            ],
                          ));
                }).then((value) => setState(() {})));
  }
}

class InlineSelectionSetting extends StatefulWidget {
  const InlineSelectionSetting({super.key,
    required this.setting,
    this.fallbackIndex = 0,
    required this.title,
    required this.icon,
    required this.options,
    this.callback});

  final String setting;
  final String title;
  final List<String> options;
  final IconData icon;
  final int fallbackIndex;
  final Function(int index)? callback;

  @override
  State<InlineSelectionSetting> createState() => _InlineSelectionSettingState();
}

class _InlineSelectionSettingState extends State<InlineSelectionSetting> {
  late SharedPreferences prefs;
  bool initialized = false;
  late String selectedOption;

  @override
  void initState() {
    asyncInitState();
    super.initState();
  }

  void asyncInitState() async {
    prefs = await SharedPreferences.getInstance();
    selectedOption =
        widget.options.elementAtOrNull(prefs.getInt(widget.setting) ?? widget.fallbackIndex) ?? "Invalid option chosen";
    setState(() {
      initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const ListTile(title: CupertinoActivityIndicator());
    return ListTile(
      title: Text(widget.title),
      subtitle: Text(selectedOption),
      leading: Icon(widget.icon),
      trailing: SegmentedButton<String>(
          segments: <ButtonSegment<String>>[
            for (final option in widget.options) ButtonSegment<String>(value: option, label: Text(option)),
          ],
          selected: <String>{
            selectedOption
          },
          onSelectionChanged: (Set<String> newSelection) {
            setState(() {
              selectedOption = newSelection.first;
            });
            widget.callback?.call(widget.options.indexOf(selectedOption));
            int index = widget.options.indexOf(selectedOption);
            if (index != -1) prefs.setInt(widget.setting, index);
          }),
    );
  }
}

class SelectionSetting extends StatefulWidget {
  const SelectionSetting({super.key,
    required this.setting,
    this.fallbackIndex = 0,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.options,
    this.callback});

  final String setting;
  final String title;
  final String? subtitle;
  final List<String> options;
  final IconData icon;
  final int fallbackIndex;
  final Function(int index)? callback;

  @override
  State<SelectionSetting> createState() => _SelectionSettingState();
}

class _SelectionSettingState extends State<SelectionSetting> {
  late SharedPreferences prefs;
  bool initialized = false;

  @override
  void initState() {
    asyncInitState();
    super.initState();
  }

  void asyncInitState() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const ListTile(title: CupertinoActivityIndicator());
    return ListTile(
        title: Text(widget.title),
        subtitle: Text(widget.options.elementAtOrNull(prefs.getInt(widget.setting) ?? widget.fallbackIndex) ??
            "Invalid option chosen"),
        leading: Icon(widget.icon),
        onTap: () =>
            showDialog(
                context: context,
                builder: (context) {
                  int index = prefs.getInt(widget.setting) ?? widget.fallbackIndex;
                  return StatefulBuilder(
                      builder: (context, setState) =>
                          AlertDialog(
                            icon: Icon(widget.icon),
                            title: Text(widget.title),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.subtitle != null && widget.subtitle!.isNotEmpty) Text(widget.subtitle!),
                                  const SizedBox(height: 16),
                                  for (final option in widget.options)
                                    RadioListTile(
                                      title: Text(option),
                                      value: option,
                                      groupValue: widget.options.elementAtOrNull(index),
                                      onChanged: (value) {
                                        index = widget.options.indexOf(value ?? widget.options[0]);
                                        setState(() {});
                                      },
                                    )
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                  style:
                                  TextButton.styleFrom(backgroundColor: Theme
                                      .of(context)
                                      .colorScheme
                                      .primaryContainer),
                                  onPressed: () async {
                                    await prefs.setInt(widget.setting, index);
                                    Navigator.of(context).pop();
                                    if (widget.callback != null) {
                                      widget.callback!(index);
                                    }
                                  },
                                  child: const Text("Bestätigen")),
                              TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text("Abbrechen"))
                            ],
                          ));
                }).then((value) => setState(() {})));
  }
}

class StringSelectionSetting extends StatefulWidget {
  const StringSelectionSetting({super.key,
    required this.setting,
    this.fallback,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.options,
    this.callback});

  final String setting;
  final String title;
  final String? subtitle;
  final List<String> options;
  final IconData icon;
  final String? fallback;
  final Function(String value)? callback;

  @override
  State<StringSelectionSetting> createState() => _StringSelectionSettingState();
}

class _StringSelectionSettingState extends State<StringSelectionSetting> {
  late SharedPreferences prefs;
  bool initialized = false;

  @override
  void initState() {
    asyncInitState();
    super.initState();
  }

  void asyncInitState() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const ListTile(title: CupertinoActivityIndicator());
    return ListTile(
        title: Text(widget.title),
        subtitle: Text(
            prefs.getString(widget.setting) ?? widget.fallback ?? widget.options.firstOrNull ?? "No options available"),
        leading: Icon(widget.icon),
        onTap: () =>
            showDialog(
                context: context,
                builder: (context) {
                  String groupValue =
                      prefs.getString(widget.setting) ?? widget.fallback ?? widget.options.firstOrNull ?? "";
                  return StatefulBuilder(
                      builder: (context, setState) =>
                          AlertDialog(
                            icon: Icon(widget.icon),
                            title: Text(widget.title),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.subtitle != null && widget.subtitle!.isNotEmpty) Text(widget.subtitle!),
                                  const SizedBox(height: 16),
                                  for (final option in widget.options)
                                    RadioListTile(
                                      title: Text(option),
                                      value: option,
                                      groupValue: groupValue,
                                      onChanged: (value) {
                                        groupValue = value ?? widget.options.firstOrNull ?? "";
                                        setState(() {});
                                      },
                                    )
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                  style:
                                  TextButton.styleFrom(backgroundColor: Theme
                                      .of(context)
                                      .colorScheme
                                      .primaryContainer),
                                  onPressed: () async {
                                    await prefs.setString(widget.setting, groupValue);
                                    Navigator.of(context).pop();
                                    if (widget.callback != null) {
                                      widget.callback!(groupValue);
                                    }
                                  },
                                  child: const Text("Bestätigen")),
                              TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text("Abbrechen"))
                            ],
                          ));
                }).then((value) => setState(() {})));
  }
}

class MultiSelectionSetting extends StatefulWidget {
  const MultiSelectionSetting({super.key,
    required this.setting,
    this.fallbackIndices = const [],
    required this.title,
    this.subtitle,
    required this.icon,
    required this.options,
    this.callback});

  final String setting;
  final String title;
  final String? subtitle;
  final List<String> options;
  final IconData icon;
  final List<int> fallbackIndices;
  final Function(List<int> indices)? callback;

  static List<int> settingStringToList(String? str, List<int> fallback) {
    Object? jsonDecodedObject = str != null ? jsonDecode(str) : null;
    List<int> selectedIndices = List.empty(growable: true);
    if (jsonDecodedObject != null && jsonDecodedObject is List && jsonDecodedObject.isNotEmpty) {
      try {
        selectedIndices = List<int>.from(jsonDecodedObject);
      } catch (e) {
        selectedIndices = List<int>.from(fallback);
      }
    } else {
      selectedIndices = List<int>.from(fallback);
    }
    return selectedIndices;
  }

  @override
  State<MultiSelectionSetting> createState() => _MultiSelectionSettingState();
}

class _MultiSelectionSettingState extends State<MultiSelectionSetting> {
  late SharedPreferences prefs;
  bool initialized = false;

  @override
  void initState() {
    asyncInitState();
    super.initState();
  }

  void asyncInitState() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const ListTile(title: CupertinoActivityIndicator());
    String? savedIndicesString = prefs.getString(widget.setting);
    List<int> selectedIndices = MultiSelectionSetting.settingStringToList(savedIndicesString, widget.fallbackIndices);
    return ListTile(
        title: Text(widget.title),
        subtitle: Text(selectedIndices.map((e) => widget.options[e]).join(", ")),
        leading: Icon(widget.icon),
        onTap: () =>
            showDialog(
                context: context,
                builder: (context) {
                  var tempIndices = selectedIndices;
                  return StatefulBuilder(
                      builder: (context, setState) =>
                          AlertDialog(
                            icon: Icon(widget.icon),
                            title: Text(widget.title),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.subtitle != null && widget.subtitle!.isNotEmpty) Text(widget.subtitle!),
                                  const SizedBox(height: 16),
                                  for (final (index, option) in widget.options.indexed)
                                    SwitchListTile(
                                      title: Text(option),
                                      value: tempIndices.contains(index),
                                      onChanged: (value) {
                                        if (value) {
                                          tempIndices.add(index);
                                        } else {
                                          tempIndices.remove(index);
                                        }
                                        setState(() {});
                                      },
                                    )
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                  style:
                                  TextButton.styleFrom(backgroundColor: Theme
                                      .of(context)
                                      .colorScheme
                                      .primaryContainer),
                                  onPressed: () async {
                                    tempIndices.sort();
                                    await prefs.setString(widget.setting, jsonEncode(tempIndices));
                                    Navigator.of(context).pop();
                                    if (widget.callback != null) {
                                      widget.callback!(tempIndices);
                                    }
                                  },
                                  child: const Text("Bestätigen")),
                              TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text("Abbrechen"))
                            ],
                          ));
                }).then((value) => setState(() {})));
  }
}

class AboutSettingsTile extends StatelessWidget {
  const AboutSettingsTile({super.key, this.title, this.subtitle, this.icon, this.extraText});

  final String? title;
  final String? subtitle;
  final IconData? icon;
  final String? extraText;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title ?? "Über"),
      subtitle: Text(subtitle ?? "App Informationen und Lizenzen"),
      leading: Icon(icon ?? Icons.info_outline),
      onTap: () async {
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        if (context.mounted) {
          showAboutDialog(
            context: context,
            applicationIcon: Image.asset("assets/icon/icon_transparent.png", height: 64, width: 64),
            applicationName: packageInfo.appName,
            applicationVersion: packageInfo.version,
            applicationLegalese: extraText,
          );
        }
      },
    );
  }
}

//
// class ColorPaletteSelectionTile extends StatefulWidget {
//   const ColorPaletteSelectionTile({super.key, required this.isar, required this.prefs});
//
//   final Isar isar;
//   final SharedPreferences prefs;
//
//   @override
//   State<ColorPaletteSelectionTile> createState() => _ColorPaletteSelectionTileState();
// }
//
// class _ColorPaletteSelectionTileState extends State<ColorPaletteSelectionTile> {
//   void showEditColorDialog(
//       bool fromSeed, String name, Color primary, Color secondary, Color tertiary, Color error, Function(bool, String, Color, Color, Color, Color) onConfirm,
//       [VoidCallback? onDelete]) {
//     int editingIndex = 0;
//     List<Color> colors = fromSeed
//         ? <ColorScheme>[
//       ColorScheme.fromSeed(
//         seedColor: primary,
//       )
//     ].map((e) => [primary, e.secondary, e.tertiary, e.error]).expand((element) => element).toList()
//         : [primary, secondary, tertiary, error];
//     showDialog(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             ColorScheme colorScheme = fromSeed
//                 ? ColorScheme.fromSeed(
//               seedColor: primary,
//               brightness: Theme.of(context).colorScheme.brightness,
//             )
//                 : SeedColorScheme.fromSeeds(
//               primaryKey: colors[0],
//               secondaryKey: colors[1],
//               tertiaryKey: colors[2],
//               errorKey: colors[3],
//               brightness: Theme.of(context).colorScheme.brightness,
//             );
//             return Theme(
//               data: Theme.of(context).copyWith(
//                 colorScheme: colorScheme,
//               ),
//               child: AlertDialog(
//                 title: const Text("Farben bearbeiten"),
//                 content: SingleChildScrollView(
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         SizedBox(
//                           height: 128,
//                           width: 128,
//                           child: Stack(
//                             children: [
//                               ClipRRect(
//                                 borderRadius: BorderRadius.circular(8),
//                                 child: Container(
//                                   height: 128,
//                                   width: 128,
//                                   decoration: BoxDecoration(
//                                     borderRadius: BorderRadius.circular(4),
//                                   ),
//                                   child: GridView.count(
//                                     crossAxisCount: 2,
//                                     children: [
//                                       for (final (index, color) in (fromSeed
//                                           ? <ColorScheme>[
//                                         ColorScheme.fromSeed(
//                                           seedColor: colors[0],
//                                         )
//                                       ].map((e) => [e.primary, e.secondary, e.tertiary, e.error]).expand((element) => element).toList()
//                                           : colors)
//                                           .indexed)
//                                         GestureDetector(
//                                             onTap: () {
//                                               editingIndex = index;
//                                               setState(() {});
//                                             },
//                                             child: Container(color: color)),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                               AnimatedAlign(
//                                 duration: const Duration(milliseconds: 200),
//                                 curve: Curves.easeInOut,
//                                 alignment: [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight][editingIndex],
//                                 child: AnimatedContainer(
//                                   duration: const Duration(milliseconds: 200),
//                                   curve: Curves.easeInOut,
//                                   height: fromSeed ? 128 : 64,
//                                   width: fromSeed ? 128 : 64,
//                                   decoration: BoxDecoration(
//                                     borderRadius: fromSeed
//                                         ? BorderRadius.circular(8)
//                                         : BorderRadius.only(
//                                       topLeft: editingIndex == 0 ? const Radius.circular(8) : const Radius.circular(0),
//                                       topRight: editingIndex == 1 ? const Radius.circular(8) : const Radius.circular(0),
//                                       bottomLeft: editingIndex == 2 ? const Radius.circular(8) : const Radius.circular(0),
//                                       bottomRight: editingIndex == 3 ? const Radius.circular(8) : const Radius.circular(0),
//                                     ),
//                                     border: Border.all(color: Theme.of(context).colorScheme.inverseSurface, width: 2),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         TextField(
//                           controller: TextEditingController(text: name),
//                           decoration: const InputDecoration(
//                             labelText: "Name",
//                           ),
//                           onChanged: (value) => name = value,
//                         ),
//                         const SizedBox(height: 16),
//                         Row(
//                           children: [
//                             const Expanded(child: Text("Anhand einer einzelnen Farbe generieren")),
//                             Switch(
//                               value: fromSeed,
//                               onChanged: (value) => setState(() {
//                                 fromSeed = value;
//                                 if (fromSeed) {
//                                   colors = <ColorScheme>[
//                                     ColorScheme.fromSeed(
//                                       seedColor: colors[0],
//                                     )
//                                   ].map((e) => [colors[0], e.secondary, e.tertiary, e.error]).expand((element) => element).toList();
//                                 }
//                               }),
//                             ),
//                           ],
//                         ),
//                         ColorPicker(
//                           color: fromSeed ? colors[0] : colors[editingIndex],
//                           onColorChanged: (value) {
//                             setState(() {
//                               if (fromSeed) {
//                                 colors[0] = value;
//                                 ColorScheme scheme = SeedColorScheme.fromSeeds(primaryKey: value);
//                                 colors = [colors[0], scheme.secondary, scheme.tertiary, scheme.error];
//                               } else {
//                                 colors[editingIndex] = value;
//                               }
//                             });
//                           },
//                           pickersEnabled: const {
//                             ColorPickerType.primary: true,
//                             ColorPickerType.accent: false,
//                           },
//                           enableShadesSelection: !fromSeed,
//                         )
//                       ],
//                     )),
//                 actions: [
//                   TextButton(
//                       style: TextButton.styleFrom(backgroundColor: colorScheme.primaryContainer),
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                         onConfirm(fromSeed, name, colors[0], colors[1], colors[2], colors[3]);
//                       },
//                       child: const Text("Bestätigen")),
//                   TextButton(
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                       },
//                       child: const Text("Abbrechen")),
//                   if (onDelete != null)
//                     TextButton(
//                         style: TextButton.styleFrom(backgroundColor: colorScheme.errorContainer),
//                         onPressed: () {
//                           Navigator.of(context).pop();
//                           onDelete();
//                         },
//                         child: Text("Löschen", style: TextStyle(color: colorScheme.error))),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return DynamicColorBuilder(
//       builder: (lightDynamic, darkDynamic) {
//         ColorScheme defaultColorScheme = ColorScheme.fromSeed(
//           seedColor: Colors.teal,
//         );
//
//         List<(ColorScheme, String, bool)> colorSchemes = [
//           (defaultColorScheme, "Default", false),
//           if (lightDynamic != null) (lightDynamic.harmonized(), "System", false),
//           ...widget.isar.colorPalettes
//               .where()
//               .findAllSync()
//               .map((e) => (e.toColorScheme(), (e.name == null || e.name!.isEmpty) ? "Unbenannt" : e.name!, e.fromSeed)),
//         ];
//
//         int selectedColorScheme = widget.prefs.getInt("colorSchemeIndex") ?? (colorSchemes.length > 1 ? 1 : 0);
//
//         return Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             //eventuell visualisierung einfügen
//             SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: Padding(
//                 padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     for (var (index, (ColorScheme colorScheme, String name, bool fromSeed)) in colorSchemes.indexed)
//                       Column(
//                         children: [
//                           GestureDetector(
//                             onTap: () async {
//                               await widget.prefs.setInt("colorSchemeIndex", index);
//                               if (context.mounted) ColorChangedNotification().dispatch(context);
//                               setState(() {});
//                             },
//                             onLongPress: index >= (lightDynamic != null ? 2 : 1)
//                                 ? () async {
//                               showEditColorDialog(
//                                 fromSeed,
//                                 name,
//                                 colorScheme.primary,
//                                 colorScheme.secondary,
//                                 colorScheme.tertiary,
//                                 colorScheme.error,
//                                     (fromSeed, name, primary, secondary, tertiary, error) async {
//                                   await widget.isar.writeTxn(() async {
//                                     await widget.isar.colorPalettes
//                                         .put((await widget.isar.colorPalettes.where().findAll())[index - (lightDynamic != null ? 2 : 1)]
//                                       ..fromSeed = fromSeed
//                                       ..name = name
//                                       ..primaryR = primary.red
//                                       ..primaryG = primary.green
//                                       ..primaryB = primary.blue
//                                       ..secondaryR = secondary.red
//                                       ..secondaryG = secondary.green
//                                       ..secondaryB = secondary.blue
//                                       ..tertiaryR = tertiary.red
//                                       ..tertiaryG = tertiary.green
//                                       ..tertiaryB = tertiary.blue
//                                       ..errorR = error.red
//                                       ..errorG = error.green
//                                       ..errorB = error.blue);
//                                   });
//                                   await widget.prefs.setInt("colorSchemeIndex", index);
//                                   if (context.mounted) ColorChangedNotification().dispatch(context);
//                                   setState(() {});
//                                 },
//                                     () async {
//                                   await widget.isar.writeTxn(() async {
//                                     await widget.isar.colorPalettes
//                                         .delete((await widget.isar.colorPalettes.where().findAll())[index - (lightDynamic != null ? 2 : 1)].id);
//                                   });
//                                   await widget.prefs.setInt("colorSchemeIndex", 0);
//                                   if (context.mounted) ColorChangedNotification().dispatch(context);
//                                   setState(() {});
//                                 },
//                               );
//                             }
//                                 : null,
//                             child: AnimatedContainer(
//                                 height: 64,
//                                 width: 64,
//                                 duration: const Duration(milliseconds: 500),
//                                 curve: Curves.easeInOut,
//                                 margin: const EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   borderRadius: BorderRadius.circular(4),
//                                   color: colorScheme.primaryContainer,
//                                 ),
//                                 padding: EdgeInsets.all(selectedColorScheme == index ? 2 : 0),
//                                 child: ClipRRect(
//                                   borderRadius: BorderRadius.circular(4),
//                                   child: GridView.count(
//                                     crossAxisCount: 2,
//                                     children: [
//                                       Container(color: colorScheme.primary),
//                                       Container(color: colorScheme.secondary),
//                                       Container(color: colorScheme.tertiary),
//                                       Container(color: colorScheme.error),
//                                     ],
//                                   ),
//                                 )),
//                           ),
//                           Text(name, style: TextStyle(color: index == selectedColorScheme ? Theme.of(context).colorScheme.primary : null)),
//                         ],
//                       ),
//                     GestureDetector(
//                       onTap: () async {
//                         showEditColorDialog(
//                           true,
//                           "",
//                           Theme.of(context).colorScheme.primary,
//                           Theme.of(context).colorScheme.secondary,
//                           Theme.of(context).colorScheme.tertiary,
//                           Theme.of(context).colorScheme.error,
//                               (fromSeed, name, primary, secondary, tertiary, error) async {
//                             await widget.isar.writeTxn(() async {
//                               await widget.isar.colorPalettes.put(ColorPalette()
//                                 ..fromSeed = fromSeed
//                                 ..name = name
//                                 ..primaryR = primary.red
//                                 ..primaryG = primary.green
//                                 ..primaryB = primary.blue
//                                 ..secondaryR = secondary.red
//                                 ..secondaryG = secondary.green
//                                 ..secondaryB = secondary.blue
//                                 ..tertiaryR = tertiary.red
//                                 ..tertiaryG = tertiary.green
//                                 ..tertiaryB = tertiary.blue
//                                 ..errorR = error.red
//                                 ..errorG = error.green
//                                 ..errorB = error.blue);
//                             });
//                             await widget.prefs.setInt("colorSchemeIndex", colorSchemes.length);
//                             if (context.mounted) ColorChangedNotification().dispatch(context);
//                             setState(() {});
//                           },
//                         );
//                       },
//                       child: Container(
//                           height: 64,
//                           width: 64,
//                           margin: const EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(4),
//                             color: Theme.of(context).colorScheme.surfaceVariant,
//                           ),
//                           alignment: Alignment.center,
//                           child: const Icon(Icons.add)),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
//
