import 'dart:convert';

import 'package:flutter/services.dart';

/// 省 / 市 / 区 三级区划节点
class RegionNode {
  const RegionNode(this.name, [this.children = const []]);

  final String name;
  final List<RegionNode> children;

  factory RegionNode.fromJson(Map<String, dynamic> json) {
    final raw = json['children'];
    final children = raw is List
        ? raw
              .whereType<Map>()
              .map((e) => RegionNode.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
        : const <RegionNode>[];
    return RegionNode(json['name'] as String? ?? '', children);
  }
}

class RegionSelection {
  const RegionSelection({
    required this.province,
    required this.city,
    required this.district,
  });

  final String province;
  final String city;
  final String district;

  String get label => '$province $city $district';

  String get cityKey => '$province-$city';
}

/// 全国省市区数据（assets/regions/china_pca.json，来源 china-division）。
abstract final class ChinaRegions {
  static List<RegionNode> _tree = const [];
  static Future<void>? _loading;

  static List<RegionNode> get tree => _tree;

  static bool get isReady => _tree.isNotEmpty;

  /// 应用启动或打开选择器前调用；可重复调用，只会加载一次。
  static Future<void> ensureLoaded() {
    if (_tree.isNotEmpty) return Future<void>.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/regions/china_pca.json');
    final list = jsonDecode(raw) as List<dynamic>;
    _tree = list
        .whereType<Map>()
        .map((e) => RegionNode.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  static int provinceIndexOf(String name) {
    final i = _tree.indexWhere((e) => e.name == name);
    return i < 0 ? 0 : i;
  }
}
