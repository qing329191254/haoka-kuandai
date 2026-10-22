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
    required this.title,
    required this.releaseNotes,
    required this.iosStoreUrl,
    required this.enabled,
  });

  final String latestVersion;
  final String minSupportedVersion;
  final String title;
  final String releaseNotes;
  /// App Store 详情页（上架后填一次即可）
  final String iosStoreUrl;
  final bool enabled;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      latestVersion: '${json['latestVersion'] ?? '1.0.0'}'.trim(),
      minSupportedVersion: '${json['minSupportedVersion'] ?? '1.0.0'}'.trim(),
      title: '${json['title'] ?? '发现新版本'}'.trim(),
      releaseNotes: '${json['releaseNotes'] ?? ''}'.trim(),
      iosStoreUrl: '${json['iosUrl'] ?? json['iosStoreUrl'] ?? ''}'.trim(),
      enabled: json['enabled'] != false,
    );
  }
}

/// 仅商店更新：强制时弹窗拦路并跳转商店；非强制由用户手动「检查更新」。
abstract final class AppUpdate {
  static PackageInfo? _info;
  static AppVersionInfo? _remote;

  static String get version => _info?.version ?? '—';
  static String get buildNumber => _info?.buildNumber ?? '';
  static String get packageName => _info?.packageName ?? '';
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

  /// 仅当本地低于「最低可用版本」时强制（严重问题调高该版本号）。
  static bool mustForce(AppVersionInfo remote, String local) {
    if (!remote.enabled) return false;
    return compareVersion(local, remote.minSupportedVersion) < 0;
  }

  /// 跳转应用商店（Android 按包名；iOS 用后台配置的 App Store 链接）。
  static Future<void> openStore(BuildContext context, AppVersionInfo remote) async {
    await ensureLocal();
    if (!context.mounted) return;

    if (Platform.isIOS) {
      final raw = remote.iosStoreUrl;
      if (raw.isEmpty) {
        AppToast.tip(context, 'App Store 链接暂未配置');
        return;
      }
      final uri = Uri.tryParse(raw);
      if (uri == null) {
        AppToast.tip(context, '商店链接无效');
        return;
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!context.mounted) return;
      if (!ok) AppToast.tip(context, '无法打开应用商店，请稍后重试');
      return;
    }

    final id = packageName;
    if (id.isEmpty) {
      AppToast.tip(context, '无法获取应用包名');
      return;
    }
    // 优先唤起本机应用商店；失败再试 Play 网页
    final market = Uri.parse('market://details?id=$id');
    if (await canLaunchUrl(market)) {
      final ok = await launchUrl(market, mode: LaunchMode.externalApplication);
      if (!context.mounted) return;
      if (!ok) AppToast.tip(context, '无法打开应用商店');
      return;
    }
    final play = Uri.parse('https://play.google.com/store/apps/details?id=$id');
    final ok = await launchUrl(play, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) AppToast.tip(context, '无法打开应用商店，请稍后重试');
  }

  /// 手动检查：有新版本可跳转商店；非强制可取消。
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
    final title = remote.title.isEmpty
        ? (force ? '版本过低' : '发现新版本')
        : remote.title;
    final body = force
        ? '您当前使用的版本过低，请更新至最新版本后再使用。'
        : (remote.releaseNotes.isNotEmpty
            ? remote.releaseNotes
            : '检测到新版本 ${remote.latestVersion}，建议前往应用商店更新。');

    return showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) => PopScope(
        canPop: !force,
        child: AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body, style: const TextStyle(height: 1.45)),
              const SizedBox(height: 10),
              Text(
                '当前 $localVersion  →  最新 ${remote.latestVersion}',
                style: const TextStyle(fontSize: 13, color: AppStyle.subtitle),
              ),
              if (force && remote.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  remote.releaseNotes,
                  style: const TextStyle(height: 1.45, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
            FilledButton(
              onPressed: () async {
                await openStore(ctx, remote);
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
