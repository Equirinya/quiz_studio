import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../database/constants.dart';
import '../pages/games_categories.dart';

enum MediaUploadType {
  image(
    uiString: "Image",
    iconAdd: Icons.add_photo_alternate,
    iconSuccess: Icons.image,
    iconError: Icons.image_not_supported,
    pickFile: _pickImage,
  ),
  music(
    uiString: "Sound",
    iconAdd: MdiIcons.musicNotePlus,
    iconSuccess: Icons.music_note,
    iconError: MdiIcons.musicNoteOff,
    pickFile: _pickMusic,
  );

  final IconData iconAdd;
  final IconData iconSuccess;
  final IconData iconError;
  final String uiString;
  final Future<XFile?> Function() pickFile;

  const MediaUploadType(
      {required this.uiString,
      required this.iconAdd,
      required this.iconSuccess,
      required this.iconError,
      required this.pickFile});
}

Future<XFile?> _pickImage() async => await ImagePicker().pickImage(source: ImageSource.gallery);

Future<XFile?> _pickMusic() async =>
    await openFile(acceptedTypeGroups: <XTypeGroup>[Platform.isIOS ? musicUniformFileType : musicExtension]);

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
    super.initState();
    () async {
      appSupportDir = await getApplicationSupportDirectory();
      setState(() {
        initialized = true;
      });
    }();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const CupertinoActivityIndicator();
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
                  XFile? xFile = await widget.uploadType.pickFile();
                  if (xFile == null) return;
                  setState(() {
                    uploadSuccess = null;
                    loading = true;
                  });
                  int index = await getGameMediaIndex(widget.gameId);
                  String filename = "$index.${xFile.path.split("/").last.split(".").last}";
                  final localFilePath = "${appSupportDir.absolute.path}/${widget.gameId}/$filename";
                  uploadStream =
                      storageRef.child("game_${widget.gameId}/$filename").putFile(File(xFile.path)).snapshotEvents;
                  uploadStream?.listen((event) {
                    switch (event.state) {
                      case TaskState.success:
                        widget.updateDB(filename);
                        xFile.saveTo(localFilePath);
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
                          title: Text("Delete ${widget.uploadType.uiString}"),
                          content: Text("Are you sure you want to delete this  ${widget.uploadType.uiString}?"),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                await widget.updateDB(null);
                                setState(() {
                                  uploadSuccess = null;
                                });
                                if(context.mounted) Navigator.of(context).pop();
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
