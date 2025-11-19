import 'package:flutter/material.dart';
import 'package:quiz_show/pages/games_display/playboard.dart';

class DisplayPlayboard extends Playboard {
  const DisplayPlayboard({
    super.key,
    required super.categoryGroupData,
    required super.homePageState,
    required super.size,
    required super.categoryNames,
    required super.questionDocs,
    required super.selectedFieldData,
    required super.playedFieldsList,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Column(
        children: [
          Text(categoryGroupData?.text ?? "", style: TextStyle(fontSize: size.height * 0.05)),
        ],
      ),
    );
  }
}
