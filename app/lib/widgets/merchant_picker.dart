import 'package:flutter/material.dart';
import 'package:haoka_app/models/merchant.dart';
import 'package:haoka_app/widgets/app_surface.dart';

Future<LocalMerchant?> showLocalMerchantPicker(
  BuildContext context, {
  required String cityLabel,
  required List<LocalMerchant> merchants,
  String? selectedId,
}) {
  return showModalBottomSheet<LocalMerchant>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _MerchantPickerSheet(
      cityLabel: cityLabel,
      merchants: merchants,
      selectedId: selectedId,
    ),
  );
}

class _MerchantPickerSheet extends StatelessWidget {
  const _MerchantPickerSheet({
    required this.cityLabel,
    required this.merchants,
    this.selectedId,
  });

  final String cityLabel;
  final List<LocalMerchant> merchants;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: maxH,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E4EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$cityLabel入驻商家',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppStyle.title,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '选择后，该本地商家将在 App 中看到此订单',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppStyle.subtitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppStyle.mutedIcon),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppStyle.divider),
            Expanded(
              child: merchants.isEmpty
                  ? const Center(
                      child: Text(
                        '该地区暂无入驻商家',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppStyle.subtitle,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: merchants.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final m = merchants[i];
                        final selected = m.id == selectedId;
                        return Material(
                          color: selected
                              ? AppStyle.brand.withValues(alpha: 0.08)
                              : const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(context, m),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  SoftIconTile(
                                    icon: Icons.storefront_outlined,
                                    size: 42,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppStyle.title,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          m.address == null ||
                                                  m.address!.isEmpty
                                              ? '${m.district} · ${m.contact} ${m.phone}'
                                              : '${m.district}${m.address} · ${m.contact} ${m.phone}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppStyle.subtitle,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppStyle.brand,
                                      size: 22,
                                    )
                                  else
                                    const Icon(
                                      Icons.chevron_right,
                                      color: AppStyle.chevron,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
