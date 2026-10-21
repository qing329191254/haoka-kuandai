import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/data/china_regions.dart';
import 'package:haoka_app/data/local_merchants.dart';
import 'package:haoka_app/data/phone_brands.dart';
import 'package:haoka_app/data/products.dart';
import 'package:haoka_app/models/merchant.dart';
import 'package:haoka_app/models/order.dart';
import 'package:haoka_app/models/product.dart';
import 'package:haoka_app/store/auth_store.dart';
import 'package:haoka_app/store/order_store.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/app_toast.dart';
import 'package:haoka_app/widgets/biz_visual.dart';
import 'package:haoka_app/widgets/carrier_picker.dart';
import 'package:haoka_app/widgets/merchant_picker.dart';
import 'package:haoka_app/widgets/order_flow_chart.dart';
import 'package:haoka_app/widgets/region_picker.dart';
import 'package:haoka_app/widgets/select_field.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key, required this.bizType});

  final BizType bizType;

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  static const _brands = PhoneBrands.names;
  static const _priceRanges = [
    '1000 元以下',
    '1000–2000 元',
    '2000–4000 元',
    '4000–6000 元',
    '6000 元以上',
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _product = TextEditingController();
  final _remark = TextEditingController();
  String _carrier = '电信';
  String _brand = '苹果';
  String _priceRange = '2000–4000 元';

  /// 意向单 / 确定套餐
  String _intent = 'intent';
  CatalogProduct? _pickedPackage;

  RegionSelection? _region;
  LocalMerchant? _localMerchant;

  bool get _isBroadband => widget.bizType.isBroadband;
  bool get _isContract => widget.bizType == BizType.contractPhone;
  bool get _isNaked => widget.bizType == BizType.broadbandNaked;
  bool get _needMerchant => widget.bizType.assignMerchant;
  bool get _confirmed => _intent == 'confirmed';

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _product.dispose();
    _remark.dispose();
    super.dispose();
  }

  List<CatalogProduct> get _cityPackages {
    final city = _region?.city;
    if (city == null) return const [];
    return CatalogProducts.of(bizType: widget.bizType, city: city);
  }

  Future<void> _pickRegion() async {
    final picked = await showRegionPicker(context, initial: _region);
    if (!mounted || picked == null) return;

    final regionChanged =
        _region?.cityKey != picked.cityKey ||
        _region?.district != picked.district;
    setState(() {
      _region = picked;
      if (regionChanged) {
        _localMerchant = null;
        _pickedPackage = null;
      }
    });

    if (regionChanged && _needMerchant) {
      await _pickMerchant(auto: true);
    }
  }

  Future<void> _pickMerchant({bool auto = false}) async {
    if (!LocalMerchants.loaded) {
      await LocalMerchants.refresh();
      if (!mounted) return;
    }
    final region = _region;
    if (region == null) {
      if (!auto) AppToast.tip(context, '请先选择省 / 市 / 区');
      return;
    }
    final list = LocalMerchants.inCity(
      province: region.province,
      city: region.city,
      bizType: widget.bizType,
      preferDistrict: region.district,
    );
    if (!mounted) return;
    if (list.isEmpty) {
      AppToast.tip(context, '${region.city}暂无承接该业务的入驻商家');
      return;
    }
    final picked = await showLocalMerchantPicker(
      context,
      cityLabel: region.city,
      merchants: list,
      selectedId: _localMerchant?.id,
    );
    if (!mounted || picked == null) return;
    setState(() => _localMerchant = picked);
  }

  Future<void> _pickBrand() async {
    final picked = await showCarrierPicker(
      context,
      title: '选择手机品牌',
      selected: _brand,
      carriers: _brands,
      leadingBuilder: (name) => PhoneBrandMark(name: name),
    );
    if (picked != null && mounted) setState(() => _brand = picked);
  }

  Future<void> _pickPrice() async {
    final picked = await showCarrierPicker(
      context,
      title: '选择价格区间',
      selected: _priceRange,
      carriers: _priceRanges,
    );
    if (picked != null && mounted) setState(() => _priceRange = picked);
  }

  Future<void> _pickPackage() async {
    if (_region == null) {
      AppToast.tip(context, '请先选择地区，以便匹配当地上架套餐');
      return;
    }
    final list = _cityPackages;
    if (list.isEmpty) {
      AppToast.tip(context, '${_region!.city}暂无上架套餐，可手填资费说明');
      return;
    }
    final picked = await showCarrierPicker(
      context,
      title: '选择当地套餐',
      selected: _pickedPackage == null
          ? ''
          : '${_pickedPackage!.name}（${_pickedPackage!.priceLabel}）',
      carriers: list.map((p) => '${p.name}（${p.priceLabel}）').toList(),
    );
    if (picked == null || !mounted) return;
    final match = list.firstWhere(
      (p) => '${p.name}（${p.priceLabel}）' == picked,
      orElse: () => list.first,
    );
    setState(() {
      _pickedPackage = match;
      _product.text = match.name;
      _carrier = match.carrier;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_needMerchant) {
      if (_region == null) {
        AppToast.tip(context, '请选择订单所在省 / 市 / 区');
        return;
      }
      if (_localMerchant == null) {
        AppToast.tip(context, '请选择要分配的本地商家');
        return;
      }
    }
    if (_isBroadband &&
        _confirmed &&
        _pickedPackage == null &&
        _product.text.trim().isEmpty) {
      AppToast.tip(context, '确定套餐订单请选择或填写套餐');
      return;
    }

    final region = _region;
    final merchant = _localMerchant;
    final detail = _address.text.trim();
    final fullAddress = region == null
        ? detail
        : '${region.province}${region.city}${region.district}$detail';

    late final String productName;
    late final String carrier;
    if (_isContract) {
      productName = '$_brand 合约机（$_priceRange）';
      carrier = _brand;
    } else if (_isBroadband && !_confirmed) {
      productName = _isNaked ? '裸宽意向单' : '融合宽带意向单';
      carrier = _carrier;
    } else if (_pickedPackage != null) {
      productName = _pickedPackage!.name;
      carrier = _pickedPackage!.carrier;
    } else {
      final note = _product.text.trim();
      productName = note.isEmpty
          ? '${widget.bizType.label}（$_carrier · 按当地资费）'
          : note;
      carrier = _carrier;
    }

    final user = context.read<AuthStore>().user;
    final err = await context.read<OrderStore>().addOrder(
      bizType: widget.bizType,
      productId: _pickedPackage?.id,
      customerName: _name.text.trim(),
      customerPhone: _phone.text.trim(),
      address: fullAddress.isEmpty ? (region?.label ?? '') : fullAddress,
      productName: productName,
      carrier: carrier,
      remark: _remark.text.trim().isEmpty ? null : _remark.text.trim(),
      province: region?.province,
      city: region?.city,
      district: region?.district,
      assignedMerchantId: merchant?.id,
      assignedMerchantName: merchant?.name,
      createdByUserId: user?.id,
      commission: _pickedPackage?.commission,
      orderIntent: _isBroadband ? (_confirmed ? '确定套餐' : '意向单') : null,
      phoneBrand: _isContract ? _brand : null,
      priceRange: _isContract ? _priceRange : null,
    );
    if (!mounted) return;
    if (err != null) {
      AppToast.tip(context, err);
      return;
    }
    final toast = merchant == null
        ? '订单已提交，可在「我的订单」查看进度'
        : '已分配给「${merchant.name}」，本地商家可在小程序接单处理';
    AppToast.success(context, toast);
    context.go('/orders');
  }

  Widget _intentSwitch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '客户意向',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppStyle.title,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _chip('意向单', 'intent'),
            const SizedBox(width: 8),
            _chip('已确定套餐', 'confirmed'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _confirmed ? '请选择当地上架套餐，或手填资费说明。' : '先留联系方式，套餐待客户确认后再补。',
          style: const TextStyle(fontSize: 12, color: AppStyle.subtitle),
        ),
      ],
    );
  }

  Widget _chip(String label, String value) {
    final on = _intent == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _intent = value;
          if (value == 'intent') _pickedPackage = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on
                ? AppStyle.brand.withValues(alpha: 0.12)
                : const Color(0xFFF5F7FB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on
                  ? AppStyle.brand.withValues(alpha: 0.4)
                  : const Color(0xFFE8ECF1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: on ? AppStyle.brand : AppStyle.title,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar('办理 · ${widget.bizType.label}'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SoftIconTile(icon: bizIcon(widget.bizType), size: 40),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '办理流程',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppStyle.title,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OrderFlowChart(
                    steps: widget.bizType.flowSteps,
                    previewMode: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SoftCard(
              child: Column(
                children: [
                  if (_isBroadband) ...[
                    _intentSwitch(),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _name,
                    decoration: AppStyle.softInput(
                      labelText: _isContract ? '申请人姓名' : '客户姓名',
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '必填' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: AppStyle.softInput(
                      labelText: _isContract ? '联系电话' : '联系方式（手机号）',
                      prefixIcon: const Icon(Icons.phone_iphone),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 11) ? '请输入手机号' : null,
                  ),
                  if (_isContract) ...[
                    const SizedBox(height: 12),
                    SelectField(
                      label: '手机品牌',
                      value: _brand,
                      hint: '请选择品牌',
                      icon: Icons.phone_android_outlined,
                      prefix: PhoneBrandMark(name: _brand, size: 28),
                      onTap: _pickBrand,
                    ),
                    const SizedBox(height: 12),
                    SelectField(
                      label: '能接受的价格区间',
                      value: _priceRange,
                      hint: '请选择价格区间',
                      icon: Icons.sell_outlined,
                      onTap: _pickPrice,
                    ),
                  ],
                  if (_needMerchant) ...[
                    const SizedBox(height: 12),
                    SelectField(
                      label: '订单所在地区',
                      value: _region?.label,
                      hint: '请选择省 / 市 / 区',
                      icon: Icons.map_outlined,
                      onTap: _pickRegion,
                    ),
                    const SizedBox(height: 12),
                    SelectField(
                      label: '分配本地商家',
                      value: _localMerchant?.name,
                      hint: _region == null
                          ? '请先选择地区'
                          : '选择${_region!.city}入驻商家',
                      icon: Icons.storefront_outlined,
                      subtitle: _localMerchant == null
                          ? null
                          : '${_localMerchant!.district} · ${_localMerchant!.contact}',
                      onTap: () => _pickMerchant(),
                    ),
                  ],
                  if (_isBroadband) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _address,
                      decoration: AppStyle.softInput(
                        labelText: '详细装机地址',
                        hintText: '街道、门牌号等',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '必填' : null,
                    ),
                  ],
                  if (_isBroadband && _confirmed) ...[
                    const SizedBox(height: 12),
                    SelectField(
                      label: '已上架套餐',
                      value: _pickedPackage == null
                          ? null
                          : '${_pickedPackage!.name} · ${_pickedPackage!.priceLabel}',
                      hint: _region == null
                          ? '请先选择地区'
                          : '选择${_region!.city}套餐（可手填）',
                      icon: Icons.inventory_2_outlined,
                      onTap: _pickPackage,
                    ),
                    const SizedBox(height: 12),
                    SelectField(
                      label: '运营商',
                      value: _carrier,
                      hint: '请选择运营商',
                      icon: Icons.cell_tower_outlined,
                      onTap: () async {
                        final picked = await showCarrierPicker(
                          context,
                          title: '选择运营商',
                          selected: _carrier,
                          carriers: const ['电信', '移动', '联通'],
                        );
                        if (picked != null && mounted)
                          setState(() => _carrier = picked);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _product,
                      decoration: AppStyle.softInput(
                        labelText: '套餐 / 资费说明',
                        hintText: '未匹配到上架套餐时可手填',
                        prefixIcon: const Icon(Icons.notes_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _remark,
                    maxLines: 3,
                    decoration: AppStyle.softInput(
                      labelText: '备注（可选）',
                      prefixIcon: const Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              style: AppStyle.primaryPill,
              child: Text(
                _needMerchant ? '提交并分配给本地商家' : '提交办理',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
