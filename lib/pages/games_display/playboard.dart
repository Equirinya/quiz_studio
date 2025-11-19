import 'package:flutter/material.dart';
import 'package:quiz_show/database/constants.dart';
import 'package:quiz_show/pages/games_display/playboard_display.dart';
import 'package:quiz_show/pages/games_display/playboard_wheel.dart';
import 'package:quiz_show/pages/games_display/playboard_map.dart';

import '../../database/game_stream.dart';

abstract class Playboard extends StatelessWidget {
  const Playboard({
    super.key,
    required this.categoryGroupData,
    required this.homePageState,
    required this.size,
    required this.categoryNames,
    required this.questionDocs,
    required this.selectedFieldData,
    required this.playedFieldsList,
  });

  final CategoryGroupData? categoryGroupData;
  final HomePageState homePageState;
  final Size size;

  final List<String> categoryNames;
  final List<List<Map<String, dynamic>>> questionDocs;

  final (int, int) selectedFieldData;
  final List<(int, int)> playedFieldsList;

  factory Playboard.fromCategoryType({
    required CategoryGroupData? categoryGroupData,
    required HomePageState homePageState,
    required Size size,
    required List<String> categoryNames,
    required List<List<Map<String, dynamic>>> questionDocs,
    required (int, int) selectedFieldData,
    required List<(int, int)> playedFieldsList,
  }) {
    switch (categoryGroupData?.type ?? CategoryGroupType.wheel) {
      case CategoryGroupType.display:
        return DisplayPlayboard(
          categoryGroupData: categoryGroupData,
          homePageState: homePageState,
          size: size,
          categoryNames: categoryNames,
          questionDocs: questionDocs,
          selectedFieldData: selectedFieldData,
          playedFieldsList: playedFieldsList,
        );
      case CategoryGroupType.wheel:
        return WheelPlayboard(
          categoryGroupData: categoryGroupData,
          homePageState: homePageState,
          size: size,
          categoryNames: categoryNames,
          questionDocs: questionDocs,
          selectedFieldData: selectedFieldData,
          playedFieldsList: playedFieldsList,
        );
      case CategoryGroupType.map:
        return MapPlayboard(
          categoryGroupData: categoryGroupData,
          homePageState: homePageState,
          size: size,
          categoryNames: categoryNames,
          questionDocs: questionDocs,
          selectedFieldData: selectedFieldData,
          playedFieldsList: playedFieldsList,
        );
    }
  }
}
