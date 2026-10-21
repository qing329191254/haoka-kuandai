import 'package:flutter/material.dart';
import 'package:haoka_app/widgets/app_surface.dart';

const kCarriers = ['电信', '移动', '联通', '广电'];

Color carrierAccent(String carrier) => switch (carrier) {
  '电信' => const Color(0xFF0052D9),
  '移动' => const Color(0xFF0085D0),
  '联通' => const Color(0xFFE60012),
  '广电' => const Color(0xFF6A1B9A),
  _ => AppStyle.brand,
};

Future<String?> showCarrierPicker(
  BuildContext context, {
  required String selected,
  List<String> carriers = kCarriers,
  String title = '选择运营商',
  Widget Function(String name)? leadingBuilder,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.7;
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E4EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppStyle.title,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: carriers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = carriers[i];
                      return _CarrierOption(
                        name: c,
                        selected: c == selected,
                        onTap: () => Navigator.pop(ctx, c),
                        leading: leadingBuilder?.call(c),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _CarrierOption extends StatelessWidget {
  const _CarrierOption({
    required this.name,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final accent = carrierAccent(name);
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.08)
          : const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              leading ??
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      name.substring(0, 1),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: AppStyle.title,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_rounded, color: accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
