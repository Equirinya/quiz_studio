import 'package:flutter/material.dart';
import 'package:quiz_show/pages/games_display/playboard.dart';

class NoBoardPlayboard extends Playboard {
  const NoBoardPlayboard(
      {super.key, required super.homePageState, required super.size, required super.categoryNames, required super.questionDocs, required super.selectedFieldData, required super.playedFieldsList,});

  @override
  Widget build(BuildContext context) {
    return Text("NoBoard");
  }
}
