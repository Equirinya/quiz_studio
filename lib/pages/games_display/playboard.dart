import 'package:flutter/material.dart';
import 'package:quiz_show/database/constants.dart';
import 'package:quiz_show/pages/games_display/playboard_noboard.dart';
import 'package:quiz_show/pages/games_display/playboard_wheel.dart';

abstract class Playboard extends StatelessWidget {
  const Playboard({
    super.key,
    required this.homePageState,
    required this.size,
    required this.categoryNames,
    required this.questionDocs,
    required this.selectedFieldData,
    required this.playedFieldsList,
  });

  final HomePageState homePageState;
  final Size size;

  final List<String> categoryNames;
  final List<List<Map<String, dynamic>>> questionDocs;

  final (int, int) selectedFieldData;
  final List<(int, int)> playedFieldsList;

  factory Playboard.fromCategoryType({
    required CategoryType categoryType,
    required HomePageState homePageState,
    required Size size,
    required List<String> categoryNames,
    required List<List<Map<String, dynamic>>> questionDocs,
    required (int, int) selectedFieldData,
    required List<(int, int)> playedFieldsList,
  }) {
    switch (categoryType) {
      case CategoryType.noboard:
        return NoBoardPlayboard(
          homePageState: homePageState,
          size: size,
          categoryNames: categoryNames,
          questionDocs: questionDocs,
          selectedFieldData: selectedFieldData,
          playedFieldsList: playedFieldsList,
        );
      case CategoryType.wheel:
        return WheelPlayboard(
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
