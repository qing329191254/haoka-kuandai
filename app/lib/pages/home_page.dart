import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haoka_app/widgets/app_surface.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _entries = <_HomeEntry>[
    _HomeEntry(
      title: '号卡',
      guide: '选择当地在售号卡套餐，填写收货人信息后提交',
      hint: '按城市选套餐办理',
      icon: Icons.sim_card_outlined,
      path: '/catalog?type=haoka',
    ),
    _HomeEntry(
      title: '合约机',
      guide: '填写申请人、电话、手机品牌和可接受价位',
      hint: '提交后由当地商家承接',
      icon: Icons.phonelink_setup_outlined,
      path: '/create?type=contract_phone',
    ),
    _HomeEntry(
      title: '宽带',
      guide: '办理裸宽或融合宽带，融合可新开卡上门或线上办理',
      hint: '含裸宽与融合宽带',
      icon: Icons.router_outlined,
      path: '/broadband',
    ),
    _HomeEntry(
      title: 'WIFI 设备',
      guide: '4G / 5G 随身 WIFI，买断或租赁；也可办理 CPE',
      hint: '提交后由当地商家交付',
      icon: Icons.wifi_outlined,
      path: '/wifi',
    ),
    _HomeEntry(
      title: '存量业务',
      guide: '宽带续费、套餐升档、电视增值等已有业务',
      hint: '按业务类型选择套餐',
      icon: Icons.layers_outlined,
      path: '/stock/types',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SoftPageScaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SoftPageHeader(
            title: '派客邦',
            subtitle: '号卡 · 合约机 · 宽带 · WIFI · 存量',
            trailing: IconButton(
              tooltip: '客服',
              onPressed: () => context.go('/service'),
              icon: const Icon(
                Icons.support_agent_outlined,
                color: Color(0xFF5A6A7A),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            child: Column(
              children: [
                for (final e in _entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SoftCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () => context.push(e.path),
                      child: Row(
                        children: [
                          SoftIconTile(icon: e.icon, size: 48),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppStyle.title,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.guide,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppStyle.subtitle,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  e.hint,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppStyle.brand.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppStyle.chevron,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeEntry {
  const _HomeEntry({
    required this.title,
    required this.guide,
    required this.hint,
    required this.icon,
    required this.path,
  });

  final String title;
  final String guide;
  final String hint;
  final IconData icon;
  final String path;
}
