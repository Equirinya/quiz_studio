import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

enum HomePageState { overview, question, questionBuzzered, answerRevealed, buzzerTest }

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


//categories
const String categories = 'categories';
const String categoryGroup = 'categoryGroup';
const String categoryGroupId = 'categoryGroupId';
const String categoryIndex = 'categoryIndex'; //index within group
const String active = 'active';
const String createdAt = 'createdAt';
const String createdBy = 'createdBy';
const String access = 'access';
const String name = 'name';

//category groups
const String categoryGroups = 'categoryGroups';
const String categoryGroupType = 'categoryGroupType';
const String categoryGroupIndex = 'categoryGroupIndex';
enum CategoryGroupType {
  display('Display Board', Icons.art_track_rounded),
  wheel('Wheel Playboard', Icons.pie_chart_outline),
  map('Map Playboard', Icons.route);

  final String uiString;
  final IconData icon;
  String databaseString() => 'category_${this.name}';

  const CategoryGroupType(this.uiString, this.icon);
}
const String text = 'text';
const String imagePath = 'imagePath';
const String color = 'color';
const String accentColor = 'accentColor';
const String connections = 'connections';
const String splitPointFields = 'splitPointFields';

//questions
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
//familyfeud
const String informationPercentage = 'informationPercentage';
const String wrongAttempts = 'wrongAttempts';
const String revealedList = 'revealedList';
const String absoluteValues = 'absoluteValues';
//abcd question type
const String answers = 'answers';
const String answersCorrect = 'answersCorrect';

//sessions
const String sessions = 'sessions';

const String buzzerSensitivity = 'buzzerSensitivity';
const String queueBuzzers = 'queueBuzzers'; //bool: if true, buzzers are queued, otherwise only first buzzer counts until reset
const String buzzerTeam = 'buzzerTeam';
const String currentState = 'currentState';
const String playingFrom = 'playingFrom'; //TODO rename to playing as it currently only is true for playing, false for paused, and null for stopped
const String playBuzzer = 'playBuzzer';
const String buzzeredFrom = 'buzzeredFrom';
const String game = 'game';
const String selectedCategoryGroup = 'selectedCategoryGroup';
const String selectedField = 'selectedField';
const String lastUsed = 'lastUsed';
const String playedFields = 'playedFields';
const String points = 'points';
const String teams = 'teams';
const String playEffect = 'playEffect';
const String playMusic = 'playMusic';
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
  buzzeredFrom: [],
  revealedList: [],
  wrongAttempts: 0,
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


//Music Types
const String musicBackground = 'musicBackground';
const String musicCalm = 'musicCalm';
const String musicExciting = 'musicExciting';


const String musicEffects = 'musicEffects';
const String musicEffectReveal = 'musicEffectReveal';
const String musicEffectAnswerCorrect = 'musicEffectAnswerCorrect';
const String musicEffectAnswerWrong = 'musicEffectAnswerWrong';
const String musicEffectAnswerClosed = 'musicEffectAnswerClosed';
const String musicCustomEffect = 'musicCustomEffect';

//Strings
const String noSession = 'No session selected';
const String unnamed = 'Unnamed';
const String overview = 'Overview';
const String newCategory = 'New';
