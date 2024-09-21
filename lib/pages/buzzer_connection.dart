import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/constants.dart';
import '../database/session_stream.dart';
import '../serial_connection.dart';
import 'settings.dart';

class BuzzerConnectionPage extends StatefulWidget {
  const BuzzerConnectionPage({super.key});

  @override
  State<BuzzerConnectionPage> createState() => _BuzzerConnectionPageState();
}

class _BuzzerConnectionPageState extends State<BuzzerConnectionPage> {
  late SharedPreferences prefs;
  bool initialized = false;
  Map<int, List<int>> inputs = {};

  @override
  void initState() {
    () async {
      prefs = await SharedPreferences.getInstance();
      setState(() {
        initialized = true;
      });
    }();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const CupertinoActivityIndicator();
    return ListView(
      children: [
        SettingsSubPageCategory(title: "Connection", settings: [
          StringSelectionSetting(
            setting: "serial_port",
            title: "Serial Port",
            icon: Icons.electrical_services,
            options: SerialPort.availablePorts,
            callback: (value) async {
              SerialConnection().createSerialStream();
              setState(() {});
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minWidth: MediaQuery.of(context).size.width - 16, minHeight: 100, maxHeight: 200),
              child: Card(
                color: Color.lerp(Theme.of(context).colorScheme.surface, Colors.black, 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Builder(builder: (context) {
                    List<String> lines = List.empty(growable: true);
                    if (SerialConnection().status == SerialStatus.notConfigured) {
                      return const Text("Serial port not configured");
                    }
                    if (SerialConnection().status == SerialStatus.disconnected) {
                      return const Text("Serial port disconnected");
                    }
                    return StreamBuilder(
                      stream: SerialConnection().serialStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          lines.add(snapshot.data!);
                        }
                        if (lines.isNotEmpty) {
                          return Text(lines.sublist(max(0, lines.length - 10)).join("\n"));
                        } else {
                          return const Text("No data");
                        }
                      },
                    );
                  }),
                ),
              ),
            ),
          )
        ]),
        SettingsSubPageCategory(title: "Sensitivity", settings: [
          SessionStreamBuilder(
            session: prefs.getString("currentSession"),
            builder: (teamsList, pointsList, selectedFieldData, state, buzzeredTeam, playedFieldsList, revealed,
                buzzerSensitivityMap, buzzerTeamMap, gameRef, sessionRef) {
              return FutureBuilder(
                future: SerialConnection().serialStream.first,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                    try {
                      Map<int, int> newData = Map.fromEntries(snapshot.data!.split(",").map((e) {
                        List<String> parts = e.split(":");
                        return MapEntry(int.tryParse(parts[0]) ?? -1, int.tryParse(parts[1]) ?? 0);
                      }));
                      for (final entry in newData.entries) {
                        if (!inputs.containsKey(entry.key)) inputs[entry.key] = [];
                        inputs[entry.key]?.add(entry.value);
                      }
                    } catch (e) {
                      return const Text("Error parsing data");
                    }
                  }
                  return Column(
                    children: [
                      for (final entry in inputs.entries)
                        ListTile(
                          title: Text(entry.key.toString()),
                          subtitle: Text(entry.value.last.toString()),
                          trailing: SizedBox(
                            height: 20,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatefulBuilder(builder: (context, setSliderState) {
                                  return Slider(
                                    value: buzzerSensitivityMap.containsKey(entry.key)
                                        ? buzzerSensitivityMap[entry.key]!.toDouble()
                                        : 0,
                                    min: 0,
                                    max: 1023,
                                    onChangeEnd: (value) {
                                      sessionRef.update({"$buzzerSensitivity.${entry.key}": value.round()});
                                    },
                                    onChanged: (double value) {
                                      setSliderState(() {
                                        buzzerSensitivityMap[entry.key] = value.round();
                                      });
                                    },
                                  );
                                }),
                                Text(buzzerSensitivityMap.containsKey(entry.key)
                                    ? buzzerSensitivityMap[entry.key]!.toString()
                                    : "0"),
                                const SizedBox(width: 24),
                                DropdownMenu<String>(
                                    dropdownMenuEntries:
                                        teamsList.map((e) => DropdownMenuEntry(label: e, value: e)).toList(),
                                    initialSelection: buzzerTeamMap.containsKey(entry.key)
                                        ? teamsList[buzzerTeamMap[entry.key]!]
                                        : teamsList.firstOrNull,
                                    onSelected: (value) {
                                      sessionRef.update({"$buzzerTeam.${entry.key}": teamsList.indexOf(value ?? "")});
                                    }),
                                const SizedBox(width: 24),
                                TextButton(
                                    onPressed: () => selectSound(entry.key, context), child: const Text("Select Sound"))
                              ],
                            ),
                          ),
                        )
                    ],
                  );
                },
              );
            },
          )
        ]),
      ],
    );
  }
}

