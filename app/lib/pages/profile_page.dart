import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/services/app_cache.dart';
import 'package:haoka_app/services/app_update.dart';
import 'package:haoka_app/store/auth_store.dart';
import 'package:haoka_app/widgets/app_toast.dart';
import 'package:haoka_app/widgets/user_avatar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _brand = Color(0xFF1E88E5);

  double _cacheMb = 0;
  bool _cacheLoading = true;
  bool _clearing = false;
  bool _checking = false;
  String _versionLabel = '…';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _refreshCacheSize();
  }

  Future<void> _loadVersion() async {
    await AppUpdate.ensureLocal();
    if (!mounted) return;
    setState(() => _versionLabel = AppUpdate.versionLabel);
  }

  Future<void> _refreshCacheSize() async {
    setState(() => _cacheLoading = true);
    final mb = await AppCache.sizeMb();
    if (!mounted) return;
    setState(() {
      _cacheMb = mb;
      _cacheLoading = false;
    });
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await AppUpdate.checkManual(context);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _clearCache() async {
    final sizeText = AppCache.formatMb(_cacheMb);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清理缓存'),
        content: Text(
          _cacheMb < 0.05
              ? '当前几乎没有可清理的缓存。'
              : '将清理约 $sizeText 缓存（临时文件、图片缓存等），不影响登录账号与订单数据。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      final left = await AppCache.clear();
      if (!mounted) return;
      setState(() {
        _cacheMb = left;
        _clearing = false;
      });
      AppToast.success(context, '缓存已清理');
    } catch (_) {
      if (!mounted) return;
      setState(() => _clearing = false);
      AppToast.tip(context, '清理失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未登录')));
    }

    final cacheLabel = _clearing
        ? '清理中…'
        : _cacheLoading
        ? '计算中…'
        : AppCache.formatMb(_cacheMb);
    final topPad = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 顶部浅蓝渐变 + 用户信息
            Container(
              padding: EdgeInsets.fromLTRB(20, topPad + 12, 12, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFD6E9FF),
                    Color(0xFFEEF5FF),
                    Color(0xFFF5F7FB),
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => context.push('/profile/info'),
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Color(0xFF5A6A7A),
                      ),
                      tooltip: '个人信息',
                    ),
                  ),
                  InkWell(
                    onTap: () => context.push('/profile/info'),
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: _brand.withValues(alpha: 0.18),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: UserAvatar.fromUser(user, radius: 32),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '你好，${user.nickname}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A2333),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '账号 ${user.phone}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF7A8699),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFFB0B8C4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 常用功能：蓝色圆角色块图标
                  _SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '常用功能',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A2333),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.receipt_long_outlined,
                                label: '我的订单',
                                onTap: () => context.go('/orders'),
                              ),
                            ),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.headset_mic_outlined,
                                label: '联系客服',
                                onTap: () => context.go('/service'),
                              ),
                            ),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.person_outline,
                                label: '个人信息',
                                onTap: () => context.push('/profile/info'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 列表菜单卡片
                  _SoftCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _MenuRow(
                          icon: Icons.help_outline,
                          title: '帮助中心',
                          onTap: () => context.push('/profile/help'),
                        ),
                        _MenuRow(
                          icon: Icons.feedback_outlined,
                          title: '意见反馈',
                          onTap: () => context.push('/profile/feedback'),
                        ),
                        _MenuRow(
                          icon: Icons.description_outlined,
                          title: '用户协议',
                          onTap: () => context.push('/profile/agreement'),
                        ),
                        _MenuRow(
                          icon: Icons.privacy_tip_outlined,
                          title: '隐私政策',
                          onTap: () => context.push('/profile/privacy'),
                        ),
                        _MenuRow(
                          icon: Icons.cleaning_services_outlined,
                          title: '清理缓存',
                          trailingText: cacheLabel,
                          onTap: _clearing ? () {} : _clearCache,
                        ),
                        _MenuRow(
                          icon: Icons.system_update_alt_outlined,
                          title: '检查更新',
                          trailingText: _checking ? '检查中…' : '当前 $_versionLabel',
                          showDivider: false,
                          onTap: _checking ? () {} : _checkUpdate,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 圆角胶囊退出按钮
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        context.read<AuthStore>().logout();
                        context.go('/login');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        '退出登录',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailingText,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? trailingText;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 22, color: const Color(0xFF8A94A6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF2A3344),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailingText != null) ...[
                  Text(
                    trailingText!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9AA3B2),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Color(0xFFC5CAD3),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 0.5,
            indent: 50,
            endIndent: 16,
            color: Color(0xFFEEF0F3),
          ),
      ],
    );
  }
}
