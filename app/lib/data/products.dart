import 'package:haoka_app/api/api_client.dart';
import 'package:haoka_app/models/order.dart';
import 'package:haoka_app/models/product.dart';

/// 套餐目录：仅使用后端接口数据。
abstract final class CatalogProducts {
  static List<CatalogProduct> _items = [];
  static List<StockBizType> _stockTypes = [];

  static bool offline = false;
  static bool loaded = false;
  static String? loadError;

  static List<CatalogProduct> get items => List.unmodifiable(_items);

  static List<StockBizType> get stockTypes => List.unmodifiable(_stockTypes);

  static Future<void> refresh() async {
    try {
      final results = await Future.wait([
        Api.get('/api/products'),
        Api.get('/api/stock-types'),
      ]);
      final data = Map<String, dynamic>.from(results[0] as Map);
      final types = Map<String, dynamic>.from(results[1] as Map);
      _items = (data['items'] as List? ?? [])
          .map((e) => CatalogProduct.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((e) => e.id.isNotEmpty)
          .toList();
      _stockTypes = (types['items'] as List? ?? [])
          .map((e) => StockBizType.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((e) => e.id.isNotEmpty)
          .toList();
      loaded = true;
      offline = false;
      loadError = null;
    } catch (e) {
      offline = !loaded;
      loadError = e is ApiException ? e.message : '套餐加载失败';
    }
  }

  static List<CatalogProduct> of({
    required BizType bizType,
    String? stockTypeId,
    String? city,
  }) {
    return items.where((p) {
      if (p.bizType != bizType) return false;
      if (stockTypeId != null && p.stockTypeId != stockTypeId) return false;
      if (city != null && city.isNotEmpty && p.city != city) return false;
      return true;
    }).toList();
  }

  static List<String> citiesOf({
    required BizType bizType,
    String? stockTypeId,
  }) {
    final set = <String>{};
    for (final p in of(bizType: bizType, stockTypeId: stockTypeId)) {
      if (p.city.isNotEmpty) set.add(p.city);
    }
    return set.toList();
  }

  static CatalogProduct? byId(String id) {
    for (final p in items) {
      if (p.id == id) return p;
    }
    return null;
  }
}
