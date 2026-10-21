import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/data/china_regions.dart';
import 'package:haoka_app/models/order.dart';
import 'package:haoka_app/models/product.dart';
import 'package:haoka_app/store/auth_store.dart';
import 'package:haoka_app/store/order_store.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/app_toast.dart';
import 'package:haoka_app/widgets/region_picker.dart';
import 'package:haoka_app/widgets/select_field.dart';

class HaokaPurchasePage extends StatefulWidget {
  const HaokaPurchasePage({super.key, required this.product});

  final CatalogProduct product;

  @override
  State<HaokaPurchasePage> createState() => _HaokaPurchasePageState();
}

class _HaokaPurchasePageState extends State<HaokaPurchasePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _idNo = TextEditingController();
  final _address = TextEditingController();
  RegionSelection? _region;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _idNo.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickRegion() async {
    final picked = await showRegionPicker(context, initial: _region);
    if (!mounted || picked == null) return;
    setState(() => _region = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_region == null) {
      AppToast.tip(context, '请选择所在地');
      return;
    }

    final region = _region!;
    final detail = _address.text.trim();
    final user = context.read<AuthStore>().user;
    final err = await context.read<OrderStore>().addOrder(
      bizType: BizType.haoka,
      productId: widget.product.id,
      customerName: _name.text.trim(),
      customerPhone: _phone.text.trim(),
      address: '${region.province}${region.city}${region.district}$detail',
      productName: widget.product.name,
      carrier: widget.product.carrier,
      province: region.province,
      city: region.city,
      district: region.district,
      createdByUserId: user?.id,
      customerIdNo: _idNo.text.trim().isEmpty ? null : _idNo.text.trim(),
    );
    if (!mounted) return;
    if (err != null) {
      AppToast.tip(context, err);
      return;
    }
    AppToast.success(context, '订单已提交，可在「我的订单」查看进度');
    context.go('/orders');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar('填写收货人信息'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SoftCard(
              child: Row(
                children: [
                  SoftIconTile(icon: Icons.sim_card_outlined, size: 44),
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
                          '${p.carrier} · ${p.priceLabel}',
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
                  TextFormField(
                    controller: _name,
                    decoration: AppStyle.softInput(
                      labelText: '收货人姓名',
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
                      labelText: '收货人手机号',
                      prefixIcon: const Icon(Icons.phone_iphone),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 11) ? '请输入手机号' : null,
                  ),
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
                  const SizedBox(height: 12),
                  SelectField(
                    label: '所在地',
                    value: _region?.label,
                    hint: '请选择省 / 市 / 区',
                    icon: Icons.map_outlined,
                    onTap: _pickRegion,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    decoration: AppStyle.softInput(
                      labelText: '详细地址',
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
              child: const Text(
                '提交办理',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
