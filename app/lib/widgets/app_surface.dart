import 'package:flutter/material.dart';

/// 与「我的」页统一的视觉 token
abstract final class AppStyle {
  static const brand = Color(0xFF1E88E5);
  static const pageBg = Color(0xFFF5F7FB);
  static const title = Color(0xFF1A2333);
  static const subtitle = Color(0xFF7A8699);
  static const mutedIcon = Color(0xFF8A94A6);
  static const chevron = Color(0xFFC5CAD3);
  static const divider = Color(0xFFEEF0F3);

  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFD6E9FF), Color(0xFFEEF5FF), pageBg],
    stops: [0, 0.55, 1],
  );

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: brand.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static InputDecoration softInput({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: brand, width: 1.2),
      ),
    );
  }

  static AppBar softAppBar(String pageTitle, {List<Widget>? actions}) {
    return AppBar(
      title: Text(pageTitle),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      foregroundColor: AppStyle.title,
      actions: actions,
    );
  }

  static ButtonStyle get primaryPill => FilledButton.styleFrom(
    backgroundColor: brand,
    foregroundColor: Colors.white,
    elevation: 0,
    minimumSize: const Size.fromHeight(48),
    shape: const StadiumBorder(),
  );
}

/// 圆角白卡片 + 轻阴影
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppStyle.softShadow,
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

/// 顶部渐变标题区（用于 Tab 页）
class SoftPageHeader extends StatelessWidget {
  const SoftPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 16, 16, 20),
      decoration: const BoxDecoration(gradient: AppStyle.pageGradient),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppStyle.title,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppStyle.subtitle,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 蓝色渐变圆角方块图标
class SoftIconTile extends StatelessWidget {
  const SoftIconTile({super.key, required this.icon, this.size = 48});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppStyle.brand.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}
