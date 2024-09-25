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
  bool? mediaPlaying;
  final mediaPlayer = AudioPlayer();
  final musicPlayer = AudioPlayer(); //TODO
  late Directory appSupportDir;

  @override
  void initState() {
    () async {
      prefs = await SharedPreferences.getInstance();
      appSupportDir = await getApplicationSupportDirectory();
      setState(() {
        initialized = true;
      });
    }();
    super.initState();
  }

  @override
  void dispose() {
    mediaPlayer.dispose();
    musicPlayer.dispose();
    super.dispose();
  }

  StreamSubscription? buzzeredSubscription;

  void playSound(int teamIndex) async {
    String sessionId = prefs.getString("currentSession") ?? "";
    final Directory appSupportDir = await getApplicationSupportDirectory();
    final File file = File('${appSupportDir.path}/$sessionId/team_sound$teamIndex');

    final player = AudioPlayer();
    if (await file.exists()) {
      await player.play(DeviceFileSource(file.path));
    } else {
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
          color: Theme.of(context).colorScheme.surfaceContainer,
        ),
      ),
      //fullscreen
      if (Platform.isMacOS || Platform.isWindows)
        IconButton(
          onPressed: () {
            setState(() {
              fullscreen = !fullscreen;
              WindowManager.instance.setFullScreen(fullscreen);
            });
          },
          icon: Icon(
            fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
            color: Theme.of(context).colorScheme.surfaceContainer,
          ),
        ),
      IconButton(
        onPressed: () {
          setState(() {});
          //TODO open in new window
        },
        icon: Icon(
          Icons.open_in_new,
          color: Theme.of(context).colorScheme.surfaceContainer,
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

    Size screenSize = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          GameStreamBuilder(
              key: Key(currentGame),
              gameId: currentGame,
              fallback: SessionStreamBuilder(
                  session: prefs.getString("currentSession"),
                  builder: (teamsList, pointsList, selectedFieldData, state,playing, buzzeredTeam, playedFieldsList, revealed,
                      buzzerSensitivityMap, buzzerTeamMap, gameRef, sessionRef) {
                    if (currentGame != (gameRef?.id ?? "noGame")) {
                      Future.delayed(
                          const Duration(milliseconds: 200),
                          () => setState(() {
                                currentGame = gameRef?.id ?? "noGame";
                              }));
                    }
                    return fallbackWidget;
                  },
                fallback: fallbackWidget,
              ),
              builder: (categories, gameQuestionPoints, questions, emptyFields) {
                return SessionStreamBuilder(
                  session: prefs.getString("currentSession"),
                  builder: (teamsList, pointsList, selectedFieldData, state, playing, buzzeredTeam, playedFieldsList, revealed,
                      buzzerSensitivityMap, buzzerTeamMap, gameRef, sessionRef) {
                    if (currentGame != (gameRef?.id ?? "noGame")) {
                      Future.delayed(
                          const Duration(milliseconds: 200),
                          () => setState(() {
                                currentGame = gameRef?.id ?? "noGame";
                              }));
                    }
                    if(gameRef == null) return fallbackWidget;
                    if(mediaPlaying != playing){
                      if(playing == null) mediaPlayer.stop();
                      else if(playing && mediaPlaying == null) mediaPlayer.play(DeviceFileSource("${appSupportDir.path}/${gameRef.id}/${questions[selectedFieldData.$1][selectedFieldData.$2][music]}"));
                      else if(playing) mediaPlayer.resume();
                      else mediaPlayer.pause();
                      mediaPlaying = playing;
                    }

                    buzzeredSubscription?.cancel();
                    if ((state == HomePageState.question || state == HomePageState.buzzerTest) && questions[selectedFieldData.$1][selectedFieldData.$2][type] != QuestionType.noBuzzer.name &&
                        SerialConnection().status == SerialStatus.connected) {
                      buzzeredSubscription = SerialConnection().buzzerPressed.listen(
                        (event) {
                          int teamIndex = buzzerTeamMap[event] ?? -1;
                          if (state == HomePageState.question) {
                            FirebaseFirestore.instance
                                .collection(sessions)
                                .doc(prefs.getString("currentSession"))
                                .update({
                              buzzeredFrom: teamIndex,
                              currentState: HomePageState.questionBuzzered.name,
                              playingFrom: false
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

                    int estimatedRows =
                        (teamsList.length / ((screenSize.width - 64) ~/ (screenSize.height * 0.2 + 8))).ceil();
                    double playFieldHeight;
                    double playFieldWidth;
                    switch (state) {
                      case HomePageState.buzzerTest:
                      case HomePageState.overview:
                        playFieldHeight = screenSize.height - (screenSize.height * 0.12 + 8) * estimatedRows;
                        playFieldWidth = screenSize.width;
                        break;
                      case HomePageState.question:
                      case HomePageState.questionBuzzered:
                        double questionfactor = 0.1;
                        questionfactor += 0.12 * estimatedRows; //Punktestände
                        if (questions[selectedFieldData.$1][selectedFieldData.$2][image] != null &&
                            questions[selectedFieldData.$1][selectedFieldData.$2][image]!.isNotEmpty) {
                          questionfactor += 0.4;
                        }
                        // else if (questions[selectedFieldData.$1][selectedFieldData.$2][music] != null &&
                        //     questions[selectedFieldData.$1][selectedFieldData.$2][music]!.isNotEmpty) {
                        //   questionfactor += 0.2;
                        // }
                        if (questions[selectedFieldData.$1][selectedFieldData.$2][type] ==
                            QuestionType.progressingReveal.name) {
                          List<String> informationStrings = List<String>.from(
                              questions[selectedFieldData.$1][selectedFieldData.$2][information] ?? []);
                          var root = sqrt(informationStrings.length);
                          int columns = root < 4 ? root.ceil() : root.floor();
                          int rows = (informationStrings.length / columns).ceil();
                          questionfactor += 0.08 * rows;
                        } else if (questions[selectedFieldData.$1][selectedFieldData.$2][type] ==
                            QuestionType.abcd.name) {
                          questionfactor += 0.16;
                        }
                        playFieldHeight =
                            screenSize.height - (estimatedRows + 1) * 8 - screenSize.height * questionfactor;
                        playFieldHeight = max(playFieldHeight, screenSize.height * 0.25);
                        playFieldWidth = playFieldHeight / 9 * 16;
                    }

                    return Stack(
                      children: [
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: CustomPaint(
                            size: Size(playFieldWidth, playFieldHeight),
                            painter: PlayingFieldPainter(
                              categories: categories,
                              pointRings: gameQuestionPoints,
                              disabledFields: playedFieldsList..addAll(emptyFields),
                              colorScheme: Theme.of(context).colorScheme,
                              highlightedField: selectedFieldData,
                            ),
                          ),
                        ),
                        Align(
                            alignment: Alignment.topRight,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: options,
                            )),
                        Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            //Punktestände
                            SizedBox(
                              width: screenSize.width,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  children: [
                                    for (var (index, team) in teamsList.indexed)
                                      SizedBox(
                                        width: screenSize.height * 0.2,
                                        height: screenSize.height * 0.12,
                                        child: Card(
                                          color: ((state == HomePageState.questionBuzzered ||
                                                      state == HomePageState.buzzerTest) &&
                                                  buzzeredTeam == index)
                                              ? Theme.of(context).colorScheme.primaryContainer
                                              : null,
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  team,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.clip,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(fontSize: screenSize.height * 0.02),
                                                ),
                                                Text(
                                                  (pointsList.elementAtOrNull(index) ?? 0).toString(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineSmall
                                                      ?.copyWith(fontSize: screenSize.height * 0.04),
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
                            if (state != HomePageState.buzzerTest)
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  if ((state == HomePageState.question || state == HomePageState.questionBuzzered) &&
                                      selectedFieldData.$1 != -1)
                                    QuestionDisplay(
                                      gameId: gameRef.id,
                                      questionData: questions[selectedFieldData.$1][selectedFieldData.$2],
                                      reveal: revealed,
                                      appSupportDir: appSupportDir,
                                    ),
                                ],
                              )
                          ],
                        ),
                      ],
                    );
                  },
                  fallback: fallbackWidget,
                );
              }),
          const Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: BuzzerStatusIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}
