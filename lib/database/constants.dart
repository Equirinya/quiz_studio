enum QuestionType {
  free("Free Question"),
  noBuzzer("No Buzzer"),
  abcd("ABCD"),
  progressingReveal("Progressing Reveal");

  final String uiString;

  const QuestionType(this.uiString);
}

enum HomePageState { overview, question, questionBuzzered, buzzerTest }

//database
const String users = 'users';
const String username = 'username';
const String lastLogin = 'lastLogin';
const String games = 'games';
const String gamesMediaIndex = 'gamesMediaIndex';
const String locked = 'locked';

enum AccessType {
  admin("Admin"),
  full("Full Access"),
  limited("Limited Access"),
  none("No Access");

  final String uiString;

  const AccessType(this.uiString);
}

const String categories = 'categories';
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
const String information = 'information';
const String answers = 'answers';
const String answersCorrect = 'answersCorrect';

const String sessions = 'sessions';

const String buzzerSensitivity = 'buzzerSensitivity';
const String buzzerTeam = 'buzzerTeam';
const String currentState = 'currentState';
const String playingFrom = 'playingFrom';
const String revealed = 'revealed';
const String buzzeredFrom = 'buzzeredFrom';
const String game = 'game';
const String selectedField = 'selectedField';
const String lastUsed = 'lastUsed';
const String playedFields = 'playedFields';
const String points = 'points';
const String teams = 'teams';

//Strings
const String noSession = 'No session selected';
const String unnamed = 'Unnamed';
const String overview = 'Overview';
const String newCategory = 'New';
