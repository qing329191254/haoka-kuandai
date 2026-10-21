import 'package:flutter/material.dart';
import 'package:haoka_app/widgets/app_surface.dart';

/// 合约机品牌。Logo 均取自各品牌官网（favicon / 站点标识）。
abstract final class PhoneBrands {
  static const names = ['苹果', '华为', '小米', 'OPPO', 'vivo', '荣耀', '三星', '其他'];

  static const logos = <String, String>{
    '苹果': 'assets/brands/apple.png',
    '华为': 'assets/brands/huawei.png',
    '小米': 'assets/brands/xiaomi.png',
    'OPPO': 'assets/brands/oppo.png',
    'vivo': 'assets/brands/vivo.png',
    '荣耀': 'assets/brands/honor.png',
    '三星': 'assets/brands/samsung.png',
  };

  static String? logoOf(String name) => logos[name];
}

class PhoneBrandMark extends StatelessWidget {
  const PhoneBrandMark({super.key, required this.name, this.size = 36});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = PhoneBrands.logoOf(name);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox(
        width: size,
        height: size,
        child: asset == null
            ? ColoredBox(
                color: const Color(0xFFE8ECF1),
                child: Icon(
                  Icons.smartphone_outlined,
                  size: size * 0.58,
                  color: AppStyle.subtitle,
                ),
              )
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: const Color(0xFFE8ECF1),
                  child: Icon(
                    Icons.smartphone_outlined,
                    size: size * 0.58,
                    color: AppStyle.subtitle,
                  ),
                ),
              ),
      ),
    );
  }
}
