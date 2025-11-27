import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quiz_show/database/constants.dart';

import '../widgets/media_upload.dart';

//TODO give the mediapaths to the mediadownloader to download them
class AudioController {
  static final AudioController _instance = AudioController._internal();

  factory AudioController() {
    return _instance;
  }

  AudioController._internal();

  final musicBackgroundPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  final musicCalmPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  final musicExcitingPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  final Map<String, AudioPlayer> effectPlayers = {};
  String _gameId = "";
  String? _selectedCategoryGroupId = "";
  String? _selectedCategoryId = "";
  String? _selectedQuestionId = "";
  String _oldGameId = "";
  String? _oldSelectedCategoryGroupId = "";
  String? _oldSelectedCategoryId = "";
  String? _oldSelectedQuestionId = "";

  Future<String> getMediaFilePath(String mediaPath) async {
    final Directory appSupportDir = await getApplicationSupportDirectory();
    return "${appSupportDir.absolute.path}/$_gameId/$mediaPath";
  }

  void setGameId(String newGameId) {
    _gameId = newGameId;
  }

  void setSelectedCategoryGroupId(String? newCategoryGroupId) {
    _selectedCategoryGroupId = newCategoryGroupId;
  }

  void setSelectedCategoryId(String? newCategoryId) {
    _selectedCategoryId = newCategoryId;
  }

  void setSelectedQuestionId(String? newQuestionId) {
    _selectedQuestionId = newQuestionId;
  }

  void startBackgroundMusic() => startMusic(player: musicBackgroundPlayer);

  void startCalmMusic() => startMusic(player: musicCalmPlayer);

  void startExcitingMusic() => startMusic(player: musicExcitingPlayer);

  void startMusic({required AudioPlayer player}) async {
    if(player.state == PlayerState.playing) return;
    player.setVolume(1.0);
    player.stop();
    player.seek(Duration.zero);
    player.resume();
    for (var otherPlayer in [musicBackgroundPlayer, musicCalmPlayer, musicExcitingPlayer]) {
      if (otherPlayer != player) {
        fadeOutMusic(player: otherPlayer);
      }
    }
  }

  void stopAllMusic() {
    fadeOutMusic(player: musicBackgroundPlayer);
    fadeOutMusic(player: musicCalmPlayer);
    fadeOutMusic(player: musicExcitingPlayer);
  }

  void fadeOutMusic({required AudioPlayer player, Duration duration = const Duration(milliseconds: 500)}) async {
    if (player.state != PlayerState.playing) return;
    double volume = player.volume;
    const int steps = 10;
    Duration stepDuration = Duration(milliseconds: (duration.inMilliseconds / steps).round());
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(stepDuration, () {
        player.setVolume(volume * (1 - i / steps));
      });
    }
    await player.stop();
    await player.setVolume(volume);
  }

  void playEffect(String effectKey) {
    var player = effectPlayers[effectKey];
    if (player != null) {
      if (player.state == PlayerState.playing) {
        player.stop();
      } else {
        player.seek(Duration.zero);
        player.resume();
      }
    }
  }

  Future<List<String>> getAvailableEffects() async {
    var db = FirebaseFirestore.instance;
    var gameRef = db.collection(games).doc(_gameId);
    var categoryGroupRef = _selectedCategoryGroupId != null ? gameRef.collection(categoryGroups).doc(_selectedCategoryGroupId): null;
    var categoryRef = _selectedCategoryId != null? gameRef.collection(categories).doc(_selectedCategoryId) : null;
    var questionRef = _selectedQuestionId != null ? categoryRef?.collection(questions).doc(_selectedQuestionId) : null;
    List<DocumentSnapshot<Map<String, dynamic>>> docs = await Future.wait<DocumentSnapshot<Map<String, dynamic>>>([
      ?questionRef?.get(),
      ?categoryRef?.get(),
      ?categoryGroupRef?.get(),
      gameRef.get(),
    ]);
    Set<String> effects = {};
    for (var doc in docs) {
      var data = doc.data();
      if (data == null) continue;
      Map<String, String> docEffects = Map<String, String>.from(data[musicEffects] ?? {});
      effects.addAll(docEffects.keys);
    }
    return effects.toList();
  }

  Future<void> setFiles() async {
    if(_oldGameId == _gameId &&
       _oldSelectedCategoryGroupId == _selectedCategoryGroupId &&
       _oldSelectedCategoryId == _selectedCategoryId &&
       _oldSelectedQuestionId == _selectedQuestionId) {
      return;
    }
    _oldGameId = _gameId;
    _oldSelectedCategoryGroupId = _selectedCategoryGroupId;
    _oldSelectedCategoryId = _selectedCategoryId;
    _oldSelectedQuestionId = _selectedQuestionId;

    var db = FirebaseFirestore.instance;
    var gameRef = db.collection(games).doc(_gameId);
    var categoryGroupRef = _selectedCategoryGroupId != null ? gameRef.collection(categoryGroups).doc(_selectedCategoryGroupId): null;
    var categoryRef = _selectedCategoryId != null? gameRef.collection(categories).doc(_selectedCategoryId) : null;
    var questionRef = _selectedQuestionId != null ? categoryRef?.collection(questions).doc(_selectedQuestionId) : null;
    List<DocumentSnapshot<Map<String, dynamic>>> docs = await Future.wait<DocumentSnapshot<Map<String, dynamic>>>([
      ?questionRef?.get(),
      ?categoryRef?.get(),
      ?categoryGroupRef?.get(),
      gameRef.get(),
    ]);
    String? musicBackgroundFile;
    String? musicCalmFile;
    String? musicExcitingFile;

    Map<String, String?> effects = {};
    for (var doc in docs) {
      var data = doc.data();
      if (data == null) continue;
      musicBackgroundFile ??= data[musicBackground];
      musicCalmFile ??= data[musicCalm];
      musicExcitingFile ??= data[musicExciting];

      Map<String, String> docEffects = Map<String, String>.from(data[musicEffects] ?? {});
      effects[musicEffectAnswerCorrect] ??= data[musicEffectAnswerCorrect];
      effects[musicEffectAnswerWrong] ??= data[musicEffectAnswerWrong];
      effects[musicEffectAnswerClosed] ??= data[musicEffectAnswerClosed];
      effects[musicEffectReveal] ??= data[musicEffectReveal];
      for (var entry in docEffects.entries) {
        effects[entry.key] ??= entry.value;
      }
    }
    if (musicBackgroundFile != null) {
      var path = await getMediaFilePath(musicBackgroundFile);
      await musicBackgroundPlayer.stop();
      await musicBackgroundPlayer.setSourceDeviceFile(path);
    }
    if (musicCalmFile != null) {
      var path = await getMediaFilePath(musicCalmFile);
      await musicCalmPlayer.stop();
      await musicCalmPlayer.setSourceDeviceFile(path);
    }
    if (musicExcitingFile != null) {
      var path = await getMediaFilePath(musicExcitingFile);
      await musicExcitingPlayer.stop();
      await musicExcitingPlayer.setSourceDeviceFile(path);
    }
    for (var soundPlayer in effectPlayers.values) {
      await soundPlayer.dispose();
    }
    effectPlayers.clear();
    for (var entry in effects.entries) {
      if (entry.value == null || entry.value!.isEmpty) continue;
      var path = await getMediaFilePath(entry.value!);
      var player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await player.setSourceDeviceFile(path);
      effectPlayers[entry.key] = player;
    }
  }
}

