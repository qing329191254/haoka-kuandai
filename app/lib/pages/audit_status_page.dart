import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/store/auth_store.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/app_toast.dart';

/// 入驻审核状态页（押金+合同完成后等待运营；未通过前不可下单）
class AuditStatusPage extends StatefulWidget {
  const AuditStatusPage({super.key});

  @override
  State<AuditStatusPage> createState() => _AuditStatusPageState();
}

class _AuditStatusPageState extends State<AuditStatusPage> {
  Timer? _timer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    if (mounted) setState(() {});
    try {
      await context.read<AuthStore>().refreshMe();
    } catch (_) {
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('未登录')));
    }

    // 未完成押金 / 合同：跳到对应步骤
    if (user.auditStatus == AgentAuditStatus.needDeposit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/audit/deposit');
      });
    } else if (user.auditStatus == AgentAuditStatus.needContract) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/audit/contract');
      });
    }

    final (icon, color, title, body) = switch (user.auditStatus) {
      AgentAuditStatus.needDeposit => (
        Icons.account_balance_wallet_outlined,
        const Color(0xFF1E88E5),
        '请先缴纳押金',
        '正在跳转支付…',
      ),
      AgentAuditStatus.needContract => (
        Icons.draw_outlined,
        const Color(0xFF1E88E5),
        '请签署合作协议',
        '正在跳转电子签…',
      ),
      AgentAuditStatus.pending => (
        Icons.hourglass_top_rounded,
        const Color(0xFFEF6C00),
        '押金与合同审核中',
        '我们已收到「${user.companyName.isEmpty ? user.nickname : user.companyName}」的押金与电子签合同，运营审核通过后即可转手下单。',
      ),
      AgentAuditStatus.rejected => (
        Icons.cancel_outlined,
        const Color(0xFFC62828),
        '入驻申请未通过',
        user.rejectReason.isEmpty ? '请完善资料后重新申请，或联系平台客服。' : user.rejectReason,
      ),
      AgentAuditStatus.approved => (
        Icons.check_circle_outline,
        const Color(0xFF2E7D32),
        '已通过审核',
        '您可以开始提交号卡 / 宽带转手订单。',
      ),
    };

    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar(
        '入驻状态',
        actions: [
          TextButton(
            onPressed: () {
              context.read<AuthStore>().logout();
              context.go('/login');
            },
            child: const Text('退出登录'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          SoftCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: color),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppStyle.title,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppStyle.subtitle,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '登录手机号 ${user.phone}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppStyle.mutedIcon,
                  ),
                ),
                const SizedBox(height: 20),
                _stepRow(
                  '电子签合同',
                  user.contractSigned,
                  user.contractNo.isEmpty
                      ? null
                      : '${user.contractNo} · ${user.signerName}',
                ),
                const SizedBox(height: 8),
                _stepRow(
                  '押金',
                  user.depositPaid,
                  user.depositPaidAt.isEmpty
                      ? '${user.scaleLabel} · 应缴 ¥${user.depositAmount.toStringAsFixed(0)}'
                      : '${user.scaleLabel} · ¥${user.depositAmount.toStringAsFixed(0)} · ${user.depositPaidAt}',
                ),
                const SizedBox(height: 24),
                if (user.auditStatus == AgentAuditStatus.approved)
                  FilledButton(
                    style: AppStyle.primaryPill,
                    onPressed: () => context.go('/'),
                    child: const Text('进入首页'),
                  ),
                if (user.auditStatus == AgentAuditStatus.rejected) ...[
                  FilledButton(
                    style: AppStyle.primaryPill,
                    onPressed: () {
                      context.read<AuthStore>().logout();
                      context.go('/login/apply');
                    },
                    child: const Text('重新申请'),
                  ),
                  const SizedBox(height: 8),
                ],
                if (user.auditStatus == AgentAuditStatus.pending) ...[
                  FilledButton(
                    style: AppStyle.primaryPill,
                    onPressed: _refreshing
                        ? null
                        : () async {
                            await _refresh();
                            if (!context.mounted) return;
                            AppToast.tip(context, '已刷新审核状态');
                          },
                    child: Text(_refreshing ? '刷新中…' : '刷新审核状态'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => context.push('/service'),
                    child: const Text('联系客服'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(String label, bool done, String? detail) {
    final detailStyle = TextStyle(
      fontSize: 11,
      color: done ? const Color(0xFF2E7D32) : AppStyle.mutedIcon,
      height: 1.35,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFE8F5E9) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color: done ? const Color(0xFF2E7D32) : AppStyle.mutedIcon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (detail == null)
                Text(done ? '已完成' : '未完成', style: detailStyle),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail, textAlign: TextAlign.right, style: detailStyle),
          ],
        ],
      ),
    );
  }
}
