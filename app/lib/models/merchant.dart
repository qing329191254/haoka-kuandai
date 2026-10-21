import 'package:haoka_app/models/order.dart';

/// App 端本地履约商家（按地级市入驻，供宽带异地转单选择）。
class LocalMerchant {
  const LocalMerchant({
    required this.id,
    required this.name,
    required this.phone,
    required this.contact,
    required this.province,
    required this.city,
    required this.district,
    required this.bizTypes,
    this.address,
  });

  final String id;
  final String name;
  final String phone;
  final String contact;
  final String province;
  final String city;
  final String district;

  /// 门店详细地址，不参与按市筛选
  final String? address;
  final List<BizType> bizTypes;

  String get regionLabel => '$province $city $district';

  bool coversCity(String province, String city) =>
      this.province == province && this.city == city;

  bool accepts(BizType type) => bizTypes.contains(type);

  factory LocalMerchant.fromJson(Map<String, dynamic> json) {
    final types = (json['bizTypes'] as List? ?? [])
        .map((e) => bizTypeFromApi('$e'))
        .toList();
    return LocalMerchant(
      id: '${json['id'] ?? ''}',
      name: '${json['mpDisplayName'] ?? json['name'] ?? ''}',
      phone: '${json['phone'] ?? json['loginPhone'] ?? ''}',
      contact: '${json['contact'] ?? ''}',
      province: '${json['province'] ?? ''}',
      city: '${json['city'] ?? ''}',
      district: '${json['district'] ?? ''}',
      address: json['address'] == null ? null : '${json['address']}',
      bizTypes: types.isEmpty ? BizType.values : types,
    );
  }
}
