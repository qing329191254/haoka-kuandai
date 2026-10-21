import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/data/china_regions.dart';
import 'package:haoka_app/data/local_merchants.dart';
import 'package:haoka_app/models/merchant.dart';
import 'package:haoka_app/models/order.dart';
import 'package:haoka_app/models/product.dart';
import 'package:haoka_app/store/auth_store.dart';
import 'package:haoka_app/store/order_store.dart';
import 'package:haoka_app/widgets/app_loading.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/app_toast.dart';
import 'package:haoka_app/widgets/carrier_picker.dart';
import 'package:haoka_app/widgets/merchant_picker.dart';
import 'package:haoka_app/widgets/region_picker.dart';
import 'package:haoka_app/widgets/select_field.dart';

class CatalogPurchasePage extends StatefulWidget {
  const CatalogPurchasePage({super.key, required this.product});

  final CatalogProduct product;

  @override
  State<CatalogPurchasePage> createState() => _CatalogPurchasePageState();
}

class _CatalogPurchasePageState extends State<CatalogPurchasePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _idNo = TextEditingController();
  final _address = TextEditingController();
  final _company = TextEditingController();
  RegionSelection? _region;
  LocalMerchant? _localMerchant;

  bool get _needMerchant => widget.product.bizType.assignMerchant;
  bool get _wifiFamily => widget.product.bizType.isWifiFamily;

  @override
  void initState() {
    super.initState();
    _company.text = widget.product.carrier;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _idNo.dispose();
    _address.dispose();
    _company.dispose();
    super.dispose();
  }

  Future<void> _pickRegion() async {
    final picked = await showRegionPicker(context, initial: _region);
    if (!mounted || picked == null) return;
    final regionChanged =
        _region?.cityKey != picked.cityKey ||
        _region?.district != picked.district;
    setState(() {
      _region = picked;
      if (regionChanged) _localMerchant = null;
    });
    if (_needMerchant && regionChanged) {
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
      bizType: widget.product.bizType,
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

  Future<void> _pickCompany() async {
    const options = ['电信', '移动', '联通', '广电', '小米WIFI', '华为WIFI'];
    final picked = await showCarrierPicker(
      context,
      title: '选择运营商或 WIFI 公司',
      selected: _company.text,
      carriers: options,
    );
    if (picked != null && mounted) setState(() => _company.text = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_region == null) {
      AppToast.tip(context, '请选择所在地');
      return;
    }
    if (_needMerchant && _localMerchant == null) {
      AppToast.tip(context, '请选择要分配的本地商家');
      return;
    }
    if (_wifiFamily && _company.text.trim().isEmpty) {
      AppToast.tip(context, '请填写运营商或 WIFI 公司');
      return;
    }

    final region = _region!;
    final merchant = _localMerchant;
    final detail = _address.text.trim();
    final user = context.read<AuthStore>().user;
    final idNo = _idNo.text.trim();
    final err = await AppLoading.run(
      context,
      () => context.read<OrderStore>().addOrder(
        bizType: widget.product.bizType,
        productId: widget.product.id,
        customerName: _name.text.trim().isEmpty
            ? '用户${_phone.text.trim().substring(_phone.text.trim().length - 4)}'
            : _name.text.trim(),
        customerPhone: _phone.text.trim(),
        address: '${region.province}${region.city}${region.district}$detail',
        productName: widget.product.name,
        carrier: _wifiFamily ? _company.text.trim() : widget.product.carrier,
        province: region.province,
        city: region.city,
        district: region.district,
        assignedMerchantId: merchant?.id,
        assignedMerchantName: merchant?.name,
        createdByUserId: user?.id,
        stockTypeId: widget.product.stockTypeId,
        stockTypeName: widget.product.stockTypeName,
        commission: widget.product.commission,
        wifiDeviceType: widget.product.wifiDeviceType,
        wifiBizMode: widget.product.wifiBizMode,
        customerIdNo: widget.product.bizType == BizType.haoka && idNo.isNotEmpty
            ? idNo
            : null,
      ),
      message: '提交中…',
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

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isHaoka = p.bizType == BizType.haoka;
    final nameLabel = isHaoka ? '收货人姓名' : '客户姓名';
    final phoneLabel = isHaoka ? '收货人手机号' : '用户电话';
    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar(isHaoka ? '填写收货人信息' : '填写办理信息'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SoftCard(
              child: Row(
                children: [
                  const SoftIconTile(
                    icon: Icons.inventory_2_outlined,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppStyle.title,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            p.cityLabel,
                            if (p.wifiDeviceType != null) p.wifiDeviceType,
                            if (p.wifiBizMode != null) p.wifiBizMode,
                            p.carrier,
                            p.priceLabel,
                            '佣金 ¥${p.commission.toStringAsFixed(0)}',
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppStyle.subtitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SoftCard(
              child: Column(
                children: [
                  if (!_wifiFamily) ...[
                    TextFormField(
                      controller: _name,
                      decoration: AppStyle.softInput(
                        labelText: nameLabel,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '必填' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: AppStyle.softInput(
                      labelText: phoneLabel,
                      prefixIcon: const Icon(Icons.phone_iphone),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 11) ? '请输入手机号' : null,
                  ),
                  if (isHaoka) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _idNo,
                      keyboardType: TextInputType.text,
                      decoration: AppStyle.softInput(
                        labelText: '身份证号码（选填）',
                        hintText: '18 位身份证号',
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return null;
                        if (!RegExp(r'^\d{17}[\dXx]$').hasMatch(s) &&
                            !RegExp(r'^\d{15}$').hasMatch(s)) {
                          return '请输入有效身份证号';
                        }
                        return null;
                      },
                    ),
                  ],
                  if (_wifiFamily) ...[
                    const SizedBox(height: 12),
                    SelectField(
                      label: '运营商或 WIFI 公司',
                      value: _company.text.isEmpty ? null : _company.text,
                      hint: '请选择或填写',
                      icon: Icons.cell_tower_outlined,
                      onTap: _pickCompany,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _company,
                      decoration: AppStyle.softInput(
                        labelText: '或手动填写 WIFI 公司',
                        hintText: '如：某某网络科技',
                        prefixIcon: const Icon(Icons.apartment_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SelectField(
                    label: '所在地',
                    value: _region?.label,
                    hint: '请选择省 / 市 / 区',
                    icon: Icons.map_outlined,
                    onTap: _pickRegion,
                  ),
                  if (_needMerchant) ...[
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    decoration: AppStyle.softInput(
                      labelText: '地址',
                      hintText: '街道、门牌号等',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '必填' : null,
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
