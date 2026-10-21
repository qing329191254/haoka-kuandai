import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haoka_app/data/products.dart';
import 'package:haoka_app/models/order.dart';
import 'package:haoka_app/widgets/app_surface.dart';

class StockTypeListPage extends StatefulWidget {
  const StockTypeListPage({super.key});

  @override
  State<StockTypeListPage> createState() => _StockTypeListPageState();
}

class _StockTypeListPageState extends State<StockTypeListPage> {
  bool _loading = !CatalogProducts.loaded;

  @override
  void initState() {
    super.initState();
    _ensureData();
  }

  Future<void> _ensureData() async {
    if (!CatalogProducts.loaded || CatalogProducts.offline) {
      setState(() => _loading = true);
      await CatalogProducts.refresh();
      if (!mounted) return;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final types = CatalogProducts.stockTypes;
    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar('存量业务'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppStyle.brand,
              onRefresh: () async {
                await CatalogProducts.refresh();
                if (mounted) setState(() {});
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Text(
                      '请选择存量业务类型，再挑选当地在售套餐。',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppStyle.subtitle,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (types.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              CatalogProducts.offline
                                  ? (CatalogProducts.loadError ?? '加载失败')
                                  : '暂无存量业务类型',
                              style: const TextStyle(color: AppStyle.subtitle),
                            ),
                            TextButton(
                              onPressed: _ensureData,
                              child: const Text('重新加载'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final t in types)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SoftCard(
                          padding: const EdgeInsets.all(14),
                          onTap: () => context.push(
                            '/catalog?type=stock&stockTypeId=${t.id}&stockTypeName=${Uri.encodeComponent(t.name)}',
                          ),
                          child: Row(
                            children: [
                              const SoftIconTile(
                                icon: Icons.layers_outlined,
                                size: 48,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppStyle.title,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t.description,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppStyle.subtitle,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${CatalogProducts.of(bizType: BizType.stock, stockTypeId: t.id).length} 个在售套餐',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppStyle.brand.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: AppStyle.chevron,
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}
