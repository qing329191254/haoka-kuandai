import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/data/china_regions.dart';
import 'package:haoka_app/store/auth_store.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/app_toast.dart';
import 'package:haoka_app/widgets/region_picker.dart';
import 'package:haoka_app/widgets/select_field.dart';
import 'dart:async';
import 'dart:io';

/// 代理入驻申请（异地代理 / 异地商家统一身份）
class AgentApplyPage extends StatefulWidget {
  const AgentApplyPage({super.key});

  @override
  State<AgentApplyPage> createState() => _AgentApplyPageState();
}

class _AgentApplyPageState extends State<AgentApplyPage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _contact = TextEditingController();
  final _company = TextEditingController();
  final _address = TextEditingController();
  final _wechat = TextEditingController();
  final _backup = TextEditingController();
  final _idNo = TextEditingController();
  final _remark = TextEditingController();

  RegionSelection? _region;
  String _scale = 'city';
  DepositQuote? _quote;
  String? _licensePath;
  bool _obscure = true;
  bool _loading = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    _contact.dispose();
    _company.dispose();
    _address.dispose();
    _wechat.dispose();
    _backup.dispose();
    _idNo.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_countdown > 0) return;
    if (_phone.text.trim().length != 11) {
      AppToast.tip(context, '请先输入正确的 11 位手机号');
      return;
    }
    final err = await context.read<AuthStore>().sendSmsCode(_phone.text);
    if (!mounted) return;
    if (err != null) {
      AppToast.error(context, err);
      return;
    }
    AppToast.success(context, '验证码已发送');
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        t.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _pickRegion() async {
    final picked = await showRegionPicker(context, initial: _region);
    if (picked != null) {
      setState(() => _region = picked);
      _refreshQuote();
    }
  }

  Future<void> _pickScale() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '选择合作规模',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            ...agentScaleOptions.map(
              (s) => ListTile(
                title: Text(s.label),
                trailing: _scale == s.id
                    ? const Icon(Icons.check, color: AppStyle.brand)
                    : null,
                onTap: () => Navigator.pop(ctx, s.id),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _scale = picked);
    _refreshQuote();
  }

  Future<void> _refreshQuote() async {
    if (_region == null) {
      setState(() => _quote = null);
      return;
    }
    final q = await context.read<AuthStore>().quoteDeposit(
      province: _region!.province,
      city: _region!.city,
      scale: _scale,
    );
    if (!mounted) return;
    setState(() => _quote = q);
  }

  Future<void> _pickLicense() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _licensePath = file.path);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_region == null) {
      AppToast.tip(context, '请选择合作区域');
      return;
    }
    if (_scale.isEmpty) {
      AppToast.tip(context, '请选择合作规模');
      return;
    }
    if (_licensePath == null || _licensePath!.isEmpty) {
      AppToast.tip(context, '请上传证件照片');
      return;
    }
    setState(() => _loading = true);
    final err = await context.read<AuthStore>().submitApplication(
      phone: _phone.text,
      password: _password.text,
      code: _code.text,
      contact: _contact.text,
      companyName: _company.text,
      province: _region!.province,
      city: _region!.city,
      district: _region!.district,
      address: _address.text,
      wechat: _wechat.text,
      backupPhone: _backup.text,
      idNo: _idNo.text,
      licensePath: _licensePath!,
      remark: _remark.text,
      scale: _scale,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      AppToast.error(context, err);
      return;
    }
    AppToast.success(context, '申请已提交，请签署合作协议');
    context.go('/audit/contract');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar('申请入驻'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '代理入驻申请',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppStyle.title,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '提交资料后需签署合作协议并缴纳保证金，运营审核通过后方可下单。',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyle.subtitle,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '账号信息',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: AppStyle.softInput(
                        labelText: '手机号（登录账号）',
                        prefixIcon: const Icon(Icons.phone_iphone),
                      ),
                      validator: (v) => (v == null || v.trim().length != 11)
                          ? '请输入 11 位手机号'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      decoration: AppStyle.softInput(
                        labelText: '短信验证码',
                        prefixIcon: const Icon(Icons.sms_outlined),
                        suffixIcon: TextButton(
                          onPressed: _countdown > 0 ? null : _sendCode,
                          child: Text(
                            _countdown > 0 ? '${_countdown}s' : '获取验证码',
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入验证码' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: AppStyle.softInput(
                        labelText: '设置登录密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().length < 6)
                          ? '密码至少 6 位'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      decoration: AppStyle.softInput(
                        labelText: '确认密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (v) => v != _password.text ? '两次密码不一致' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '主体信息',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _contact,
                      decoration: AppStyle.softInput(
                        labelText: '联系人姓名',
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请填写联系人' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _company,
                      decoration: AppStyle.softInput(
                        labelText: '公司 / 门店名称',
                        prefixIcon: const Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请填写公司或门店名称' : null,
                    ),
                    const SizedBox(height: 12),
                    SelectField(
                      label: '合作区域',
                      value: _region?.label,
                      hint: '请选择省 / 市 / 区',
                      icon: Icons.map_outlined,
                      onTap: _pickRegion,
                    ),
                    const SizedBox(height: 12),
                    SelectField(
                      label: '合作规模',
                      value: agentScaleOptions
                          .firstWhere(
                            (s) => s.id == _scale,
                            orElse: () => agentScaleOptions[1],
                          )
                          .label,
                      hint: '区县 / 地市 / 省级',
                      icon: Icons.apartment_outlined,
                      onTap: _pickScale,
                    ),
                    if (_quote != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '预估保证金 ¥${_quote!.amount.toStringAsFixed(0)}（${_quote!.scope} · ${_quote!.scaleLabel}）\n提交后金额锁定，以申请单为准。',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppStyle.title,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _address,
                      decoration: AppStyle.softInput(
                        labelText: '详细地址',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请填写详细地址' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _wechat,
                      decoration: AppStyle.softInput(
                        labelText: '微信号（选填）',
                        prefixIcon: const Icon(Icons.chat_bubble_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _backup,
                      keyboardType: TextInputType.phone,
                      decoration: AppStyle.softInput(
                        labelText: '备用电话（选填）',
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '资质与说明',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _idNo,
                      decoration: AppStyle.softInput(
                        labelText: '身份证号 / 统一社会信用代码',
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请填写证件号码' : null,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '证件照片',
                      style: TextStyle(fontSize: 13, color: AppStyle.subtitle),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickLicense,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE6EBF2)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _licensePath == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: AppStyle.mutedIcon,
                                    size: 32,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '上传身份证或营业执照',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppStyle.subtitle,
                                    ),
                                  ),
                                ],
                              )
                            : Image.file(
                                File(_licensePath!),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _remark,
                      maxLines: 3,
                      decoration: AppStyle.softInput(
                        labelText: '备注（渠道来源、预计月单量等，选填）',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: AppStyle.primaryPill,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '提交申请',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('已有账号？返回登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
