import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/models/order.dart';
import 'package:haoka_app/store/order_store.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/biz_visual.dart';

/// 异地商家 / 代理查看自己提交的订单（本地履约在小程序）。
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  OrderListFilter _filter = OrderListFilter.all;
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;

  static const _loadMoreExtent = 240.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OrderStore>().ensureFirstPage(_filter);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - _loadMoreExtent) {
      context.read<OrderStore>().loadMore(_filter);
    }
  }

  Future<void> _onFilter(OrderListFilter f) async {
    if (f == _filter) return;
    setState(() => _filter = f);
    await context.read<OrderStore>().ensureFirstPage(f);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      if (!mounted) return;
      await context.read<OrderStore>().search(value, _filter);
      if (!mounted) return;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Future<void> _clearSearch() async {
    _debounce?.cancel();
    _search.clear();
    await context.read<OrderStore>().search('', _filter);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Color _statusColor(OrderStatus s) => switch (s) {
    OrderStatus.done => const Color(0xFF2E7D32),
    OrderStatus.cancelled => const Color(0xFF9E9E9E),
    OrderStatus.followUp || OrderStatus.failed => const Color(0xFFC62828),
    OrderStatus.installing || OrderStatus.bossOpened => const Color(0xFFEF6C00),
    _ => AppStyle.brand,
  };

  String _subtitle(OrderStore store, OrderListSession session, int total) {
    if (!session.initialized || (session.loading && session.items.isEmpty)) {
      return '正在加载订单…';
    }
    if (store.keyword.isNotEmpty) {
      final n = store.countOf(_filter);
      return n == 0 ? '没有找到相关订单' : '找到 $n 笔相关订单';
    }
    return total == 0 ? '暂无订单，去首页提交业务即可' : '共 $total 笔订单，可搜索或按状态筛选';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<OrderStore>();
    final session = store.sessionOf(_filter);
    final list = session.items;
    final total = store.keyword.isEmpty
        ? store.countOf(OrderListFilter.all)
        : store.countOf(_filter);
    final showLoading =
        list.isEmpty && (!session.initialized || session.loading);

    if (!session.loading && !session.initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<OrderStore>().ensureFirstPage(_filter);
      });
    } else if (!session.loading && list.isEmpty && store.countOf(_filter) > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<OrderStore>().ensureFirstPage(_filter);
      });
    }

    return SoftPageScaffold(
      body: Column(
        children: [
          SoftPageHeader(
            title: '我的订单',
            subtitle: _subtitle(store, session, total),
          ),
          Material(
            color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      onSubmitted: (v) {
                        _debounce?.cancel();
                        context.read<OrderStore>().search(v, _filter);
                      },
                      decoration: InputDecoration(
                        hintText: '搜索订单号、姓名、手机号、套餐',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppStyle.subtitle,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: AppStyle.mutedIcon,
                        ),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '清除',
                                onPressed: _clearSearch,
                                icon: const Icon(
                                  Icons.cancel,
                                  size: 18,
                                  color: AppStyle.mutedIcon,
                                ),
                              ),
                        filled: true,
                        fillColor: const Color(0xFFF5F7FB),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: AppStyle.brand.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                      itemCount: OrderListFilter.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final f = OrderListFilter.values[i];
                        final selected = f == _filter;
                        final count = store.countOf(f);
                        final label = f == OrderListFilter.all
                            ? f.label
                            : (count > 0 ? '${f.label}$count' : f.label);
                        return GestureDetector(
                          onTap: () => _onFilter(f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppStyle.brand.withValues(alpha: 0.12)
                                  : const Color(0xFFF5F7FB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? AppStyle.brand.withValues(alpha: 0.35)
                                    : const Color(0xFFE8ECF1),
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.1,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? AppStyle.brand
                                    : AppStyle.title,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: showLoading
                  ? const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    )
                  : store.loadError != null && list.isEmpty
                  ? Center(
                      child: SoftCard(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('订单加载失败'),
                            const SizedBox(height: 8),
                            Text(
                              store.loadError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppStyle.subtitle,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => store.refresh(_filter),
                              child: const Text('重新加载'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : list.isEmpty
                  ? _EmptyState(
                      filter: _filter,
                      keyword: store.keyword,
                      onGoHome: () => context.go('/'),
                      onClearSearch: store.keyword.isEmpty
                          ? null
                          : _clearSearch,
                    )
                  : RefreshIndicator(
                      color: AppStyle.brand,
                      onRefresh: () => store.refresh(_filter),
                      child: ListView.separated(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: list.length + 1,
                        separatorBuilder: (_, i) {
                          if (i >= list.length - 1)
                            return const SizedBox.shrink();
                          return const SizedBox(height: 12);
                        },
                        itemBuilder: (context, i) {
                          if (i == list.length) {
                            return _ListFooter(
                              loadingMore: session.loadingMore,
                              hasMore: session.hasMore,
                            );
                          }
                          final o = list[i];
                          return _OrderTile(
                            order: o,
                            statusColor: _statusColor(o.status),
                            bizIcon: bizIcon(o.bizType),
                            onTap: () => context.push('/orders/${o.id}'),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.statusColor,
    required this.bizIcon,
    required this.onTap,
  });

  final AppOrder order;
  final Color statusColor;
  final IconData bizIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SoftIconTile(icon: bizIcon, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.productName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppStyle.title,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.bizLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppStyle.subtitle,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppStyle.divider),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.tag, size: 14, color: AppStyle.mutedIcon),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.assignedMerchantName != null
                      ? '${order.orderNo} · 履约 ${order.assignedMerchantName}'
                      : order.orderNo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppStyle.subtitle,
                  ),
                ),
              ),
              Text(
                order.customerName,
                style: const TextStyle(fontSize: 12, color: AppStyle.subtitle),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppStyle.chevron,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.loadingMore, required this.hasMore});

  final bool loadingMore;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '没有更多了',
            style: TextStyle(fontSize: 12, color: AppStyle.subtitle),
          ),
        ),
      );
    }
    return const SizedBox(height: 12);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filter,
    required this.keyword,
    required this.onGoHome,
    this.onClearSearch,
  });

  final OrderListFilter filter;
  final String keyword;
  final VoidCallback onGoHome;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final searching = keyword.isNotEmpty;
    final tip = searching
        ? '没有找到「$keyword」相关订单'
        : switch (filter) {
            OrderListFilter.all => '还没有订单，去首页提交业务吧',
            OrderListFilter.pending => '暂无待接单订单',
            OrderListFilter.processing => '暂无进行中的订单',
            OrderListFilter.done => '暂无已完成订单',
            OrderListFilter.failed => '暂无交付失败订单',
            OrderListFilter.cancelled => '暂无已取消订单',
          };

    return Center(
      child: SoftCard(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SoftIconTile(
              icon: searching
                  ? Icons.search_off_outlined
                  : Icons.receipt_long_outlined,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              tip,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppStyle.title,
              ),
            ),
            if (searching && onClearSearch != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onClearSearch,
                style: FilledButton.styleFrom(
                  backgroundColor: AppStyle.brand,
                  shape: const StadiumBorder(),
                  minimumSize: const Size(140, 40),
                ),
                child: const Text('清除搜索'),
              ),
            ] else if (filter == OrderListFilter.all) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onGoHome,
                style: FilledButton.styleFrom(
                  backgroundColor: AppStyle.brand,
                  shape: const StadiumBorder(),
                  minimumSize: const Size(140, 40),
                ),
                child: const Text('去办理'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
