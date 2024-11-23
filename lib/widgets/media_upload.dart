import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../database/constants.dart';
import '../pages/games_categories.dart';

enum MediaUploadType {
  image(iconAdd: Icons.add_photo_alternate ,iconSuccess: Icons.image, iconError: Icons.image_not_supported,),
  music(iconAdd: MdiIcons.musicNotePlus,iconSuccess:  Icons.music_note, iconError: MdiIcons.musicNoteOff,);

  final IconData iconAdd;
  final IconData iconSuccess;
  final IconData iconError;

  const MediaUploadType({required this.iconAdd, required this.iconSuccess, required this.iconError});
}

class MediaUploadIconButton extends StatefulWidget {
  final MediaUploadType uploadType;
  final String gameId;
  final String? databaseMediaIndex;
  final Future<void> Function(dynamic) updateDB;

  const MediaUploadIconButton({
    super.key,
    required this.uploadType,
    required this.gameId,
    required this.databaseMediaIndex,
    required this.updateDB,
  });

  @override
  State<MediaUploadIconButton> createState() => _MediaUploadIconButtonState();
}

class _MediaUploadIconButtonState extends State<MediaUploadIconButton> {
  final storageRef = FirebaseStorage.instance.ref();
  Stream<TaskSnapshot>? uploadStream;
  bool? uploadSuccess;
  bool loading = false;

  bool initialized = false;
  late Directory appSupportDir;

  @override
  void initState() {
    () async {
      appSupportDir = await getApplicationSupportDirectory();
      setState(() {
        initialized = true;
      });
    }();
  }
  @override
  Widget build(BuildContext context) {
    if (!initialized) return CupertinoActivityIndicator();
    return IconButton(
      icon: loading
          ? const CupertinoActivityIndicator()
          : Icon(uploadSuccess == null && (widget.databaseMediaIndex == null || widget.databaseMediaIndex!.isEmpty)
              ? widget.uploadType.iconAdd
              : uploadSuccess ?? true
                  ? widget.uploadType.iconSuccess
                  : widget.uploadType.iconError),
      onPressed: loading
          ? null
          : uploadSuccess == null && (widget.databaseMediaIndex == null || widget.databaseMediaIndex!.isEmpty)
              ? () async {
                  final XFile? musicXFile = await openFile(
                      acceptedTypeGroups: <XTypeGroup>[Platform.isIOS ? musicUniformFileType : musicExtension]);
                  if (musicXFile == null) return;
                  setState(() {
                    uploadSuccess = null;
                    loading = true;
                  });
                  int index = await getGameMediaIndex(widget.gameId);
                  String filename = "$index.${musicXFile.path.split("/").last.split(".").last}";
                  final localFilePath = "${appSupportDir.absolute.path}/${widget.gameId}/$filename";
                  uploadStream =
                      storageRef.child("game_${widget.gameId}/$filename").putFile(File(musicXFile.path)).snapshotEvents;
                  uploadStream?.listen((event) {
                    switch (event.state) {
                      case TaskState.success:
                        widget.updateDB(filename);
                        musicXFile.saveTo(localFilePath);
                        setState(() {
                          loading = false;
                          uploadSuccess = true;
                        });
                        if (widget.databaseMediaIndex != null) {
                          storageRef.child("game_${widget.gameId}/${widget.databaseMediaIndex}").delete();
                        }
                        break;
                      case TaskState.error:
                        setState(() {
                          loading = false;
                          uploadSuccess = false;
                        });
                        break;
                      default:
                        break;
                    }
                  });
                }
              : () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                          icon: const Icon(Icons.delete),
                          title: const Text("Delete Sound"),
                          content: const Text("Are you sure you want to delete this sound?"),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                await widget.updateDB(FieldValue.delete());
                                uploadSuccess = null;
                                Navigator.of(context).pop();
                              },
                              child: const Text("Yes"),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text("No"),
                            )
                          ]);
                    },
                  ).then((value) => setState(() {}));
                },
    );
  }
}
