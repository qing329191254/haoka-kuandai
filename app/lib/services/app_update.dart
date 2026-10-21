import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:haoka_app/api/api_client.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/app_toast.dart';

class AppVersionInfo {
  const AppVersionInfo({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.forceUpdate,
    required this.title,
    required this.releaseNotes,
    required this.androidUrl,
    required this.iosUrl,
    required this.enabled,
  });

  final String latestVersion;
  final String minSupportedVersion;
  final bool forceUpdate;
  final String title;
  final String releaseNotes;
  final String androidUrl;
  final String iosUrl;
  final bool enabled;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      latestVersion: '${json['latestVersion'] ?? '1.0.0'}'.trim(),
      minSupportedVersion: '${json['minSupportedVersion'] ?? '1.0.0'}'.trim(),
      forceUpdate: json['forceUpdate'] == true,
      title: '${json['title'] ?? '发现新版本'}'.trim(),
      releaseNotes: '${json['releaseNotes'] ?? ''}'.trim(),
      androidUrl: '${json['androidUrl'] ?? ''}'.trim(),
      iosUrl: '${json['iosUrl'] ?? ''}'.trim(),
      enabled: json['enabled'] != false,
    );
  }

  String get updateUrl {
    if (Platform.isIOS) return iosUrl;
    return androidUrl;
  }
}

abstract final class AppUpdate {
  static PackageInfo? _info;
  static AppVersionInfo? _remote;

  static String get version => _info?.version ?? '—';
  static String get buildNumber => _info?.buildNumber ?? '';
  static String get versionLabel {
    final v = version;
    if (v == '—') return v;
    final b = buildNumber;
    return b.isEmpty ? 'V$v' : 'V$v ($b)';
  }

  static Future<PackageInfo> ensureLocal() async {
    return _info ??= await PackageInfo.fromPlatform();
  }

  static Future<AppVersionInfo?> fetchRemote() async {
    try {
      final data = Map<String, dynamic>.from(
        await Api.get('/api/content/app-version') as Map,
      );
      _remote = AppVersionInfo.fromJson(data);
      return _remote;
    } catch (_) {
      return _remote;
    }
  }

  /// a < b → -1；相等 → 0；a > b → 1
  static int compareVersion(String a, String b) {
    final pa = a
        .split(RegExp(r'[^\d]+'))
        .where((e) => e.isNotEmpty)
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final pb = b
        .split(RegExp(r'[^\d]+'))
        .where((e) => e.isNotEmpty)
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x < y ? -1 : 1;
    }
    return 0;
  }

  static bool needUpdate(AppVersionInfo remote, String local) {
    if (!remote.enabled) return false;
    return compareVersion(local, remote.latestVersion) < 0;
  }

  static bool mustForce(AppVersionInfo remote, String local) {
    if (!remote.enabled) return false;
    if (compareVersion(local, remote.minSupportedVersion) < 0) return true;
    return remote.forceUpdate && needUpdate(remote, local);
  }

  static Future<void> openUpdateUrl(BuildContext context, AppVersionInfo remote) async {
    final url = remote.updateUrl;
    if (url.isEmpty) {
      AppToast.tip(
        context,
        Platform.isIOS ? 'iOS 更新链接暂未配置，请联系运营获取新版' : '下载地址暂未配置，请联系运营获取安装包',
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      AppToast.tip(context, '更新链接无效');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) AppToast.tip(context, '无法打开更新链接');
  }

  /// 手动检查：返回是否已处理弹窗。
  static Future<void> checkManual(BuildContext context) async {
    await ensureLocal();
    final remote = await fetchRemote();
    if (!context.mounted) return;
    if (remote == null) {
      AppToast.tip(context, '暂时无法检查更新，请稍后重试');
      return;
    }
    if (!remote.enabled) {
      _showInfo(context, '检查更新暂未开放');
      return;
    }
    final local = version;
    if (!needUpdate(remote, local)) {
      _showInfo(context, '当前已是最新版本 $versionLabel');
      return;
    }
    await showUpdateDialog(
      context,
      remote: remote,
      localVersion: local,
      force: mustForce(remote, local),
    );
  }

  /// 启动后静默检查：仅强制更新时拦截。
  static Future<void> checkForceIfNeeded(BuildContext context) async {
    await ensureLocal();
    final remote = await fetchRemote();
    if (!context.mounted || remote == null) return;
    final local = version;
    if (!mustForce(remote, local)) return;
    await showUpdateDialog(
      context,
      remote: remote,
      localVersion: local,
      force: true,
    );
  }

  static void _showInfo(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('检查更新'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
        ],
      ),
    );
  }

  static Future<void> showUpdateDialog(
    BuildContext context, {
    required AppVersionInfo remote,
    required String localVersion,
    required bool force,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) => PopScope(
        canPop: !force,
        child: AlertDialog(
          title: Text(remote.title.isEmpty ? '发现新版本' : remote.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前 $localVersion  →  最新 ${remote.latestVersion}',
                style: const TextStyle(fontSize: 13, color: AppStyle.subtitle),
              ),
              if (remote.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(remote.releaseNotes, style: const TextStyle(height: 1.45)),
              ],
              if (force) ...[
                const SizedBox(height: 10),
                const Text(
                  '当前版本过旧，请更新后再使用。',
                  style: TextStyle(color: Color(0xFFC62828), fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('稍后再说'),
              ),
            FilledButton(
              onPressed: () async {
                await openUpdateUrl(ctx, remote);
                if (force) return;
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('立即更新'),
            ),
          ],
        ),
      ),
    );
  }
}
