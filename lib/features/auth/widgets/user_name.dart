import 'package:flutter/material.dart';

import 'package:quiz_show/features/auth/user_service.dart';

/// The display name of a user, looked up by id.
class UserName extends StatelessWidget {
  const UserName(this.uid, {super.key, this.style});

  final String uid;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: UserService.instance.usernameOf(uid),
      builder: (context, snapshot) => Text(
        snapshot.connectionState != ConnectionState.done ? "…" : (snapshot.data ?? "Unknown user"),
        style: style,
      ),
    );
  }
}
