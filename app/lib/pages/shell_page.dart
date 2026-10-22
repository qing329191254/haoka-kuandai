import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:haoka_app/services/app_update.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _bounceIndex = -1;
  int _bounceToken = 0;
  bool _forceChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _forceChecked) return;
      _forceChecked = true;
      AppUpdate.checkForceIfNeeded(context);
    });
  }

  void _onTap(int i) {
    setState(() {
      _bounceIndex = i;
      _bounceToken++;
    });
    // 同 Tab 再点回到根；切 Tab 保活（IndexedStack），避免客服页每次重建转圈
    widget.navigationShell.goBranch(
      i,
      initialLocation: i == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.navigationShell.currentIndex;
    final primary = Theme.of(context).colorScheme.primary;
    const inactive = Color(0xFF8A8F99);

    // 系统导航栏改白，并与底部 Tab 连成一体，避免露出主题蓝底边
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        // 与 SoftPageScaffold 顶部同色，避免子页透明时露出主题白底白线
        backgroundColor: const Color(0xFFD6E9FF),
        body: widget.navigationShell,
        bottomNavigationBar: ColoredBox(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Color(0xFFE8E8E8),
                ),
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      _TabItem(
                        label: '首页',
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        selected: selected == 0,
                        bounceToken: _bounceIndex == 0 ? _bounceToken : 0,
                        activeColor: primary,
                        inactiveColor: inactive,
                        onTap: () => _onTap(0),
                      ),
                      _TabItem(
                        label: '订单',
                        icon: Icons.receipt_long_outlined,
                        activeIcon: Icons.receipt_long,
                        selected: selected == 1,
                        bounceToken: _bounceIndex == 1 ? _bounceToken : 0,
                        activeColor: primary,
                        inactiveColor: inactive,
                        onTap: () => _onTap(1),
                      ),
                      _TabItem(
                        label: '客服',
                        icon: Icons.support_agent_outlined,
                        activeIcon: Icons.support_agent,
                        selected: selected == 2,
                        bounceToken: _bounceIndex == 2 ? _bounceToken : 0,
                        activeColor: primary,
                        inactiveColor: inactive,
                        onTap: () => _onTap(2),
                      ),
                      _TabItem(
                        label: '我的',
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        selected: selected == 3,
                        bounceToken: _bounceIndex == 3 ? _bounceToken : 0,
                        activeColor: primary,
                        inactiveColor: inactive,
                        onTap: () => _onTap(3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.bounceToken,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final int bounceToken;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _lift;

  @override
  void initState() {
    super.initState();
    // 弹簧感：放大 → 回弹过头 → 再弹 → 归位（比单段 ease 更有弹性）
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.14,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.14,
          end: 0.94,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.94,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.06,
          end: 0.98,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.98,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 16,
      ),
    ]).animate(_controller);

    _lift = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: -2.5,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -2.5,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: -1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -1,
          end: 0.4,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.4,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 16,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _TabItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bounceToken != 0 &&
        widget.bounceToken != oldWidget.bounceToken) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? widget.activeColor : widget.inactiveColor;
    return Expanded(
      child: InkWell(
        onTap: widget.onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _lift.value),
                  child: Transform.scale(scale: _scale.value, child: child),
                );
              },
              child: Icon(
                widget.selected ? widget.activeIcon : widget.icon,
                color: color,
                size: widget.selected ? 26 : 24,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutBack,
              style: TextStyle(
                fontSize: widget.selected ? 12.5 : 11.5,
                fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Text(widget.label),
            ),
          ],
        ),
      ),
    );
  }
}
