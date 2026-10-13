import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:quiz_show/core/widgets/dialogs.dart';
import 'package:quiz_show/features/games/game_repository.dart';
import 'package:quiz_show/features/games/media_service.dart';
import 'package:quiz_show/features/games/widgets/map_editor.dart';
import 'package:quiz_show/features/games/widgets/media_button.dart';

/// The map of one category group, to arrange by hand.
class MapEditorPage extends StatefulWidget {
  const MapEditorPage({super.key, required this.gameId, required this.groupId});

  final String gameId;
  final String groupId;

  @override
  State<MapEditorPage> createState() => _MapEditorPageState();
}

class _MapEditorPageState extends State<MapEditorPage> {
  late final Stream<GameSnapshot> _game = GameRepository.instance.watchGame(widget.gameId);

  Future<String?> _pickImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await MediaKind.image.pick();
    if (path == null) return null;
    try {
      return await MediaService.instance.upload(widget.gameId, path);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Could not upload the picture.")));
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameSnapshot>(
      stream: _game,
      builder: (context, snapshot) {
        final group = snapshot.data?.content.group(widget.groupId);
        return Scaffold(
          appBar: AppBar(title: Text(group == null ? "Map" : "Map · ${group.name}")),
          body: snapshot.hasError || (snapshot.hasData && group == null)
              ? const Center(child: Text("This group is not available."))
              : group == null
                  ? const Center(child: CupertinoActivityIndicator())
                  : SafeArea(
                      child: MapEditor(
                        group: group,
                        imageFile: (name) {
                          final file = MediaService.instance.localFile(widget.gameId, name);
                          // A picture added elsewhere is fetched on first sight.
                          if (!file.existsSync()) {
                            MediaService.instance.ensureCached(widget.gameId, name).then((_) {
                              if (mounted) setState(() {});
                            }, onError: (Object _) {});
                            return null;
                          }
                          return file;
                        },
                        pickImage: _pickImage,
                        onSave: (layout) => guarded(
                          context,
                          () => GameRepository.instance.updateGroup(widget.gameId, widget.groupId, {'mapLayout': layout}),
                        ),
                      ),
                    ),
        );
      },
    );
  }
}