void showSetMusicDialog({
  required BuildContext context,
  required String gameId,
  required DocumentReference<Map<String, dynamic>> ref,
  List<String> effects = const [],
}) => showDialog(
  context: context,
  builder: (context) => AlertDialog(
    content: FutureBuilder(
      future: ref.get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var data = snapshot.data!.data()!;
        List<String> customEffects = data[musicCustomEffect] != null ? List<String>.from(data[musicCustomEffect]) : [];
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var musicField in [musicBackground, musicCalm, musicExciting])
                Row(
                  children: [
                    Text(musicField),
                    const SizedBox(width: 8),
                    MediaUploadIconButton(
                      uploadType: MediaUploadType.music,
                      gameId: gameId,
                      databaseMediaIndex: data[musicField],
                      updateDB: (value) => ref.update({musicField: value}),
                    ),
                  ],
                ),
              Divider(),
              for (var effect in [musicEffectAnswerCorrect, musicEffectAnswerWrong, musicEffectAnswerClosed, musicEffectReveal, ...effects])
                Row(
                  children: [
                    Text(effect),
                    const SizedBox(width: 8),
                    MediaUploadIconButton(
                      uploadType: MediaUploadType.music,
                      gameId: gameId,
                      databaseMediaIndex: data[musicEffects] != null ? (data[musicEffects] as Map<String, dynamic>)[effect] : null,
                      updateDB: (value) async {
                        data[musicEffects] =  data[musicEffects] ?? {};
                        data[musicEffects][effect] = value;
                        ref.update({musicEffects: data[musicEffects]});
                      },
                    ),
                  ],
                ),
              StatefulBuilder(builder: (context, setState) => Column(
                children: [
                  for (var i = 0; i < customEffects.length; i++)
                    Row(
                      children: [
                        Expanded(child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Custom Effect ${i + 1}',
                          ),
                          controller: TextEditingController(text: customEffects[i]),
                          onChanged: (value) {
                            customEffects[i] = value;
                            ref.update({musicCustomEffect: customEffects});
                          },
                        )),
                        const SizedBox(width: 8),
                        MediaUploadIconButton(
                          uploadType: MediaUploadType.music,
                          gameId: gameId,
                          databaseMediaIndex: data[musicEffects] != null ? (data[musicEffects] as Map<String, dynamic>)[customEffects[i]] : null,
                          updateDB: (value) async {
                            data[musicEffects] =  data[musicEffects] ?? {};
                            data[musicEffects][customEffects[i]] = value;
                            ref.update({musicEffects: data[musicEffects]});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            customEffects.removeAt(i);
                            ref.update({musicCustomEffect: customEffects});
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  TextButton(
                    onPressed: () async {
                      customEffects.add('');
                      ref.update({musicCustomEffect: customEffects});
                      setState(() {});
                    },
                    child: const Text('Add Custom Effect'),
                  ),
                ],
              )),
            ],
          ),
        );
      },
    ),
  ),
);
