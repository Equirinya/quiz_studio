import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:quiz_show/question_types/abstract_question.dart';
import 'package:quiz_show/widgets/media_upload.dart';

import '../database/constants.dart';
import '../database/session_stream.dart';

class FamilyFeudQuestion extends Question {
  FamilyFeudQuestion(super.data);

  @override
  String explainString = """This question type is inspired by family feud and shows a list of possible answers.""";

  @override
  String asText() => "${super.asText()}"
      "Information to be revealed:\n"
      "${data[information] is! List ? "" : (List<String>.from(data[information])).indexed.map((e) => "(${(List<double>.from(data[informationPercentage]).elementAtOrNull(e.$1)) ?? "-"} %) ${e.$2}\n").join()}";

  @override
  bool showDefaultAnswerButtons() => false;

  @override
  List<Widget> controlButtons(BuildContext context, SessionData sessionData, Future<void> Function(Map<String, dynamic> data) update) {
    List<String> infoList = List<String>.from(data[information] ?? []);
    List<double> infoPercentageList = List<num>.from(data[informationPercentage] ?? []).map((e) => e.toDouble()).toList();
    List<int> revealedInfos = List<int>.from(sessionData.sessionData[revealedList] ?? []);
    int _wrongAttempts = sessionData.sessionData[wrongAttempts] ?? 0;
    HomePageState state = sessionData.state;
    int informationLength = infoList.length;
    int columns = informationLength <= 5 ? 1 : 2;
    int rows = (informationLength / columns).ceil();

    return [
      if (state == HomePageState.questionBuzzered)
        if(_wrongAttempts < 2)
        ElevatedButton(
            onPressed: () {
              update({
                wrongAttempts: FieldValue.increment(1),
                playEffect: musicEffectAnswerWrong
              });
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close),
                Text("Wrong Answer"),
              ],
            ))
      else if (_wrongAttempts == 2)
      ElevatedButton(
          onPressed: () {
            update({
              wrongAttempts: FieldValue.increment(1),
              playEffect: musicEffectAnswerWrong
            });
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close),
              Text("Wrong Answer -> Next Team"),
            ],
          ))
      else if (_wrongAttempts == 3)
            ...[ElevatedButton(
                onPressed: () {
                  double accumulatedAnswerPercentage = revealedInfos.map((e) => infoPercentageList[e]).fold(0.0, (previousValue, element) => previousValue + element);
                  int pointsToAward = (accumulatedAnswerPercentage*data[pointsPlus]/100).round();
                  var pointsList = sessionData.pointsList;
                  pointsList[sessionData.buzzeredTeam.first] = (pointsList[sessionData.buzzeredTeam.first]) + pointsToAward;
                  update({
                    wrongAttempts: 0,
                    revealedList: List<int>.generate(informationLength, (index) => index),
                    currentState: HomePageState.answerRevealed.name,
                    points: pointsList,
                    playEffect: musicEffectAnswerWrong
                  });
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close),
                    Text("Wrong Answer"),
                  ],
                )),
              ElevatedButton(
                  onPressed: () {
                    double accumulatedAnswerPercentage = revealedInfos.map((e) => infoPercentageList[e]).fold(0.0, (previousValue, element) => previousValue + element);
                    int pointsToAward = (accumulatedAnswerPercentage*data[pointsPlus]/100).round();
                    var pointsList = sessionData.pointsList;
                    int opponentTeamIndex = sessionData.buzzeredTeam.elementAtOrNull(1) ?? (sessionData.teamsList.length == 2 ? (1 - sessionData.buzzeredTeam.first) : -1);
                    if(opponentTeamIndex != -1) pointsList[opponentTeamIndex] = (pointsList[opponentTeamIndex]) + pointsToAward;

                    update({
                      wrongAttempts: 0,
                      revealedList: List<int>.generate(informationLength, (index) => index),
                      currentState: HomePageState.answerRevealed.name,
                      points: pointsList,
                      playEffect: musicEffectAnswerCorrect
                    });
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check),
                      Text("Right Answer"),
                    ],
                  ))],
      if( _wrongAttempts >= 1 && state == HomePageState.questionBuzzered)
        ElevatedButton(
            onPressed: () {
              update({
                wrongAttempts: 0,
              });
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh),
                Text("Reset Wrong Answers"),
              ],
            )),
      if (state == HomePageState.questionBuzzered)
        SizedBox(
            width: double.maxFinite,
            height: rows*48,
            child: Wrap(
              direction: Axis.vertical,
              alignment: WrapAlignment.start,
              children: [
                for (var (i, information) in infoList.indexed)
                  SizedBox(
                    width: MediaQuery.of(context).size.width / (infoList.length <= 5 ? 1 : 2) - 16,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: revealedInfos.contains(i) ? Theme.of(context).colorScheme.primaryContainer : null,
                      ),
                      onPressed: revealedInfos.contains(i)
                          ? () {
                              revealedInfos.remove(i);
                              update({
                                revealedList: revealedInfos,
                              });
                            }
                          : () {
                              revealedInfos.add(i);
                              Map<String,dynamic> updateData = {
                                revealedList: revealedInfos,
                                playEffect: musicEffectReveal
                              };
                              double accumulatedAnswerPercentage = revealedInfos.map((e) => infoPercentageList[e]).fold(0.0, (previousValue, element) => previousValue + element);
                              int pointsToAward = (accumulatedAnswerPercentage*data[pointsPlus]/100).round();
                              var pointsList = sessionData.pointsList;

                              if(infoList.indexed.every((element) => revealedInfos.contains(element.$1))){
                                pointsList[sessionData.buzzeredTeam.first] = (pointsList[sessionData.buzzeredTeam.first]) + pointsToAward;
                                updateData[currentState] = HomePageState.answerRevealed.name;
                                updateData[points] = pointsList;
                              }
                              update(updateData);
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          children: [
                            Text(
                              '${infoPercentageList[i]}%',
                            ),
                            Expanded(
                              child: Text(
                                information,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ))
    ];
  }

  @override
  List<String?> mediaPaths() {
    return super.mediaPaths();
  }

  @override
  List<Widget> inputWidgets(BuildContext context, String gameId, Future<void> Function(Map<String, dynamic> data) update, VoidCallback refresh) {
    List<String> infoList = List<String>.from(data[information] ?? []);
    List<double> infoPercentageList = List<num>.from(data[informationPercentage] ?? []).map((e) => e.toDouble()).toList();
    return [
      const SizedBox(
        height: 16,
      ),
      Row(
        children: [
          Text("Answers:", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
          IconButton(
            onPressed: () async {
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (context) => RankerImportDialog(),
              );
              if (result != null) {
                await update({
                  information: result[information],
                  informationPercentage: result[informationPercentage],
                  if (result.containsKey(question)) question: result[question],
                  if (result.containsKey(answerHint)) answerHint: result[answerHint],
                });
                refresh();
              }
            },
            icon: const Icon(Icons.link, size: 16,)
          ),

        ],
      ),
      SwitchListTile(
        value: data[absoluteValues] ?? false,
        onChanged: (value) async {
          await update({absoluteValues: value});
          refresh();
        },
        title: const Text("Show absolute values instead of percentages"),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      ReorderableListView.builder(
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        buildDefaultDragHandles: false,
        itemBuilder: (context, i) => Padding(
          key: ValueKey("answers_${data[documentId]}_$i"),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: i,
                child: Icon(
                  Icons.drag_indicator,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: TextEditingController(text: infoPercentageList[i].toString()),
                  decoration: InputDecoration(
                    labelText: "Value ${i + 1}",
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) async {
                    data[informationPercentage] ??= [];
                    if (data[informationPercentage]!.length <= i) {
                      return;
                    }
                    data[informationPercentage]![i] = double.tryParse(value) ?? 0.0;
                    update({informationPercentage: data[informationPercentage]});
                  },
                ),
              ),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: infoList[i]),
                  decoration: InputDecoration(
                    labelText: "Information ${i + 1}",
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) async {
                    data[information] ??= [];
                    if (data[information]!.length <= i) {
                      return;
                    }
                    data[information]![i] = value;
                    update({information: data[information]});
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  data[information].removeAt(i);
                  data[informationPercentage].removeAt(i);
                  await update({information: data[information], informationPercentage: data[informationPercentage]});
                  refresh();
                },
              ),
            ],
          ),
        ),
        itemCount: infoList.length,
        onReorder: (oldIndex, newIndex) async {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          data[information].insert(newIndex, (data[information] as List?)?.removeAt(oldIndex) ?? 0.0);
          data[informationPercentage].insert(newIndex, (data[informationPercentage] as List?)?.removeAt(oldIndex) ?? 0.0);
          await update({
            information: data[information],
            informationPercentage: data[informationPercentage],
          });
          refresh();
        },
        footer: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () async {
              data[information] ??= [];
              data[informationPercentage] ??= [];
              data[information].add("");
              data[informationPercentage].add(0.0);
              await update({
                information: data[information],
                informationPercentage: data[informationPercentage],
              });
              refresh();
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Add Information"),
            ),
          ),
        ),
      ),
    ];
  }

  @override
  double questionHeightPercentage() {
    double questionfactor;
    questionfactor = super.questionHeightPercentage();
    questionfactor += 0.05; //for the xxx
    int informationLength = data[information]?.length ?? 0;
    int columns = informationLength <= 5 ? 1 : 2;
    int rows = (informationLength / columns).ceil();
    questionfactor += 0.08 * rows;
    return questionfactor;
  }

  @override
  Widget questionWidget(
      {required BuildContext context, required Directory gameDir, bool controllerView = false, required Map<String, dynamic> sessionData}) {
    List<String> informationStrings = List<String>.from(data[information] ?? []);
    List<double> infoPercentages = List<num>.from(data[informationPercentage] ?? []).map((e) => e.toDouble()).toList();
    int columns = informationStrings.length <= 5 ? 1 : 2;
    int rows = (informationStrings.length / columns).ceil();
    var size = MediaQuery.of(context).size;
    List<int> revealedInfos = List<int>.from(sessionData[revealedList] ?? []);
    int _wrongAttempts = sessionData[wrongAttempts] ?? 0;
    bool showAbsoluteValues = data[absoluteValues] ?? false;

    return Column(children: [
      super.questionWidget(gameDir: gameDir, controllerView: controllerView, sessionData: sessionData, context: context),
      SizedBox(
        height: size.height * 0.06,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < _wrongAttempts; i++) Icon(Icons.close, color: Theme.of(context).colorScheme.error, size: size.height * 0.05),
          ],
        ),
      ),
      Visibility(
        visible: !controllerView,
        child: SizedBox(
          height: (size.height * 0.08*rows) + 8,
          child: Wrap(
            direction: Axis.vertical,
            alignment: WrapAlignment.start,
            children: [
              for (var (i, information) in informationStrings.indexed)
                SizedBox(
                  width: size.width / columns - 16,
                  height: size.height * 0.08,
                  child: Card(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: size.height * 0.1,
                            child: Visibility(
                              visible: revealedInfos.contains(i),
                              child: Center(
                                child: Text(
                                  showAbsoluteValues ? (infoPercentages[i] % 1 == 0 ? infoPercentages[i].toInt().toString() : infoPercentages[i].toString()): '${infoPercentages[i]}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.bold, fontSize: controllerView ? null : size.height * 0.03 - 2, color: Theme.of(context).colorScheme.tertiary),
                                ),
                              ),
                            ),
                          ),
                          VerticalDivider(
                            thickness: 4,
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          Expanded(
                            child: Visibility(
                              visible: revealedInfos.contains(i),
                              child: Text(
                                information,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: controllerView ? null : size.height * 0.04 - 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      )
    ]);
  }
}

class RankerImportDialog extends StatefulWidget {
  const RankerImportDialog({super.key});

  @override
  State<RankerImportDialog> createState() => _RankerImportDialogState();
}

class _RankerImportDialogState extends State<RankerImportDialog> {
  final TextEditingController _urlController = TextEditingController();
  final List<String> _logs = [];
  bool _loading = false;
  String? _error;

  void _log(String s) {
    setState(() {
      _logs.add(s);
    });
  }

  Future<void> _import() async {
    final url = _urlController.text.trim();
    _error = null;
    _logs.clear();
    if (url.isEmpty) {
      setState(() => _error = "Bitte URL eingeben.");
      return;
    }
    final rankerPattern = RegExp(r'^https?://(www\.)?ranker\.com/(list/[^/]+/[^/]+|crowdranked-list/[^/]+)', caseSensitive: false);
    if (!rankerPattern.hasMatch(url)) {
      _log("Ungültige URL. Bitte eine Ranker List URL eingeben (z.B. https://www.ranker.com/list/best-smells/jacob-shelton)");
    }

    setState(() {
      _loading = true;
    });

    try {
      _log("Lade Seite...");
      final pageResp = await http.get(Uri.parse(url),
        headers: {
          "User-Agent": "Twitterbot",
        },);
      if (pageResp.statusCode != 200) throw Exception("Seite konnte nicht geladen werden: ${pageResp.statusCode}");

      final body = pageResp.body;

      final regex = RegExp(r'"listId"\s*:\s*(\d+)', caseSensitive: false);
      final match = regex.firstMatch(body);
      String? listId = match?.group(1);
      if (listId != null) {
        _log("Gefundene List-ID über meta: $listId");
      } else {
        _log("Seite geladen, suche nach imgix URL...");

        // Suche imgix list image url, Beispiel: imgix.ranker.com/list_img_v2/7547/2167547/original/...
        final imgixRegex = RegExp(r'imgix\.ranker\.com/list_img_v2/\d+/(\d+)', caseSensitive: false);
        final imgixMatch = imgixRegex.firstMatch(body);
        if (imgixMatch == null) throw Exception("Keine imgix list image URL gefunden.");
        listId = imgixMatch.group(1);
        _log("Gefundene List-ID: $listId");
      }
      if (listId == null || listId.isEmpty) throw Exception("Keine List-ID gefunden.");


      final sourceString = 'Ranker: $url (listId:$listId)';

      _log("Hole List-Metadaten...");
      final listInfoResp = await http.get(Uri.parse('https://api.ranker.com/lists/$listId'));
      if (listInfoResp.statusCode != 200) throw Exception("List-Info API Fehler: ${listInfoResp.statusCode}");
      final listInfo = jsonDecode(listInfoResp.body) as Map<String, dynamic>;
      final listTitle = listInfo['name'] ?? listInfo['displayName'] ?? listInfo['title'] ?? 'Imported Ranker List';
      _log("List-Titel: $listTitle");

      _log("Hole Top 20 Items...");
      final itemsResp = await http.get(Uri.parse('https://api.ranker.com/lists/$listId/items?limit=20'));
      if (itemsResp.statusCode != 200) throw Exception("Items API Fehler: ${itemsResp.statusCode}");
      final itemsJson = jsonDecode(itemsResp.body) as Map<String, dynamic>;
      final listItems = (itemsJson['listItems'] as List<dynamic>?) ?? [];
      if (listItems.isEmpty) throw Exception("Keine Listeneinträge gefunden.");

      _log("Verarbeite Items...");
      final allNames = <String>[];
      final allScores = <double>[];
      for (var item in listItems) {
        final node = item['node'] as Map<String, dynamic>?;
        final name = (node?['name'] ?? item['name'] ?? '').toString();
        final voteScore = (item['voteScore'] ?? 0).toDouble();
        allNames.add(name);
        allScores.add(voteScore);
        _log("Item: $name (voteScore: $voteScore)");
      }

// Determine split point: if fewer than 11 items, show all but one
      final int splitIndex = allNames.length < 11 ? allNames.length - 1 : 10;

      final names = allNames.sublist(0, splitIndex);
      final scores = allScores.sublist(0, splitIndex);
      final hintNames = allNames.sublist(splitIndex);

// The first item that didn't make the list is the baseline reference
      final double baselineScore = allScores.length > splitIndex ? allScores[splitIndex] : 0.0;

      _log("Baseline (first excluded item score): $baselineScore");

// Calculate percentages based on difference to the baseline score
      final rawValues = scores.map((s) => (s - baselineScore).clamp(0.0, double.infinity)).toList();
      final double totalRaw = rawValues.fold(0.0, (p, e) => p + e);

      List<double> percentages;
      if (totalRaw <= 0) {
        _log("Alle Scores gleich oder unter Baseline, gleiche Anteile verteilen.");
        final equal = 100.0 / names.length;
        percentages = List<double>.filled(names.length, equal);
      } else {
        percentages = rawValues.map((v) => (v / totalRaw) * 100.0).toList();
      }

      _log("Berechnete Prozentwerte (Summe: ${percentages.fold(0.0, (p, e) => p + e).toStringAsFixed(2)}%):");
      for (var i = 0; i < names.length; i++) {
        _log("  ${names[i]} -> ${percentages[i].toStringAsFixed(2)}%");
      }

// Build answerHint: original sourceString + reference items
      final hintBuffer = StringBuffer(sourceString);
      if (hintNames.isNotEmpty) {
        hintBuffer.write('\n\nReference items (not shown):');
        for (var i = 0; i < hintNames.length; i++) {
          hintBuffer.write('\n${splitIndex + i + 1}. ${hintNames[i]}');
        }
      }
      final String finalAnswerHint = hintBuffer.toString();

      setState(() => _loading = false);

      Navigator.of(context).pop({
        'information': names,
        'informationPercentage': percentages,
        'question': listTitle,
        'answerHint': finalAnswerHint,
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      _log("Fehler: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Import from Ranker"),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Gib die Ranker List URL ein (z.B. https://www.ranker.com/list/best-smells/jacob-shelton)"),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: "Ranker URL", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme
                  .of(context)
                  .colorScheme
                  .error)),
              if (_logs.isNotEmpty)
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(border: Border.all(color: Theme
                      .of(context)
                      .dividerColor)),
                  child: ListView(
                    children: _logs.map((l) =>
                        Text(l, style: Theme
                            .of(context)
                            .textTheme
                            .bodySmall)).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(), child: const Text("Abbrechen")),
        ElevatedButton(
          onPressed: _loading ? null : _import,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Import"),
        ),
      ],
    );
  }
}
