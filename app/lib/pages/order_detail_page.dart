import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/models/order.dart';
import 'package:haoka_app/store/order_store.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/biz_visual.dart';
import 'package:haoka_app/widgets/order_flow_chart.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.id});

  final String id;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load() async {
    await context.read<OrderStore>().fetchById(widget.id);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Color _statusColor(OrderStatus s) => switch (s) {
    OrderStatus.done => const Color(0xFF2E7D32),
    OrderStatus.cancelled => const Color(0xFF9E9E9E),
    OrderStatus.followUp || OrderStatus.failed => const Color(0xFFC62828),
    OrderStatus.installing || OrderStatus.bossOpened => const Color(0xFFEF6C00),
    _ => AppStyle.brand,
  };

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrderStore>().findById(widget.id);
    if (_loading && order == null) {
      return Scaffold(
        backgroundColor: AppStyle.pageBg,
        appBar: AppStyle.softAppBar('订单详情'),
        body: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (order == null) {
      return Scaffold(
        backgroundColor: AppStyle.pageBg,
        appBar: AppStyle.softAppBar('订单详情'),
        body: Center(
          child: TextButton(
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
            child: const Text('订单不存在或加载失败，点击重试'),
          ),
        ),
      );
    }

    final statusColor = _statusColor(order.status);
    final currentStep = switch (order.status) {
      OrderStatus.listed => 0,
      OrderStatus.merchantAccepted || OrderStatus.dispatched => 1,
      OrderStatus.techAccepted => 2,
      OrderStatus.bossOpened => order.bizType.skipTechDispatch ? 1 : 2,
      OrderStatus.installing => order.bizType.skipTechDispatch ? 2 : 3,
      OrderStatus.done => order.bizType.flowSteps.length - 1,
      OrderStatus.cancelled || OrderStatus.failed || OrderStatus.followUp => -1,
    };

    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar('订单详情'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SoftIconTile(icon: bizIcon(order.bizType), size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.productName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppStyle.title,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.bizLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppStyle.subtitle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.status.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppStyle.divider),
                const SizedBox(height: 8),
                _InfoRow(label: '订单号', value: order.orderNo),
                _InfoRow(
                  label: order.bizType == BizType.haoka
                      ? '收货人'
                      : (order.bizType == BizType.contractPhone ? '申请人' : '客户'),
                  value: order.customerName,
                ),
                _InfoRow(label: '手机号', value: order.customerPhone),
                if (order.customerIdNo != null)
                  _InfoRow(label: '身份证号', value: order.customerIdNo!),
                if (order.phoneBrand != null)
                  _InfoRow(label: '手机品牌', value: order.phoneBrand!),
                if (order.priceRange != null)
                  _InfoRow(label: '价格区间', value: order.priceRange!),
                if (order.orderIntent != null)
                  _InfoRow(label: '客户意向', value: order.orderIntent!),
                if (order.wifiDeviceType != null)
                  _InfoRow(label: '设备类型', value: order.wifiDeviceType!),
                if (order.wifiBizMode != null)
                  _InfoRow(label: '业务模式', value: order.wifiBizMode!),
                if (order.regionLabel != null)
                  _InfoRow(label: '所在地', value: order.regionLabel!),
                _InfoRow(
                  label: order.bizType == BizType.haoka ? '详细地址' : '地址',
                  value: order.detailAddress,
                ),
                if (order.assignedMerchantName != null)
                  _InfoRow(label: '履约商家', value: order.assignedMerchantName!),
                _InfoRow(
                  label: order.bizType.isWifiFamily ? '运营商 / WIFI 公司' : '运营商',
                  value: order.carrier,
                ),
                if (order.commission != null)
                  _InfoRow(
                    label: '佣金',
                    value: '¥${order.commission!.toStringAsFixed(0)}',
                  ),
                if (order.failReason != null)
                  _InfoRow(label: '交付失败原因', value: order.failReason!),
                if (order.remark != null)
                  _InfoRow(label: '备注', value: order.remark!),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '流程进度',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppStyle.title,
                  ),
                ),
                const SizedBox(height: 14),
                OrderFlowChart(
                  steps: order.bizType.flowSteps,
                  currentStep: currentStep,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppStyle.subtitle),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppStyle.title,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
