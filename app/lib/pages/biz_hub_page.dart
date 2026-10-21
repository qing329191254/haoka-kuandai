import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haoka_app/widgets/app_surface.dart';

class HubItem {
  const HubItem({
    required this.title,
    required this.desc,
    required this.hint,
    required this.icon,
    required this.path,
  });

  final String title;
  final String desc;
  final String hint;
  final IconData icon;
  final String path;
}

class BizHubPage extends StatelessWidget {
  const BizHubPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<HubItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar(title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppStyle.subtitle,
                height: 1.4,
              ),
            ),
          ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SoftCard(
                padding: const EdgeInsets.all(14),
                onTap: () => context.push(item.path),
                child: Row(
                  children: [
                    SoftIconTile(icon: item.icon, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppStyle.title,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.desc,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppStyle.subtitle,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.hint,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppStyle.brand.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppStyle.chevron),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BroadbandHubPage extends StatelessWidget {
  const BroadbandHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const BizHubPage(
      title: '宽带',
      subtitle: '请选择要办理的宽带类型。下单时请标明客户是意向咨询，还是已确定套餐。',
      items: [
        HubItem(
          title: '裸宽',
          desc: '不捆绑号卡，提供装机地址和联系方式即可办理。',
          hint: '当地商家负责装机',
          icon: Icons.router_outlined,
          path: '/create?type=broadband_naked',
        ),
        HubItem(
          title: '融合宽带 · 新开卡（上门）',
          desc: '需新开号卡，师傅上门开户后再安排装机。',
          hint: '师傅上门开户',
          icon: Icons.sim_card_outlined,
          path: '/create?type=broadband_new_card',
        ),
        HubItem(
          title: '融合宽带 · 不需要开卡（线上办理）',
          desc: '已有号码或无需新开卡，商家线上开户后装机。',
          hint: '商家线上开户',
          icon: Icons.wifi_tethering_outlined,
          path: '/create?type=broadband_no_card',
        ),
      ],
    );
  }
}

class WifiHubPage extends StatelessWidget {
  const WifiHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const BizHubPage(
      title: 'WIFI 设备',
      subtitle: '请选择设备类型。普通 WIFI 按 4G/5G 与买断或租赁选择套餐；CPE 需填写运营商或 WIFI 公司、电话和地址。',
      items: [
        HubItem(
          title: '普通 WIFI',
          desc: '选择 4G 或 5G、买断或租赁，再选当地在售套餐。',
          hint: '提交后由当地商家交付',
          icon: Icons.wifi_outlined,
          path: '/catalog?type=wifi',
        ),
        HubItem(
          title: 'CPE',
          desc: '室内 CPE 设备，填写运营商或 WIFI 公司、用户电话与地址。',
          hint: '提交后由当地商家交付',
          icon: Icons.router_rounded,
          path: '/catalog?type=cpe',
        ),
      ],
    );
  }
}
