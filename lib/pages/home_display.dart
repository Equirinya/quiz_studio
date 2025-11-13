import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';
import 'package:quiz_show/pages/games_display/playboard.dart';
import 'package:quiz_show/widgets/buzzer_status.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/constants.dart';
import 'package:quiz_show/pages/settings.dart';
import 'package:quiz_show/serial_connection.dart';

import '../database/game_stream.dart';
import '../question_types/abstract_question.dart';
import '../database/session_stream.dart';

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

  //TODO move mediaPlaying to BaseQuestionCard
  bool? mediaPlaying;
  final mediaPlayer = AudioPlayer();
  StreamSubscription? mediaPlayerComplete;
  final musicPlayer = AudioPlayer(); //TODO
  late Directory appSupportDir;

  StreamSubscription? buzzeredSubscription;
  StreamSubscription? buzzerHistorySubscription;

  @override
  void initState() {
    () async {
      prefs = await SharedPreferences.getInstance();
      appSupportDir = await getApplicationSupportDirectory();
      setState(() {
        initialized = true;
      });
    }();
    mediaPlayerComplete = mediaPlayer.onPlayerComplete.listen((event) {
      FirebaseFirestore.instance.collection(sessions).doc(prefs.getString("currentSession")).update({playingFrom: null});
    });
    super.initState();
  }

  @override
  void dispose() {
    buzzeredSubscription?.cancel();
    buzzerHistorySubscription?.cancel();
    mediaPlayer.dispose();
    mediaPlayerComplete?.cancel();
    musicPlayer.dispose();
    super.dispose();
  }

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
                builder: (Map<String, dynamic> sessionData, teamsList, pointsList, selectedFieldData, selectedCategoryGroupIndex, state, playing,
                    enableBuzzerQueue, buzzeredTeam, playedFieldsList, revealed, buzzerSensitivityMap, buzzerTeamMap, gameRef, sessionRef) {
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
              builder: (categories, questions) {
                return SessionStreamBuilder(
                  session: prefs.getString("currentSession"),
                  builder: (Map<String, dynamic> sessionData, teamsList, pointsList, selectedFieldData, selectedCategoryGroupIndex, state, playing,
                      enableBuzzerQueue, buzzeredTeam, playedFieldsList, revealed, buzzerSensitivityMap, buzzerTeamMap, gameRef, sessionRef) {
                    if (currentGame != (gameRef?.id ?? "noGame")) {
                      Future.delayed(
                          const Duration(milliseconds: 200),
                          () => setState(() {
                                currentGame = gameRef?.id ?? "noGame";
                              }));
                    }
                    if (gameRef == null) return fallbackWidget;

                    //map categoryGroup data
                    selectedCategoryGroupIndex = selectedCategoryGroupIndex.clamp(0, categories.length - 1);
                    var selectedCategoryType = categories[selectedCategoryGroupIndex].$1;
                    var selectedCategoryNames = categories[selectedCategoryGroupIndex].$2;
                    int categoryOffset =
                        categories.sublist(0, selectedCategoryGroupIndex).fold(0, (previousValue, element) => previousValue + element.$2.length);
                    //limit the arrays to the range of the category group:
                    var displayedQuestions = questions.sublist(categoryOffset, categoryOffset + selectedCategoryNames.length);
                    var displayedPlayedFieldsList = playedFieldsList
                        .where((element) => element.$1 >= categoryOffset && element.$1 < categoryOffset + selectedCategoryNames.length)
                        .map((e) => (e.$1 - categoryOffset, e.$2))
                        .toList();
                    var displayedSelectedFieldData = (selectedFieldData.$1 - categoryOffset, selectedFieldData.$2);

                    if (selectedFieldData.$1 == -1 ||
                        selectedFieldData.$1 > questions.length - 1 ||
                        selectedFieldData.$2 > questions[selectedFieldData.$1].length - 1) {
                      selectedFieldData = (-1, -1);
                      if (state == HomePageState.question || state == HomePageState.questionBuzzered) state = HomePageState.overview;
                    }

                    //execute all the game Logic, like buzzers, sound etc
                    gameLogic(
                        playing: playing,
                        gameRef: gameRef,
                        questions: questions,
                        selectedFieldData: selectedFieldData,
                        state: state,
                        buzzerTeamMap: buzzerTeamMap,
                        enableBuzzerQueue: enableBuzzerQueue,
                        sessionUpdate: FirebaseFirestore.instance.collection(sessions).doc(prefs.getString("currentSession")).update);

                    //calculate playingField Size
                    int estimatedScoreRows = (teamsList.length / ((screenSize.width - 64) ~/ (screenSize.height * 0.2 + 8))).ceil();
                    double playFieldHeight;
                    double playFieldWidth;
                    switch (state) {
                      case HomePageState.buzzerTest:
                      case HomePageState.overview:
                        playFieldHeight = screenSize.height - (screenSize.height * 0.12 + 8) * estimatedScoreRows;
                        playFieldWidth = screenSize.width;
                        break;
                      case HomePageState.question:
                      case HomePageState.questionBuzzered:
                        double questionHeight = Question.fromData(questions[selectedFieldData.$1][selectedFieldData.$2]).questionHeightPercentage();
                        playFieldHeight =
                            screenSize.height - (estimatedScoreRows + 1) * (screenSize.height * 0.12 + 8) - screenSize.height * questionHeight;
                        playFieldHeight = max(playFieldHeight, screenSize.height * 0.2);
                        playFieldWidth = playFieldHeight / 9 * 16;
                    }

                    Color? pointCardColor(int teamIndex) {
                      if (state == HomePageState.questionBuzzered || state == HomePageState.buzzerTest) {
                        if (buzzeredTeam.firstOrNull == teamIndex) return Theme.of(context).colorScheme.primaryContainer;
                        if (enableBuzzerQueue && buzzeredTeam.contains(teamIndex)) {
                          return Color.lerp(Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.surfaceContainerLow,
                              buzzeredTeam.indexOf(teamIndex) / buzzeredTeam.length);
                        }
                      }
                      return null;
                    }

                    return Stack(
                      children: [
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Playboard.fromCategoryType(
                            categoryType: selectedCategoryType,
                            homePageState: state,
                            size: Size(playFieldWidth, playFieldHeight),
                            categoryNames: selectedCategoryNames,
                            questionDocs: displayedQuestions,
                            selectedFieldData: displayedSelectedFieldData,
                            playedFieldsList: displayedPlayedFieldsList,
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
                                          color: pointCardColor(index),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  team,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.clip,
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: screenSize.height * 0.02),
                                                ),
                                                Text(
                                                  (pointsList.elementAtOrNull(index) ?? 0).toString(),
                                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: screenSize.height * 0.04),
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
                                  if ((state == HomePageState.question || state == HomePageState.questionBuzzered) && selectedFieldData.$1 != -1)
                                    Question.fromData(questions[selectedFieldData.$1][selectedFieldData.$2]).questionWidget(
                                        context: context,
                                        gameDir: Directory('${appSupportDir.absolute.path}/${gameRef.id}'),
                                        sessionData: sessionData)
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

  Future<void> gameLogic(
      {required bool? playing,
      required DocumentReference<Object?> gameRef,
      required List<List<Map<String, dynamic>>> questions,
      required (int, int) selectedFieldData,
      required HomePageState state,
      required Map<int, int> buzzerTeamMap,
      required bool enableBuzzerQueue,
      required Future<void> sessionUpdate(Map<Object, Object?> data)}) async {
    if (mediaPlaying != playing) {
      if (playing == null) {
        mediaPlayer.stop();
      } else if (playing && mediaPlaying == null) {
        mediaPlayer.play(DeviceFileSource("${appSupportDir.path}/${gameRef.id}/${questions[selectedFieldData.$1][selectedFieldData.$2][music]}"));
      } else if (playing)
        mediaPlayer.resume();
      else
        mediaPlayer.pause();
      mediaPlaying = playing;
    }

    buzzeredSubscription?.cancel();
    buzzerHistorySubscription?.cancel();
    if (SerialConnection().status == SerialStatus.connected) {
      bool questionBuzzerable = selectedFieldData.$1 >= 0 && Question.fromData(questions[selectedFieldData.$1][selectedFieldData.$2]).buzzerable();

      //listen to the buzzer if in buzzer test or an open question or a question already buzzered with buzzerqueue enabled
      if (state == HomePageState.buzzerTest ||
          (questionBuzzerable && (state == HomePageState.question || (state == HomePageState.questionBuzzered && enableBuzzerQueue)))) {
        buzzeredSubscription = SerialConnection().buzzerPressed.listen(
          (event) {
            int teamIndex = buzzerTeamMap[event] ?? -1;
            if (teamIndex == -1) return;
            if (state == HomePageState.question) {
              //TODO check if it would be lower latency when [buzzerTeam] set manually
              sessionUpdate({
                buzzeredFrom: [teamIndex],
                currentState: HomePageState.questionBuzzered.name,
                playingFrom: false
              });
              playSound(teamIndex);
            } else if (state == HomePageState.questionBuzzered && enableBuzzerQueue) {
              sessionUpdate({
                buzzeredFrom: FieldValue.arrayUnion([teamIndex]),
              });
              playSound(teamIndex);
            } else if (state == HomePageState.buzzerTest) {
              sessionUpdate({
                buzzeredFrom: [teamIndex],
              });
              playSound(teamIndex);
            }
          },
        );
      }
    }
  }
}
