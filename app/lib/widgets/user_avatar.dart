import 'dart:io';

import 'package:flutter/material.dart';
import 'package:haoka_app/store/auth_store.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatar,
    this.radius = 28,
    this.imagePath,
  });

  /// 从用户资料构建（优先本地图片）
  factory UserAvatar.fromUser(
    UserProfile user, {
    Key? key,
    double radius = 28,
  }) {
    return UserAvatar(
      key: key,
      avatar: user.avatar,
      radius: radius,
      imagePath: user.avatarPath,
    );
  }

  final AvatarOption avatar;
  final double radius;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final isNet = path != null && (path.startsWith('http://') || path.startsWith('https://'));
    final hasFile =
        !isNet && path != null && path.isNotEmpty && File(path).existsSync();

    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(avatar.color),
      backgroundImage: isNet
          ? NetworkImage(path)
          : hasFile
          ? FileImage(File(path))
          : null,
      child: (isNet || hasFile)
          ? null
          : Text(avatar.emoji, style: TextStyle(fontSize: radius * 0.85)),
    );
  }
}
