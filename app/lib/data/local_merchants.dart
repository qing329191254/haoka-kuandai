import 'package:haoka_app/api/api_client.dart';
import 'package:haoka_app/models/merchant.dart';
import 'package:haoka_app/models/order.dart';

/// 入驻商家：仅使用后端接口数据。
abstract final class LocalMerchants {
  static List<LocalMerchant> _items = [];

  static bool offline = false;
  static bool loaded = false;
  static String? loadError;

  static List<LocalMerchant> get items => List.unmodifiable(_items);

  static Future<void> refresh() async {
    try {
      final data = await Api.get('/api/merchants') as Map<String, dynamic>;
      _items = (data['items'] as List? ?? [])
          .map((e) => LocalMerchant.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((e) => e.id.isNotEmpty)
          .toList();
      loaded = true;
      offline = false;
      loadError = null;
    } catch (e) {
      offline = !loaded;
      loadError = e is ApiException ? e.message : '商家加载失败';
    }
  }

  static LocalMerchant? byId(String? id) {
    if (id == null) return null;
    for (final m in items) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// 某地级市已入驻、且可接该业务的商家。同区的排在前面。
  static List<LocalMerchant> inCity({
    required String province,
    required String city,
    required BizType bizType,
    String? preferDistrict,
  }) {
    final list = items
        .where((m) => m.coversCity(province, city) && m.accepts(bizType))
        .toList();
    if (preferDistrict != null && preferDistrict.isNotEmpty) {
      list.sort((a, b) {
        final aHit = a.district == preferDistrict ? 0 : 1;
        final bHit = b.district == preferDistrict ? 0 : 1;
        return aHit.compareTo(bHit);
      });
    }
    return list;
  }
}