void selectSound(int team, BuildContext context) async {
  String sessionId = await SharedPreferences.getInstance().then((value) => value.getString("currentSession") ?? "");
  final Directory appSupportDir = await getApplicationSupportDirectory();
  final File file = File('${appSupportDir.path}/$sessionId/team_sound$team');
  if(!await file.parent.exists()) await file.parent.create(recursive: true);
  InputDevice? selectedDevice;

  FirebaseFirestore db = FirebaseFirestore.instance;
  final storageRef = FirebaseStorage.instance.ref().child("session_$sessionId").child("team_sound$team");
  Stream<TaskSnapshot>? uploadMusicStream;
  bool? uploadRecordMusicSuccess;
  bool uploadRecordMusicLoading = false;
  bool? uploadFileMusicSuccess;
  bool uploadFileMusicLoading = false;

  await showDialog(
    context: context,
    builder: (context) {
      final record = AudioRecorder();
      bool recording = false;

      return AlertDialog(
        title: const Text("Select Sound"),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (file.existsSync())
                  ListTile(
                    title: const Text("Play Sound"),
                    leading: const Icon(Icons.play_arrow),
                    onTap: () async {
                      final player = AudioPlayer();
                      await player.play(DeviceFileSource(file.path));
                      await player.onPlayerComplete.first;
                      await player.dispose();
                    },
                  ),
                if (!recording)
                  ListTile(
                    title: const Text("Record Sound"),
                    leading: uploadRecordMusicLoading
                        ? const CupertinoActivityIndicator()
                        : Icon(uploadRecordMusicSuccess == null
                            ? Icons.record_voice_over
                            : uploadRecordMusicSuccess!
                                ? Icons.cloud_done
                                : Icons.cloud_off),
                    onTap: () async {
                      if (await record.hasPermission()) {
                        await record.start(RecordConfig(device: selectedDevice), path: "${file.path}.m4a");
                        setState(() {
                          recording = true;
                        });
                      }
                    },
                    trailing: FutureBuilder(
                      future: record.listInputDevices(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return DropdownMenu<InputDevice>(
                            dropdownMenuEntries:
                                snapshot.data!.map((e) => DropdownMenuEntry(label: e.label, value: e)).toList(),
                            initialSelection: selectedDevice,
                            onSelected: (value) {
                              selectedDevice = value;
                            },
                          );
                        } else {
                          return const CupertinoActivityIndicator();
                        }
                      },
                    ),
                  )
                else
                  ListTile(
                    title: const Text("Stop Recording"),
                    leading: const Icon(Icons.record_voice_over),
                    onTap: () async {
                      await record.stop();
                      setState(() {
                        recording = false;
                        uploadRecordMusicSuccess = null;
                        uploadRecordMusicLoading = true;
                      });
                      File("${file.path}.m4a").renameSync(file.path);
                      uploadMusicStream = storageRef.putFile(File(file.path)).snapshotEvents;
                      uploadMusicStream?.listen((event) {
                        switch (event.state) {
                          case TaskState.success:
                            setState(() {
                              uploadRecordMusicLoading = false;
                              uploadRecordMusicSuccess = true;
                            });
                            break;
                          case TaskState.error:
                            setState(() {
                              uploadRecordMusicLoading = false;
                              uploadRecordMusicSuccess = false;
                            });
                            break;
                          default:
                            break;
                        }
                      });
                    },
                  ),
                ListTile(
                  leading: uploadFileMusicLoading
                      ? const CupertinoActivityIndicator()
                      : Icon(uploadFileMusicSuccess == null
                          ? Icons.file_open
                          : uploadFileMusicSuccess!
                              ? Icons.cloud_done
                              : Icons.cloud_off),
                  title: const Text("Select File"),
                  onTap: () async {
                    final XFile? musicXFile = await openFile(
                        acceptedTypeGroups: <XTypeGroup>[Platform.isIOS ? musicUniformFileType : musicExtension]);
                    if (musicXFile == null) return;
                    setState(() {
                      uploadFileMusicSuccess = null;
                      uploadFileMusicLoading = true;
                    });
                    musicXFile.saveTo(file.path);
                    uploadMusicStream = storageRef.putFile(File(musicXFile.path)).snapshotEvents;
                    uploadMusicStream?.listen((event) {
                      switch (event.state) {
                        case TaskState.success:
                          setState(() {
                            uploadFileMusicLoading = false;
                            uploadFileMusicSuccess = true;
                          });
                          break;
                        case TaskState.error:
                          setState(() {
                            uploadFileMusicLoading = false;
                            uploadFileMusicSuccess = false;
                          });
                          break;
                        default:
                          break;
                      }
                    });
                  },
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
