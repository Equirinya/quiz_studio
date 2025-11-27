import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';
import 'package:quiz_show/pages/games_display/playboard.dart';
import 'package:quiz_show/widgets/buzzer_status.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/audio_controller.dart';
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
        icon: Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.surfaceContainer),
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
          icon: Icon(fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Theme.of(context).colorScheme.surfaceContainer),
        ),
      IconButton(
        onPressed: () {
          setState(() {});
          //TODO open in new window
        },
        icon: Icon(Icons.open_in_new, color: Theme.of(context).colorScheme.surfaceContainer),
      ),
    ];

    Widget fallbackWidget = Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(child: Center(child: CupertinoActivityIndicator())),
        Column(mainAxisSize: MainAxisSize.min, children: options),
      ],
    );

    Size screenSize = MediaQuery.of(context).size;
    return Material(
      child: Stack(
        children: [
          GameStreamBuilder(
            key: Key(currentGame),
            gameId: currentGame,
            fallback: SessionStreamBuilder(
              session: prefs.getString("currentSession"),
              builder: (sessionData) {
                if (currentGame != (sessionData.gameRef?.id ?? "noGame")) {
                  Future.delayed(
                    const Duration(milliseconds: 200),
                    () => setState(() {
                      currentGame = sessionData.gameRef?.id ?? "noGame";
                    }),
                  );
                }
                return fallbackWidget;
              },
              fallback: fallbackWidget,
            ),
            builder: (categories, questions) {
              return SessionStreamBuilder(
                session: prefs.getString("currentSession"),
                builder: (sessionData) {
                  if (currentGame != (sessionData.gameRef?.id ?? "noGame")) {
                    Future.delayed(
                      const Duration(milliseconds: 200),
                      () => setState(() {
                        currentGame = sessionData.gameRef?.id ?? "noGame";
                      }),
                    );
                  }
                  if (sessionData.gameRef == null) return fallbackWidget;

                  var state = sessionData.state;
                  var selectedFieldData = sessionData.selectedFieldData;

                  //map categoryGroup data
                  var selectedCategoryGroupIndex = sessionData.selectedCategoryGroupIndex.clamp(0, categories.length - 1);
                  CategoryGroupData? selectedCategoryGroupData = categories[selectedCategoryGroupIndex].$1;
                  CategoryGroupType selectedCategoryType = selectedCategoryGroupData?.type ?? CategoryGroupType.wheel;
                  List<String> selectedCategoryNames = categories[selectedCategoryGroupIndex].$2.map((e) => e.data()[name] as String).toList();
                  int categoryOffset = categories
                      .sublist(0, selectedCategoryGroupIndex)
                      .fold(0, (previousValue, element) => previousValue + element.$2.length);
                  //limit the arrays to the range of the category group:
                  var displayedQuestions = questions.sublist(categoryOffset, categoryOffset + selectedCategoryNames.length);
                  var displayedPlayedFieldsList = sessionData.playedFieldsList
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

                  //set Audio controller
                  AudioController audioController = AudioController();
                  audioController.setGameId(sessionData.gameRef!.id);
                  audioController.setSelectedCategoryGroupId(selectedCategoryGroupData?.id);
                  audioController.setSelectedCategoryId(displayedSelectedFieldData.$1 >= 0 && displayedSelectedFieldData.$1 < categories[selectedCategoryGroupIndex].$2.length ? categories[selectedCategoryGroupIndex].$2[displayedSelectedFieldData.$1].id : null);
                  audioController.setSelectedQuestionId(selectedFieldData.$1 >= 0 && selectedFieldData.$2 >= 0 ?questions[selectedFieldData.$1][selectedFieldData.$2][documentId] : null);
                  audioController.setFiles();

                  //execute all the game Logic, like buzzers, sound etc
                  gameLogic(
                    questions: questions,
                    sessionData: sessionData,
                    sessionUpdate: FirebaseFirestore.instance.collection(sessions).doc(prefs.getString("currentSession")).update,
                  );

                  //calculate playingField Size
                  int estimatedScoreRows = (sessionData.teamsList.length / ((screenSize.width - 64) ~/ (screenSize.height * 0.2 + 8))).ceil();
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
                    case HomePageState.answerRevealed:
                      double questionHeight = Question.fromData(questions[selectedFieldData.$1][selectedFieldData.$2]).questionHeightPercentage();
                      playFieldHeight =
                          screenSize.height - (estimatedScoreRows + 1) * (screenSize.height * 0.12 + 8) - screenSize.height * questionHeight;
                      playFieldHeight = max(playFieldHeight, screenSize.height * 0.2);
                      playFieldWidth = playFieldHeight / 9 * 16;
                  }

                  ColorScheme colorScheme = selectedCategoryGroupData?.color != null && selectedCategoryGroupData?.accentColor != null
                      ? SeedColorScheme.fromSeeds(
                          primaryKey: selectedCategoryGroupData!.color!,
                          tertiaryKey: selectedCategoryGroupData.accentColor!,
                          brightness: Theme.of(context).brightness,
                        )
                      : Theme.of(context).colorScheme;

                  Color? pointCardColor(int teamIndex) {
                    if (state == HomePageState.questionBuzzered || state == HomePageState.buzzerTest) {
                      if (sessionData.buzzeredTeam.firstOrNull == teamIndex) return colorScheme.primaryContainer;
                      if (sessionData.enableBuzzerQueue && sessionData.buzzeredTeam.contains(teamIndex)) {
                        return Color.lerp(
                          colorScheme.primaryContainer,
                          colorScheme.surfaceContainerLow,
                          sessionData.buzzeredTeam.indexOf(teamIndex) / sessionData.buzzeredTeam.length,
                        );
                      }
                    }
                    return null;
                  }

                  return Theme(
                    data: ThemeData(colorScheme: colorScheme, useMaterial3: true),
                    child: Builder(
                      builder: (context) {
                        return Scaffold(
                          body: Stack(
                            children: [
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Playboard.fromCategoryType(
                                  categoryGroupData: selectedCategoryGroupData,
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
                                child: Column(mainAxisSize: MainAxisSize.min, children: options),
                              ),
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
                                          for (var (index, team) in sessionData.teamsList.indexed)
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
                                                        (sessionData.pointsList.elementAtOrNull(index) ?? 0).toString(),
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.headlineSmall?.copyWith(fontSize: screenSize.height * 0.04),
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
                                        if ((state == HomePageState.question ||
                                                state == HomePageState.questionBuzzered ||
                                                state == HomePageState.answerRevealed) &&
                                            selectedFieldData.$1 != -1)
                                          Question.fromData(questions[selectedFieldData.$1][selectedFieldData.$2]).questionWidget(
                                            context: context,
                                            gameDir: Directory('${appSupportDir.absolute.path}/${sessionData.gameRef!.id}'),
                                            sessionData: sessionData.sessionData,
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
                fallback: fallbackWidget,
              );
            },
          ),
          const Align(
            alignment: Alignment.topLeft,
            child: Padding(padding: EdgeInsets.all(8.0), child: BuzzerStatusIndicator()),
          ),
        ],
      ),
    );
  }

  Future<void> gameLogic({
    required List<List<Map<String, dynamic>>> questions,
    required SessionData sessionData,
    required Future<void> sessionUpdate(Map<Object, Object?> data),
  }) async {
    var playing = sessionData.playing;
    var state = sessionData.state;
    var selectedFieldData = sessionData.selectedFieldData;
AudioController audioController = AudioController();

    if (mediaPlaying != playing) {
      if (playing == null) {
        mediaPlayer.stop();
      } else if (playing && mediaPlaying == null) {
        mediaPlayer.play(
          DeviceFileSource("${appSupportDir.path}/${sessionData.gameRef!.id}/${questions[selectedFieldData.$1][selectedFieldData.$2][music]}"),
        );
        audioController.stopAllMusic();
      } else if (playing){
        mediaPlayer.resume();
audioController.stopAllMusic();
      }
      else
        mediaPlayer.pause();
      mediaPlaying = playing;
    }

    String? playMusicEffect = sessionData.sessionData[playEffect];
    if (playMusicEffect != null) {
      print("Playing effect $playMusicEffect");
      audioController.playEffect(playMusicEffect);
      FirebaseFirestore.instance.collection(sessions).doc(prefs.getString("currentSession")).update({playEffect: null});
    }
    else {
      audioController.stopAllMusic();
    }

    String? playMusicType = sessionData.sessionData[playMusic];
    switch (playMusicType) {
      case musicBackground:
        audioController.startBackgroundMusic();
        break;
      case musicExciting:
        audioController.startExcitingMusic();
        break;
      case musicCalm:
        audioController.startCalmMusic();
        break;
      default:
        audioController.stopAllMusic();
    }

    buzzeredSubscription?.cancel();
    buzzerHistorySubscription?.cancel();
    if (SerialConnection().status == SerialStatus.connected) {
      bool questionBuzzerable = selectedFieldData.$1 >= 0 && Question.fromData(questions[selectedFieldData.$1][selectedFieldData.$2]).buzzerable();

      //listen to the buzzer if in buzzer test or an open question or a question already buzzered with buzzerqueue enabled
      if (state == HomePageState.buzzerTest ||
          (questionBuzzerable && (state == HomePageState.question || (state == HomePageState.questionBuzzered && sessionData.enableBuzzerQueue)))) {
        buzzeredSubscription = SerialConnection().buzzerPressed.listen((event) {
          int teamIndex = sessionData.buzzerTeamMap[event] ?? -1;
          if (teamIndex == -1) return;
          if (state == HomePageState.question) {
            //TODO check if it would be lower latency when [buzzerTeam] set manually
            sessionUpdate({
              buzzeredFrom: [teamIndex],
              currentState: HomePageState.questionBuzzered.name,
              playingFrom: false,
              playMusic: null,
            });
            playSound(teamIndex);
          } else if (state == HomePageState.questionBuzzered && sessionData.enableBuzzerQueue && !sessionData.buzzeredTeam.contains(teamIndex)) {
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
        });
      }
    }
  }
}
