import 'package:flutter/material.dart';
import 'package:haoka_app/widgets/app_surface.dart';

/// 竖向流程节点图：已完成 / 进行中 / 未到达 / 取消。
class OrderFlowChart extends StatelessWidget {
  const OrderFlowChart({
    super.key,
    required this.steps,
    this.currentStep = 0,
    this.previewMode = false,
  });

  final List<String> steps;

  /// 当前步骤索引；`-1` 表示整单已取消。
  final int currentStep;

  /// 办理页预览：无进度，仅展示流程图说明。
  final bool previewMode;

  static const _doneGreen = Color(0xFF2E7D32);
  static const _trackW = 28.0;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    final cancelled = !previewMode && currentStep < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cancelled)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '订单已结束，以下为原办理流程',
                style: TextStyle(
                  fontSize: 12,
                  color: AppStyle.subtitle,
                  height: 1.35,
                ),
              ),
            ),
          ),
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            index: i,
            label: steps[i],
            isLast: i == steps.length - 1,
            cancelled: cancelled,
            previewMode: previewMode,
            currentStep: currentStep,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.label,
    required this.isLast,
    required this.cancelled,
    required this.previewMode,
    required this.currentStep,
  });

  final int index;
  final String label;
  final bool isLast;
  final bool cancelled;
  final bool previewMode;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final done =
        !previewMode && !cancelled && currentStep >= 0 && index < currentStep;
    final current = !previewMode && !cancelled && index == currentStep;
    final pending = previewMode || cancelled || index > currentStep;

    final Color lineColor;
    if (cancelled || previewMode) {
      lineColor = const Color(0xFFE0E4EA);
    } else if (index < currentStep) {
      lineColor = AppStyle.brand.withValues(alpha: 0.55);
    } else {
      lineColor = const Color(0xFFE0E4EA);
    }

    final dashed =
        pending && !previewMode && !cancelled && index >= currentStep;
    // 当前节点带外圈，连线起点略下移
    final lineTop = current ? 14.0 : (previewMode ? 10.0 : 8.0);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: OrderFlowChart._trackW,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  if (!isLast)
                    Positioned(
                      top: lineTop,
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: CustomPaint(
                        painter: _ConnectorPainter(
                          color: lineColor,
                          dashed: dashed,
                        ),
                      ),
                    ),
                  _Node(
                    done: done,
                    current: current,
                    cancelled: cancelled,
                    previewIndex: previewMode ? index + 1 : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                        color: pending && !previewMode
                            ? AppStyle.subtitle
                            : (cancelled ? AppStyle.subtitle : AppStyle.title),
                      ),
                    ),
                    if (current) ...[
                      const SizedBox(height: 4),
                      Text(
                        '进行中',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppStyle.brand.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                    if (done) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '已完成',
                        style: TextStyle(
                          fontSize: 12,
                          color: OrderFlowChart._doneGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

class _Node extends StatelessWidget {
  const _Node({
    required this.done,
    required this.current,
    required this.cancelled,
    this.previewIndex,
  });

  final bool done;
  final bool current;
  final bool cancelled;
  final int? previewIndex;

  static const _dot = 12.0;
  static const _currentDot = 14.0;

  @override
  Widget build(BuildContext context) {
    if (previewIndex != null) {
      return Container(
        width: _currentDot + 4,
        height: _currentDot + 4,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppStyle.brand.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppStyle.brand.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: Text(
          '$previewIndex',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppStyle.brand,
            height: 1,
          ),
        ),
      );
    }

    if (cancelled) {
      return Container(
        width: _dot,
        height: _dot,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE8ECF1),
          border: Border.all(color: const Color(0xFFC5CAD3), width: 1.5),
        ),
      );
    }

    if (done) {
      return Container(
        width: _dot + 2,
        height: _dot + 2,
        decoration: const BoxDecoration(
          color: OrderFlowChart._doneGreen,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 10, color: Colors.white),
      );
    }

    if (current) {
      return Container(
        width: _currentDot + 8,
        height: _currentDot + 8,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppStyle.brand.withValues(alpha: 0.14),
        ),
        child: Container(
          width: _currentDot,
          height: _currentDot,
          decoration: BoxDecoration(
            color: AppStyle.brand,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppStyle.brand.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: _dot,
      height: _dot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC5CAD3), width: 1.6),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final x = size.width / 2;
    if (!dashed) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      return;
    }

    const dash = 4.0;
    const gap = 3.0;
    var y = 0.0;
    while (y < size.height) {
      final y2 = (y + dash).clamp(0.0, size.height);
      canvas.drawLine(Offset(x, y), Offset(x, y2), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}
