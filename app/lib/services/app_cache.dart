import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// App 可安全清理的缓存（临时文件 / 系统缓存目录 / 内存图片缓存）。
/// 不清理 SharedPreferences（登录态）与用户文档目录业务文件。
abstract final class AppCache {
  static Future<List<Directory>> _targets() async {
    final dirs = <Directory>[
      await getTemporaryDirectory(),
      await getApplicationCacheDirectory(),
    ];
    return dirs;
  }

  static Future<int> _dirSizeBytes(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  static Future<int> sizeBytes() async {
    var total = 0;
    for (final dir in await _targets()) {
      total += await _dirSizeBytes(dir);
    }
    // 内存图片缓存粗略计入展示（清理时会清空）
    total += imageCache.currentSizeBytes;
    return total;
  }

  static Future<double> sizeMb() async {
    final bytes = await sizeBytes();
    return bytes / (1024 * 1024);
  }

  static Future<void> _clearDirectory(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// 清理磁盘临时/缓存目录 + Flutter 内存图片缓存。
  static Future<double> clear() async {
    for (final dir in await _targets()) {
      await _clearDirectory(dir);
    }
    imageCache.clear();
    imageCache.clearLiveImages();
    return sizeMb();
  }

  static String formatMb(double mb) {
    if (mb < 0.1) return '0 MB';
    if (mb < 10) return '${mb.toStringAsFixed(1)} MB';
    return '${mb.toStringAsFixed(0)} MB';
  }
}
