import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';
import 'package:quiz_show/widgets/buzzer_status.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/constants.dart';
import 'package:quiz_show/pages/settings.dart';
import 'package:quiz_show/serial_connection.dart';

import '../database/game_stream.dart';
import '../widgets/playing_field.dart';
import '../database/session_stream.dart';
import '../widgets/question.dart';

class HomeDisplayPage extends StatefulWidget {
  const HomeDisplayPage({super.key});

  @override
  State<HomeDisplayPage> createState() => _HomeDisplayPageState();
}

class _HomeDisplayPageState extends State<HomeDisplayPage> {
  late SharedPreferences prefs;
  bool initialized = false;
  bool fullscreen = false;
  String currentGame = "";

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
  void dispose() {
    super.dispose();
  }

  StreamSubscription? buzzeredSubscription;

  void playSound(int teamIndex) async {
    String sessionId = prefs.getString("currentSession") ?? "";
    final Directory appSupportDir = await getApplicationSupportDirectory();
    final File file = File('${appSupportDir.path}/$sessionId/team_sound$teamIndex');

    final player = AudioPlayer();
    if(await file.exists()) {
      await player.play(DeviceFileSource(file.path));
    }
    else{
      await player.play(AssetSource("buzzer.mp3"));
    }
    await player.onPlayerComplete.first;
    await player.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const CupertinoActivityIndicator();

    List<Widget> options = [
      IconButton(
        onPressed: () => openSettings(context).then((_) => setState(() {})),
        icon: Icon(
          Icons.settings_rounded,
          color: Theme
              .of(context)
              .colorScheme
              .surfaceContainer,
        ),
      ),
      //fullscreen
      IconButton(
        onPressed: () {
          setState(() {
            fullscreen = !fullscreen;
            WindowManager.instance.setFullScreen(fullscreen);
          });
        },
        icon: Icon(
          fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
          color: Theme
              .of(context)
              .colorScheme
              .surfaceContainer,
        ),
      ),
      IconButton(
        onPressed: () {
          setState(() {});
          //TODO open in new window
        },
        icon: Icon(
          Icons.open_in_new,
          color: Theme
              .of(context)
              .colorScheme
              .surfaceContainer,
        ),
      ),
    ];

    Widget fallbackWidget = Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Center(
            child: CupertinoActivityIndicator(),
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: options)
      ],
    );

    return Scaffold(
      body: Stack(
        children: [
          const Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: BuzzerStatusIndicator(),
            ),
          ),
          GameStreamBuilder(
            key: Key(currentGame),
              gameId: currentGame,
              fallback: SessionStreamBuilder(
                  session: prefs.getString("currentSession"),
                  builder: (teamsList, pointsList, selectedFieldData, state, buzzeredTeam, playedFieldsList, revealed,
                      buzzerSensitivityMap, buzzerTeamMap, gameRef, sessionRef) {
                    if (currentGame != gameRef.id) {
                      Future.delayed(const Duration(milliseconds: 200), () =>
                          setState(() {
                            currentGame = gameRef.id;
                          }));
                    }
                    return fallbackWidget;
                  }),
              builder: (categories, gameQuestionPoints, questions, emptyFields) {
                return SessionStreamBuilder(
                  session: prefs.getString("currentSession"),
                  builder: (teamsList, pointsList, selectedFieldData, state, buzzeredTeam, playedFieldsList, revealed,
                      buzzerSensitivityMap, buzzerTeamMap, gameRef, sessionRef) {
                    if (currentGame != gameRef.id) {
                      Future.delayed(const Duration(milliseconds: 200), () =>
                          setState(() {currentGame = gameRef.id;}));
                    }

                    buzzeredSubscription?.cancel();
                    if ((state == HomePageState.question || state == HomePageState.buzzerTest) && SerialConnection().status == SerialStatus.connected) {
                      buzzeredSubscription = SerialConnection().buzzerPressed.listen(
                            (event) {
                          int teamIndex = buzzerTeamMap[event] ?? -1;
                          if (state == HomePageState.question) {
                            FirebaseFirestore.instance.collection(sessions).doc(prefs.getString("currentSession")).update({
                              buzzeredFrom: teamIndex,
                              currentState: HomePageState.questionBuzzered.name,
                            });
                            //TODO check if it would be lower latency when [buzzerTeam] set manually
                            playSound(teamIndex);
                          } else if (state == HomePageState.buzzerTest) {
                            setState(() {
                              buzzeredTeam = teamIndex;
                            });
                            playSound(teamIndex);
                          }
                        },
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            const SizedBox(width: 32),
                            Expanded(
                              child: Center(
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    for (var (index, team) in teamsList.indexed)
                                      Card(
                                        color: ((state == HomePageState.questionBuzzered ||
                                            state == HomePageState.buzzerTest) &&
                                            buzzeredTeam == index)
                                            ? Theme
                                            .of(context)
                                            .colorScheme
                                            .primaryContainer
                                            : null,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: SizedBox(
                                            width: 200,
                                            child: Column(
                                              children: [
                                                Text(
                                                  team,
                                                  style: Theme
                                                      .of(context)
                                                      .textTheme
                                                      .bodySmall,
                                                ),
                                                Text(
                                                  (pointsList.elementAtOrNull(index) ?? 0).toString(),
                                                  style: Theme
                                                      .of(context)
                                                      .textTheme
                                                      .headlineSmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: options,
                            )
                          ],
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        if (state != HomePageState.buzzerTest)
                          Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              if (state == HomePageState.question || state == HomePageState.questionBuzzered)
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxHeight: MediaQuery
                                      .of(context)
                                      .size
                                      .height * 0.25),
                                  child: QuestionDisplay(
                                      questionData: questions[selectedFieldData.$1][selectedFieldData.$2], reveal: revealed,),
                                ),
                              SizedBox(
                                height: MediaQuery
                                    .of(context)
                                    .size
                                    .height * (state == HomePageState.overview ? 1 : 0.75) -
                                    136, //TODO
                                child: CustomPaint(
                                  size: Size(MediaQuery
                                      .of(context)
                                      .size
                                      .width,
                                      MediaQuery
                                          .of(context)
                                          .size
                                          .height * (state == HomePageState.overview ? 1 : 0.75) - 136),
                                  painter: PlayingFieldPainter(
                                    categories: categories,
                                    pointRings: gameQuestionPoints,
                                    disabledFields: playedFieldsList..addAll(emptyFields),
                                    colorScheme: Theme
                                        .of(context)
                                        .colorScheme,
                                    highlightedField: selectedFieldData,
                                  ),
                                ),
                              ),
                            ],
                          )
                      ],
                    );
                  },
                  fallback: fallbackWidget,
                );
              }
          ),
        ],
      ),
    );
  }
}