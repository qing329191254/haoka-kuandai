import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/store/auth_store.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/app_toast.dart';
import 'package:haoka_app/widgets/user_avatar.dart';

/// 个人信息总览（微信风格：点进子页修改）
class PersonalInfoPage extends StatelessWidget {
  const PersonalInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppStyle.pageBg,
        appBar: AppStyle.softAppBar('个人信息'),
        body: const Center(child: Text('未登录')),
      );
    }

    const valueStyle = TextStyle(fontSize: 16, color: AppStyle.subtitle);
    final emailText = user.email.trim().isEmpty ? '未设置' : user.email;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppStyle.pageBg,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppStyle.pageBg,
        appBar: AppStyle.softAppBar('个人信息'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            SoftCard(
              padding: EdgeInsets.zero,
              child: _SettingRow(
                label: '头像',
                onTap: () => context.push('/profile/info/avatar'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar.fromUser(user, radius: 22),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right,
                      color: AppStyle.chevron,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingRow(
                    label: '手机号',
                    trailing: Text(user.phone, style: valueStyle),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 16,
                    color: AppStyle.divider,
                  ),
                  _SettingRow(
                    label: '昵称',
                    onTap: () => context.push('/profile/info/nickname'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            user.nickname,
                            overflow: TextOverflow.ellipsis,
                            style: valueStyle,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppStyle.chevron,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 16,
                    color: AppStyle.divider,
                  ),
                  _SettingRow(
                    label: '性别',
                    onTap: () => context.push('/profile/info/gender'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(user.gender.label, style: valueStyle),
                        const Icon(
                          Icons.chevron_right,
                          color: AppStyle.chevron,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 16,
                    color: AppStyle.divider,
                  ),
                  _SettingRow(
                    label: '邮箱',
                    onTap: () => context.push('/profile/info/email'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            emailText,
                            overflow: TextOverflow.ellipsis,
                            style: valueStyle,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppStyle.chevron,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 0),
              child: Text(
                '手机号用于登录验证，暂不支持自行修改。如需更换请联系客服。\n本 App 仅供已通过审核的代理入驻账号提交与查看订单；本地履约请在小程序商家端处理。',
                style: TextStyle(
                  fontSize: 12,
                  color: AppStyle.subtitle,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 头像大图预览 + 更换（参考微信）
class AvatarPreviewPage extends StatefulWidget {
  const AvatarPreviewPage({super.key});

  @override
  State<AvatarPreviewPage> createState() => _AvatarPreviewPageState();
}

class _AvatarPreviewPageState extends State<AvatarPreviewPage> {
  final _picker = ImagePicker();

  Future<void> _hideKeyboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _changeAvatar() async {
    await _hideKeyboard();
    if (!mounted) return;

    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: false,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('拍照'),
                onTap: () => Navigator.pop(ctx, _AvatarAction.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择'),
                onTap: () => Navigator.pop(ctx, _AvatarAction.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: const Text('选择默认头像'),
                onTap: () => Navigator.pop(ctx, _AvatarAction.preset),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    await _hideKeyboard();
    if (!mounted) return;

    switch (action) {
      case _AvatarAction.camera:
        await _pickImage(ImageSource.camera);
      case _AvatarAction.gallery:
        await _pickImage(ImageSource.gallery);
      case _AvatarAction.preset:
        await _pickPresetAvatar();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      final err = await context.read<AuthStore>().updateProfile(
        avatarPath: file.path,
      );
      if (!mounted) return;
      if (err != null) {
        AppToast.error(context, err);
        return;
      }
      AppToast.success(context, '头像更换成功');
    } catch (_) {
      if (!mounted) return;
      AppToast.error(
        context,
        '无法打开${source == ImageSource.camera ? '相机' : '相册'}，请检查权限',
      );
    }
  }

  Future<void> _pickPresetAvatar() async {
    await _hideKeyboard();
    if (!mounted) return;
    final user = context.read<AuthStore>().user;
    if (user == null) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择默认头像',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: AvatarOption.presets.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (context, i) {
                    final opt = AvatarOption.presets[i];
                    final active =
                        opt.id == user.avatarId && user.avatarPath == null;
                    return InkWell(
                      onTap: () => Navigator.pop(ctx, opt.id),
                      borderRadius: BorderRadius.circular(40),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: UserAvatar(avatar: opt, radius: 28),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    final err = await context.read<AuthStore>().updateProfile(
      avatarId: selected,
      clearAvatarPath: true,
    );
    if (!mounted) return;
    if (err != null) {
      AppToast.error(context, err);
      return;
    }
    AppToast.success(context, '头像更换成功');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未登录')));
    }

    final path = user.avatarPath;
    final isNet =
        path != null &&
        (path.startsWith('http://') || path.startsWith('https://'));
    final hasFile =
        !isNet && path != null && path.isNotEmpty && File(path).existsSync();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('个人头像'),
          actions: [
            IconButton(
              tooltip: '更换头像',
              onPressed: _changeAvatar,
              icon: const Icon(Icons.more_horiz),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: isNet
                      ? Image.network(path, fit: BoxFit.cover)
                      : hasFile
                      ? Image.file(File(path), fit: BoxFit.cover)
                      : ColoredBox(
                          color: Color(user.avatar.color),
                          child: Center(
                            child: Text(
                              user.avatar.emoji,
                              style: const TextStyle(fontSize: 120),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _changeAvatar,
                    child: const Text('更换头像'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditNicknamePage extends StatefulWidget {
  const EditNicknamePage({super.key});

  @override
  State<EditNicknamePage> createState() => _EditNicknamePageState();
}

class _EditNicknamePageState extends State<EditNicknamePage> {
  late final TextEditingController _controller;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _controller = TextEditingController(
      text: context.read<AuthStore>().user?.nickname ?? '',
    );
    _ready = true;
  }

  @override
  void dispose() {
    if (_ready) _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      AppToast.tip(context, '昵称不能为空');
      return;
    }
    if (name.length > 20) {
      AppToast.tip(context, '昵称最多 20 个字');
      return;
    }
    final err = await context.read<AuthStore>().updateProfile(nickname: name);
    if (!mounted) return;
    if (err != null) {
      AppToast.error(context, err);
      return;
    }
    AppToast.success(context, '保存成功');
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar(
        '设置昵称',
        actions: [TextButton(onPressed: _save, child: const Text('完成'))],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 20,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '请输入昵称',
              counterText: '',
            ),
          ),
        ),
      ),
    );
  }
}

class EditEmailPage extends StatefulWidget {
  const EditEmailPage({super.key});

  @override
  State<EditEmailPage> createState() => _EditEmailPageState();
}

class _EditEmailPageState extends State<EditEmailPage> {
  late final TextEditingController _controller;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _controller = TextEditingController(
      text: context.read<AuthStore>().user?.email ?? '',
    );
    _ready = true;
  }

  @override
  void dispose() {
    if (_ready) _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _controller.text.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      AppToast.tip(context, '请输入正确的邮箱');
      return;
    }
    final err = await context.read<AuthStore>().updateProfile(email: email);
    if (!mounted) return;
    if (err != null) {
      AppToast.error(context, err);
      return;
    }
    AppToast.success(context, '保存成功');
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar(
        '设置邮箱',
        actions: [TextButton(onPressed: _save, child: const Text('完成'))],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '选填，用于接收通知',
            ),
          ),
        ),
      ),
    );
  }
}

class EditGenderPage extends StatelessWidget {
  const EditGenderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未登录')));
    }
    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar('设置性别'),
      body: Padding(
        padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
        child: SoftCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < UserGender.values.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 16,
                    color: AppStyle.divider,
                  ),
                InkWell(
                  onTap: () async {
                    final gender = UserGender.values[i];
                    final err = await context.read<AuthStore>().updateProfile(
                      gender: gender,
                    );
                    if (!context.mounted) return;
                    if (err != null) {
                      AppToast.error(context, err);
                      return;
                    }
                    AppToast.success(context, '保存成功');
                    if (context.canPop()) context.pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            UserGender.values[i].label,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppStyle.title,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          child: user.gender == UserGender.values[i]
                              ? const Icon(
                                  Icons.check,
                                  color: AppStyle.brand,
                                  size: 22,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _AvatarAction { camera, gallery, preset }

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.trailing, this.onTap});

  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: Color(0xFF333333)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
