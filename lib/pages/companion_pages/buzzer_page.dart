import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quiz_show/database/game_stream.dart';
import 'package:quiz_show/pages/home_display.dart';
import 'package:quiz_show/widgets/buzzer_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/database/constants.dart';
import '/database/session_stream.dart';
import '/question_types/abstract_question.dart';

class BuzzerPage extends StatefulWidget {
  const BuzzerPage({super.key, required this.sessionId, required this.teamIndex});

  final String sessionId;
  final int teamIndex;

  @override
  State<BuzzerPage> createState() => _BuzzerPageState();
}

class _BuzzerPageState extends State<BuzzerPage> {
  late Directory appSupportDir;
  bool initialized = false;

  @override
  void initState() {
    () async {
      appSupportDir = await getApplicationSupportDirectory();
      setState(() {
        initialized = true;
      });
    }();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const CupertinoActivityIndicator();
    return Scaffold(
      body: SessionStreamBuilder(
        key: ValueKey("buzzer_companion_${widget.sessionId}"),
        session: widget.sessionId,
        builder: (sessionData) {
          var sessionRef = sessionData.sessionRef;
          var teamsList = sessionData.teamsList;
          var pointsList = sessionData.pointsList;
          var selectedFieldData = sessionData.selectedFieldData;
          var state = sessionData.state;
          var gameRef = sessionData.gameRef;
          var buzzeredTeam = sessionData.buzzeredTeam;
          if (gameRef == null) return Center(child: Text("Couldn't load game"));
          return GameStreamBuilder(
            key: ValueKey("companion_${gameRef.id}"),
            gameId: gameRef.id,
            builder: (categories, questions) {
              if (questions.isEmpty) {
                return const SizedBox();
              } else {
                bool buzzerActive = HomePageState.buzzerTest == state || ([HomePageState.question, HomePageState.questionBuzzered].contains(state) &&
                    selectedFieldData.$1 >= 0 && Question.fromData(questions[selectedFieldData.$1][selectedFieldData.$2]).buzzerable());

                return Center(
                  child: BuzzerButton(
                    size: MediaQuery.of(context).size.shortestSide * 0.75,
                    onPressed: buzzerActive
                        ? () => buzzer(
                            teamIndex: widget.teamIndex,
                            questions: questions,
                            sessionData: sessionData,
                            sessionUpdate: (data) => sessionRef.update(data),
                            playSound: (teamIndex) async {
                              sessionRef.update({
                                playBuzzer: true,
                              });
                              final player = AudioPlayer();
                              await player.play(AssetSource("buzzer.mp3"));
                              await player.onPlayerComplete.first;
                              await player.dispose();
                            },
                          )
                        : null,
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
