import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haoka_app/data/products.dart';
import 'package:haoka_app/models/order.dart';
import 'package:haoka_app/models/product.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/carrier_picker.dart';

class CatalogProductListPage extends StatefulWidget {
  const CatalogProductListPage({
    super.key,
    required this.bizType,
    this.stockTypeId,
    this.stockTypeName,
  });

  final BizType bizType;
  final String? stockTypeId;
  final String? stockTypeName;

  @override
  State<CatalogProductListPage> createState() => _CatalogProductListPageState();
}

class _CatalogProductListPageState extends State<CatalogProductListPage> {
  String _city = '全部';
  String _carrier = '全部';
  String _deviceType = '全部';
  String _bizMode = '全部';
  bool _loading = !CatalogProducts.loaded;

  bool get _isWifi => widget.bizType == BizType.wifi;

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

  List<CatalogProduct> get _base => CatalogProducts.of(
    bizType: widget.bizType,
    stockTypeId: widget.stockTypeId,
  );

  List<String> get _cities => [
    '全部',
    ...CatalogProducts.citiesOf(
      bizType: widget.bizType,
      stockTypeId: widget.stockTypeId,
    ),
  ];

  List<String> get _carriers {
    final set = <String>{};
    for (final p in _base) {
      set.add(p.carrier);
    }
    return ['全部', ...set];
  }

  List<CatalogProduct> get _filtered {
    return _base.where((p) {
      if (_city != '全部' && p.city != _city) return false;
      if (_carrier != '全部' && p.carrier != _carrier) return false;
      if (_isWifi && _deviceType != '全部' && p.wifiDeviceType != _deviceType)
        return false;
      if (_isWifi && _bizMode != '全部' && p.wifiBizMode != _bizMode)
        return false;
      return true;
    }).toList();
  }

  String get _title {
    if (widget.stockTypeName != null) return widget.stockTypeName!;
    return '${widget.bizType.label}套餐';
  }

  @override
  Widget build(BuildContext context) {
    final products = _filtered;
    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar(_title),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '选择${widget.bizType.label}套餐',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppStyle.title,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CatalogProducts.offline
                            ? '网络异常，请下拉重试加载套餐。'
                            : _isWifi
                            ? '可按 4G / 5G、买断或租赁筛选当地套餐。'
                            : '套餐按城市上架，请先选择办理城市。',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppStyle.subtitle,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_base.isNotEmpty) ...[
                  _ChipRow(
                    items: _cities,
                    selected: _city,
                    onSelect: (v) => setState(() => _city = v),
                  ),
                  _ChipRow(
                    items: _carriers,
                    selected: _carrier,
                    onSelect: (v) => setState(() => _carrier = v),
                    accentFor: carrierAccent,
                  ),
                  if (_isWifi) ...[
                    _ChipRow(
                      items: const ['全部', '4G', '5G'],
                      selected: _deviceType,
                      onSelect: (v) => setState(() => _deviceType = v),
                    ),
                    _ChipRow(
                      items: const ['全部', '买断', '租赁'],
                      selected: _bizMode,
                      onSelect: (v) => setState(() => _bizMode = v),
                    ),
                  ],
                ],
                Expanded(
                  child: RefreshIndicator(
                    color: AppStyle.brand,
                    onRefresh: () async {
                      await CatalogProducts.refresh();
                      if (mounted) setState(() {});
                    },
                    child: products.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.sizeOf(context).height * 0.35,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        CatalogProducts.offline
                                            ? (CatalogProducts.loadError ??
                                                  '加载失败')
                                            : '暂无在售套餐',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppStyle.subtitle,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _ensureData,
                                        child: const Text('重新加载'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                            itemCount: products.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) =>
                                _ProductCard(product: products[i]),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.items,
    required this.selected,
    required this.onSelect,
    this.accentFor,
  });

  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelect;
  final Color Function(String)? accentFor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final f = items[i];
          final isOn = f == selected;
          final accent = f == '全部' || accentFor == null
              ? AppStyle.brand
              : accentFor!(f);
          return GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isOn
                    ? accent.withValues(alpha: 0.12)
                    : const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isOn
                      ? accent.withValues(alpha: 0.4)
                      : const Color(0xFFE8ECF1),
                ),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isOn ? FontWeight.w700 : FontWeight.w500,
                  color: isOn ? accent : AppStyle.title,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final accent = carrierAccent(product.carrier);
    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/catalog/purchase?id=${product.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SoftIconTile(icon: Icons.inventory_2_outlined, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppStyle.title,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Tag(text: product.cityLabel, color: AppStyle.brand),
                        _Tag(text: product.carrier, color: accent),
                        if (product.wifiDeviceType != null)
                          _Tag(text: product.wifiDeviceType!),
                        if (product.wifiBizMode != null)
                          _Tag(text: product.wifiBizMode!),
                        Text(
                          product.priceLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppStyle.chevron),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            product.description,
            style: const TextStyle(
              fontSize: 13,
              color: AppStyle.subtitle,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '代理佣金 ¥${product.commission.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppStyle.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppStyle.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}
