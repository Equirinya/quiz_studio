import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import '../database/constants.dart';
import '../serial_connection.dart';
import 'settings.dart';

class BuzzerConnectionPage extends StatefulWidget {
  const BuzzerConnectionPage({super.key});

  @override
  State<BuzzerConnectionPage> createState() => _BuzzerConnectionPageState();
}

class _BuzzerConnectionPageState extends State<BuzzerConnectionPage> {
  @override
  Widget build(BuildContext context) {
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
              constraints: BoxConstraints(
                  minWidth: MediaQuery
                      .of(context)
                      .size
                      .width - 16, minHeight: 100, maxHeight: 200),
              child: Card(
                color: Color.lerp(Theme
                    .of(context)
                    .colorScheme
                    .surface, Colors.black, 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Builder(builder: (context) {
                    List<String> lines = List.empty(growable: true);
                    if(SerialConnection().status == SerialStatus.notConfigured){
                      return const Text("Serial port not configured");
                    }
                    if(SerialConnection().status == SerialStatus.disconnected){
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
          Builder(
            builder: (context) {
              Map<String, List<int>> inputs = {};
              return FutureBuilder(
                future: SerialConnection().serialStream.first,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                    Map<String, int> newData = Map.fromEntries(snapshot.data!.split(",").map((e) {
                      List<String> parts = e.split(":");
                      return MapEntry(parts[0], int.tryParse(parts[1]) ?? 0);
                    }));
                    for (final entry in newData.entries) {
                      if (!inputs.containsKey(entry.key)) inputs[entry.key] = [];
                      inputs[entry.key]?.add(entry.value);
                    }
                  }
                  return Column(
                    children: [
                      for (final entry in inputs.entries)
                        ListTile(
                          title: Text(entry.key),
                          subtitle: Text(entry.value.last.toString()),
                          trailing: SizedBox(
                            height: 20,
                            width: MediaQuery
                                .of(context)
                                .size
                                .width * 0.5,
                            child: StreamBuilder(
                              //TODO swap stream builders
                              stream: FirebaseFirestore.instance
                                  .collection(sessions)
                                  .doc(prefs.getString("currentSession"))
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  List<String> teamsList =
                                  (snapshot.data!.data() != null && snapshot.data!.data()![teams] != null)
                                      ? List.from(snapshot.data!.data()![teams])
                                      : List.empty();
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Slider(
                                          value: (snapshot.data!
                                              .data()?[buzzerSensitivity]
                                              ?.containsKey(entry.key) ??
                                              false)
                                              ? snapshot.data!.data()![buzzerSensitivity][entry.key].toDouble()
                                              : 0,
                                          min: 0,
                                          max: 1023,
                                          onChanged: (value) {
                                            FirebaseFirestore.instance
                                                .collection(sessions)
                                                .doc(prefs.getString("currentSession"))
                                                .update({"$buzzerSensitivity.${entry.key}": value.round()});
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                      Text(snapshot.data!.data()?[buzzerSensitivity]?.containsKey(entry.key) ??
                                          false
                                          ? snapshot.data!.data()![buzzerSensitivity][entry.key].toString()
                                          : "0"),
                                      DropdownMenu<String>(
                                          dropdownMenuEntries: teamsList
                                              .map((e) => DropdownMenuEntry(label: e, value: e))
                                              .toList(),
                                          initialSelection: snapshot.data!.data()?[buzzerTeam]?.containsKey(
                                              entry.key) ?? false ? teamsList[snapshot.data!
                                              .data()![buzzerTeam][entry.key]]
                                              : teamsList.firstOrNull,
                                          onSelected: (value) {
                                            FirebaseFirestore.instance
                                                .collection(sessions)
                                                .doc(prefs.getString("currentSession"))
                                                .update({"$buzzerTeam.${entry.key}": teamsList.indexOf(value ??
                                                "")});
                                            setState(() {});
                                          }),
                                      TextButton(onPressed: () => selectSound(int.parse(entry.key), context),
                                          child: const Text("Select Sound"))
                                    ],
                                  );
                                } else {
                                  return const SizedBox();
                                }
                              },
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
