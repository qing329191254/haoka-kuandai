import 'package:haoka_app/models/order.dart';

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.bizType,
    required this.carrier,
    required this.priceLabel,
    required this.description,
    required this.province,
    required this.city,
    required this.commission,
    this.highlights = const [],
    this.stockTypeId,
    this.stockTypeName,
    this.wifiDeviceType,
    this.wifiBizMode,
  });

  final String id;
  final String name;
  final BizType bizType;
  final String carrier;
  final String priceLabel;
  final String description;
  final String province;
  final String city;
  final double commission;
  final List<String> highlights;
  final String? stockTypeId;
  final String? stockTypeName;

  /// WIFI 设备：4G / 5G
  final String? wifiDeviceType;

  /// WIFI 设备：买断 / 租赁
  final String? wifiBizMode;

  String get cityLabel => '$province $city';

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    return CatalogProduct(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      bizType: bizTypeFromApi('${json['bizType'] ?? 'haoka'}'),
      carrier: '${json['carrier'] ?? ''}',
      priceLabel: '${json['priceLabel'] ?? ''}',
      description: '${json['description'] ?? ''}',
      province: '${json['province'] ?? ''}',
      city: '${json['city'] ?? ''}',
      commission: json['commission'] is num
          ? (json['commission'] as num).toDouble()
          : 0,
      highlights: () {
        final raw = json['highlights'];
        if (raw is List) {
          return raw.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
        }
        return const <String>[];
      }(),
      stockTypeId:
          json['stockTypeId'] == null || '${json['stockTypeId']}'.isEmpty
          ? null
          : '${json['stockTypeId']}',
      stockTypeName:
          json['stockTypeName'] == null || '${json['stockTypeName']}'.isEmpty
          ? null
          : '${json['stockTypeName']}',
      wifiDeviceType:
          json['wifiDeviceType'] == null || '${json['wifiDeviceType']}'.isEmpty
          ? null
          : '${json['wifiDeviceType']}',
      wifiBizMode:
          json['wifiBizMode'] == null || '${json['wifiBizMode']}'.isEmpty
          ? null
          : '${json['wifiBizMode']}',
    );
  }
}

class StockBizType {
  const StockBizType({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;

  factory StockBizType.fromJson(Map<String, dynamic> json) {
    return StockBizType(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      description: '${json['description'] ?? ''}',
    );
  }
}
