import 'dart:async';

import 'package:flutter/material.dart';
import 'package:haoka_app/widgets/app_surface.dart';

/// 全屏遮罩 Loading，风格对齐 AppToast / 品牌蓝
class AppLoading {
  static OverlayEntry? _entry;
  static int _depth = 0;
  /// 同步锁：挡住 Overlay 挂上前的同帧连点
  static bool _locked = false;

  static void show(BuildContext context, {String message = '加载中…'}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    if (_entry != null) {
      _depth += 1;
      return;
    }

    _depth = 1;
    _entry = OverlayEntry(
      builder: (ctx) => _LoadingLayer(message: message),
    );
    overlay.insert(_entry!);
  }

  static void hide() {
    _depth = (_depth - 1).clamp(0, 1 << 30);
    if (_depth > 0) return;
    _entry?.remove();
    _entry = null;
  }

  static Future<T> run<T>(
    BuildContext context,
    Future<T> Function() action, {
    String message = '加载中…',
  }) async {
    if (_locked) {
      return Completer<T>().future;
    }
    _locked = true;
    show(context, message: message);
    try {
      return await action();
    } finally {
      hide();
      _locked = false;
    }
  }
}

class _LoadingLayer extends StatelessWidget {
  const _LoadingLayer({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x61081428),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppStyle.brand.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppStyle.brand,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppStyle.title,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
