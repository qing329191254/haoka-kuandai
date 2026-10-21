import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tobias/tobias.dart';
import 'package:haoka_app/store/auth_store.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/app_toast.dart';

enum _PayMethod { wechat, alipay }

/// 入驻押金
class DepositPayPage extends StatefulWidget {
  const DepositPayPage({super.key});

  @override
  State<DepositPayPage> createState() => _DepositPayPageState();
}

class _DepositPayPageState extends State<DepositPayPage> {
  bool _loading = false;
  _PayMethod _method = _PayMethod.alipay;

  String get _methodLabel => switch (_method) {
    _PayMethod.wechat => '微信支付',
    _PayMethod.alipay => '支付宝',
  };

  String get _channel => switch (_method) {
    _PayMethod.wechat => 'wechat',
    _PayMethod.alipay => 'alipay',
  };

  Future<void> _pay() async {
    setState(() => _loading = true);
    final store = context.read<AuthStore>();
    final result = await store.payDeposit(channel: _channel);
    if (!mounted) return;

    if (result.error != null) {
      setState(() => _loading = false);
      AppToast.error(context, result.error!);
      return;
    }

    if (result.paid && !result.needClientPay) {
      setState(() => _loading = false);
      AppToast.success(context, '$_methodLabel支付成功，已提交审核');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      context.go('/audit');
      return;
    }

    if (_method == _PayMethod.alipay &&
        result.needClientPay &&
        result.orderStr.isNotEmpty) {
      try {
        final tobias = Tobias();
        final payEnv =
            result.env == 'sandbox' ? AliPayEvn.sandbox : AliPayEvn.online;
        final payResult = await tobias.pay(result.orderStr, evn: payEnv);
        final ok = _alipayResultOk(payResult);
        await store.refreshMe();
        if (!mounted) return;
        setState(() => _loading = false);
        if (ok || (store.user?.depositPaid ?? false)) {
          AppToast.success(context, '支付宝支付成功，已提交审核');
          await Future<void>.delayed(const Duration(milliseconds: 400));
          if (!mounted) return;
          context.go('/audit');
        } else {
          AppToast.error(
            context,
            '未确认支付成功。若已付款请稍后在审核页刷新；环境：${result.env}',
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        AppToast.error(context, '调起支付宝失败：$e');
      }
      return;
    }

    setState(() => _loading = false);
    AppToast.error(context, '支付参数异常，请重试或联系客服');
  }

  bool _alipayResultOk(dynamic payResult) {
    if (payResult is Map) {
      final status = '${payResult['resultStatus'] ?? payResult['result_status'] ?? ''}';
      return status == '9000';
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;
    final amount = user?.depositAmount ?? kAgentDepositAmount;

    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar(
        '缴纳押金',
        actions: [
          TextButton(
            onPressed: () {
              context.read<AuthStore>().logout();
              context.go('/login');
            },
            child: const Text('退出'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '入驻保证金',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppStyle.title,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '您已签署合作协议。保证金在合作期内由平台留存，用于履约保障；解约且无欠费后可申请退还。支付完成后提交运营审核。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppStyle.subtitle,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '应缴金额',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¥${amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    '申请人 ${user.nickname} · ${user.phone}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppStyle.mutedIcon,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '支付方式',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppStyle.title,
                  ),
                ),
                const SizedBox(height: 8),
                _methodTile(
                  method: _PayMethod.wechat,
                  title: '微信支付',
                  subtitle: '正式环境暂未开通时可先用支付宝',
                  asset: 'assets/pay/wechat_pay.png',
                ),
                const Divider(height: 1),
                _methodTile(
                  method: _PayMethod.alipay,
                  title: '支付宝',
                  subtitle: '支持余额、银行卡等（可由服务端切 mock/沙箱/正式）',
                  asset: 'assets/pay/alipay.png',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: AppStyle.primaryPill,
            onPressed: _loading ? null : _pay,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text('$_methodLabel 支付 ¥${amount.toStringAsFixed(0)}'),
          ),
        ],
      ),
    );
  }

  Widget _methodTile({
    required _PayMethod method,
    required String title,
    required String subtitle,
    required String asset,
  }) {
    final selected = _method == method;
    return InkWell(
      onTap: () => setState(() => _method = method),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Image.asset(asset, width: 36, height: 36, fit: BoxFit.contain),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppStyle.title,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppStyle.mutedIcon,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppStyle.brand : AppStyle.mutedIcon,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
