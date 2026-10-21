import 'package:flutter/foundation.dart';
import 'package:haoka_app/api/api_client.dart';
import 'package:haoka_app/models/order.dart';

/// 单筛选项下的分页会话（UI 按需构建 + 数据按页拉取）。
class OrderListSession {
  OrderListSession();

  final List<AppOrder> items = [];
  int nextPage = 0;
  bool hasMore = true;
  bool loading = false;
  bool loadingMore = false;

  /// 是否已完成过至少一次首屏拉取（避免首进闪空态）。
  bool initialized = false;
}

/// 订单数据：列表按筛选项分页；数据来自后端。
class OrderStore extends ChangeNotifier {
  /// 每页条数，接后端时与接口 pageSize 对齐即可。
  static const int pageSize = 10;

  List<AppOrder> _all = [];
  String _keyword = '';
  String? loadError;

  final Map<OrderListFilter, OrderListSession> _sessions = {
    for (final f in OrderListFilter.values) f: OrderListSession(),
  };

  List<AppOrder> get orders => List.unmodifiable(_all);

  String get keyword => _keyword;

  OrderListSession sessionOf(OrderListFilter filter) => _sessions[filter]!;

  List<AppOrder> visibleOf(OrderListFilter filter) =>
      List.unmodifiable(sessionOf(filter).items);

  int countOf(OrderListFilter filter) {
    return _filtered(filter).length;
  }

  Iterable<AppOrder> _filtered(OrderListFilter filter) {
    var list = _all.where((o) => filter.matches(o.status));
    if (_keyword.isNotEmpty) {
      list = list.where((o) => o.matchesSearch(_keyword));
    }
    return list;
  }

  void _resetSessions() {
    for (final s in _sessions.values) {
      s
        ..items.clear()
        ..nextPage = 0
        ..hasMore = true
        ..loading = false
        ..loadingMore = false
        ..initialized = false;
    }
  }

  /// 搜索订单号、姓名、手机号、套餐等；会重置各筛选项分页。
  Future<void> search(String keyword, OrderListFilter filter) async {
    final k = keyword.trim();
    if (_keyword == k) return;
    _keyword = k;
    _resetSessions();
    await refresh(filter);
  }

  /// 进入列表或切换筛选项时调用：已有数据则复用，否则拉第一页。
  Future<void> ensureFirstPage(OrderListFilter filter) async {
    final s = sessionOf(filter);
    if (s.items.isNotEmpty || s.loading) return;
    await refresh(filter);
  }

  Future<void> refresh(OrderListFilter filter) async {
    final s = sessionOf(filter);
    if (s.loading) return;
    s
      ..loading = true
      ..loadingMore = false
      ..items.clear()
      ..nextPage = 0
      ..hasMore = true;
    loadError = null;
    notifyListeners();

    try {
      final page = await _fetchPage(filter, 0);
      s
        ..items.addAll(page.items)
        ..nextPage = 1
        ..hasMore = page.hasMore;
    } on ApiException catch (e) {
      loadError = e.message;
      s.hasMore = false;
    } finally {
      s
        ..loading = false
        ..initialized = true;
      notifyListeners();
    }
  }

  /// 列表触底时调用；无更多或正在加载时直接返回。
  Future<void> loadMore(OrderListFilter filter) async {
    final s = sessionOf(filter);
    if (!s.hasMore || s.loading || s.loadingMore) return;

    s.loadingMore = true;
    notifyListeners();

    try {
      final page = await _fetchPage(filter, s.nextPage);
      s
        ..items.addAll(page.items)
        ..nextPage += 1
        ..hasMore = page.hasMore;
    } finally {
      s.loadingMore = false;
      notifyListeners();
    }
  }

  Future<({List<AppOrder> items, bool hasMore})> _fetchPage(
    OrderListFilter filter,
    int page,
  ) async {
    if (page == 0) {
      try {
        final data = await Api.get(
          '/api/app/orders',
          query: {'keyword': _keyword},
        );
        final list = (data['items'] as List? ?? [])
            .map((e) => AppOrder.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _all = list;
        loadError = null;
      } on ApiException catch (e) {
        loadError = e.message;
        rethrow;
      }
    }

    final all = _filtered(filter).toList(growable: false);
    final start = page * pageSize;
    if (start >= all.length) {
      return (items: <AppOrder>[], hasMore: false);
    }
    final end = (start + pageSize).clamp(0, all.length);
    final slice = all.sublist(start, end);
    return (items: slice, hasMore: end < all.length);
  }

  Future<String?> addOrder({
    required BizType bizType,
    required String customerName,
    required String customerPhone,
    required String address,
    required String productName,
    required String carrier,
    String? productId,
    String? remark,
    String? province,
    String? city,
    String? district,
    String? assignedMerchantId,
    String? assignedMerchantName,
    String? createdByUserId,
    String? stockTypeId,
    String? stockTypeName,
    double? commission,
    String? orderIntent,
    String? phoneBrand,
    String? priceRange,
    String? wifiDeviceType,
    String? wifiBizMode,
    String? customerIdNo,
  }) async {
    try {
      final data = await Api.post('/api/app/orders', {
        'bizType': bizType.apiValue,
        'productId': productId ?? '',
        'productName': productName,
        'carrier': carrier,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerIdNo': customerIdNo ?? '',
        'address': address,
        'province': province ?? '',
        'city': city ?? '',
        'district': district ?? '',
        'assignedMerchantId': assignedMerchantId ?? '',
        'remark': remark ?? '',
        'stockTypeId': stockTypeId ?? '',
        'stockTypeName': stockTypeName ?? '',
        'orderIntent': orderIntent ?? '',
        'phoneBrand': phoneBrand ?? '',
        'priceRange': priceRange ?? '',
        'wifiDeviceType': wifiDeviceType ?? '',
        'wifiBizMode': wifiBizMode ?? '',
        'commission': commission ?? 0,
      });
      final order = AppOrder.fromJson(Map<String, dynamic>.from(data as Map));
      _all.insert(0, order);
      _resetSessions();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  AppOrder? findById(String id) {
    try {
      return _all.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<AppOrder?> fetchById(String id) async {
    try {
      final data = await Api.get('/api/app/orders/$id');
      final order = AppOrder.fromJson(Map<String, dynamic>.from(data as Map));
      final i = _all.indexWhere((o) => o.id == order.id);
      if (i >= 0) {
        _all[i] = order;
      } else {
        _all.insert(0, order);
      }
      notifyListeners();
      return order;
    } on ApiException {
      return findById(id);
    }
  }

  void clear() {
    _all = [];
    loadError = null;
    _keyword = '';
    _resetSessions();
    notifyListeners();
  }
}
