import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

enum HomePageState { overview, question, questionBuzzered, buzzerTest }

//database
const String users = 'users';
const String username = 'username';
const String lastLogin = 'lastLogin';
const String games = 'games';
const String gamesMediaIndex = 'gamesMediaIndex';
const String locked = 'locked';
const String documentId = 'documentId'; //currently only used for the questionDocuments to add id to data

enum AccessType {
  admin("Admin"),
  full("Full Access"),
  limited("Limited Access"),
  none("No Access");

  final String uiString;

  const AccessType(this.uiString);
}
//general questions
const String categories = 'categories';
const String categoryType = 'categoryType';
const String categoryIndex = 'categoryIndex'; //index within group
const String categoryGroup = 'categoryGroup'; //groups are created as 1,2,3,... and therefore also act as order

enum CategoryType {
  noboard('No Board', Icons.crop_square_outlined),
  wheel('Wheel Playboard', Icons.pie_chart_outline);

  final String uiString;
  final IconData icon;
  String databaseString() => 'category_${this.name}';

  const CategoryType(this.uiString, this.icon);
}

const String active = 'active';
const String createdAt = 'createdAt';
const String createdBy = 'createdBy';
const String access = 'access';
const String name = 'name';
const String questions = 'questions';
const String type = 'type';
const String question = 'question';
const String image = 'image';
const String music = 'music';
const String description = 'description';
const String pointsMinus = 'pointsMinus';
const String pointsPlus = 'pointsPlus';
const String answerHint = 'answerHint';
//free question type
const String noBuzzer = 'noBuzzer';
//progressing reveal question type
const String information = 'information';
const String informationImage = 'informationImage';
const String informationMusic = 'informationMusic';
//abcd question type
const String answers = 'answers';
const String answersCorrect = 'answersCorrect';

const String sessions = 'sessions';

const String buzzerSensitivity = 'buzzerSensitivity';
const String queueBuzzers = 'queueBuzzers'; //bool: if true, buzzers are queued, otherwise only first buzzer counts until reset
const String buzzerTeam = 'buzzerTeam';
const String currentState = 'currentState';
const String playingFrom = 'playingFrom'; //TODO rename to playing as it currently only is true for playing, false for paused, and null for stopped
const String buzzeredFrom = 'buzzeredFrom';
const String game = 'game';
const String selectedCategoryGroup = 'selectedCategoryGroup';
const String selectedField = 'selectedField';
const String lastUsed = 'lastUsed';
const String playedFields = 'playedFields';
const String points = 'points';
const String teams = 'teams';
//progressing reveal
const String informationImageFocus = 'informationImageFocus';
const String revealed = 'revealed';

const Map<String, dynamic> previewSessionConfig = {
  revealed : 100
};

const Map<String, dynamic> resetSessionConfig = {
  revealed : 0,
  informationImageFocus: 0,
  playingFrom: null,
};


//File Selection
const XTypeGroup musicExtension = XTypeGroup(
  label: 'Audio File',
  extensions: <String>['mp3', 'wav'],
);
const XTypeGroup musicUniformFileType = XTypeGroup(
  label: 'Audio File',
  uniformTypeIdentifiers: <String>['public.audio'],
);

//Strings
const String noSession = 'No session selected';
const String unnamed = 'Unnamed';
const String overview = 'Overview';
const String newCategory = 'New';
