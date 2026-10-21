import 'package:flutter/material.dart';

enum AppToastType { tip, success, error }

/// 居中浮层提示（类微信轻提示），不走 Material SnackBar 默认样式
class AppToast {
  static OverlayEntry? _entry;

  static void tip(BuildContext context, String message) =>
      show(context, message, type: AppToastType.tip);

  static void success(BuildContext context, String message) =>
      show(context, message, type: AppToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: AppToastType.error);

  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.tip,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _entry?.remove();
    _entry = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => IgnorePointer(
        child: _ToastLayer(
          message: message,
          type: type,
          onDismissed: () {
            if (_entry == entry) {
              entry.remove();
              _entry = null;
            }
          },
          duration: duration,
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }
}

class _ToastLayer extends StatefulWidget {
  const _ToastLayer({
    required this.message,
    required this.type,
    required this.onDismissed,
    required this.duration,
  });

  final String message;
  final AppToastType type;
  final VoidCallback onDismissed;
  final Duration duration;

  @override
  State<_ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<_ToastLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    Future<void>.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.type) {
    AppToastType.tip => Icons.info_outline_rounded,
    AppToastType.success => Icons.check_rounded,
    AppToastType.error => Icons.close_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: const Alignment(0, 0.12),
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280, minWidth: 120),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  color: const Color(0xE61A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icon, color: Colors.white, size: 28),
                    const SizedBox(height: 10),
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
