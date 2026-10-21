enum BizType {
  haoka,
  contractPhone,
  broadbandNaked,
  broadbandNewCard,
  broadbandNoCard,
  wifi,
  cpe,
  stock,
}

extension BizTypeX on BizType {
  String get apiValue => switch (this) {
    BizType.haoka => 'haoka',
    BizType.contractPhone => 'contract_phone',
    BizType.broadbandNaked => 'broadband_naked',
    BizType.broadbandNewCard => 'broadband_new_card',
    BizType.broadbandNoCard => 'broadband_no_card',
    BizType.wifi => 'wifi',
    BizType.cpe => 'cpe',
    BizType.stock => 'stock',
  };

  String get label => switch (this) {
    BizType.haoka => '号卡',
    BizType.contractPhone => '合约机',
    BizType.broadbandNaked => '裸宽',
    BizType.broadbandNewCard => '融合宽带（新开卡）',
    BizType.broadbandNoCard => '融合宽带（线上办理）',
    BizType.wifi => 'WIFI 设备',
    BizType.cpe => 'CPE',
    BizType.stock => '存量业务',
  };

  bool get needNewCard =>
      this == BizType.haoka || this == BizType.broadbandNewCard;

  bool get isCatalog =>
      this == BizType.haoka ||
      this == BizType.wifi ||
      this == BizType.cpe ||
      this == BizType.stock;

  bool get isWifiFamily => this == BizType.wifi || this == BizType.cpe;

  bool get isBroadband =>
      this == BizType.broadbandNaked ||
      this == BizType.broadbandNewCard ||
      this == BizType.broadbandNoCard;

  /// 无需派上门开户：裸宽 / 融合线上办理
  bool get skipTechDispatch =>
      this == BizType.broadbandNaked || this == BizType.broadbandNoCard;

  bool get assignMerchant => this != BizType.haoka;

  String get orderPrefix => switch (this) {
    BizType.haoka => 'HK',
    BizType.contractPhone => 'HJ',
    BizType.wifi => 'WF',
    BizType.cpe => 'CPE',
    BizType.stock => 'CL',
    _ => 'KD',
  };

  List<String> get flowSteps => switch (this) {
    BizType.haoka => const ['提交办卡信息', '商家接单安排', '师傅预约上门', '现场开户激活', '办理完成'],
    BizType.contractPhone => const [
      '提交合约机意向',
      '分配当地商家',
      '商家接单联系',
      '交付办理',
      '办理完成',
    ],
    BizType.broadbandNaked => const ['提交裸宽地址与联系方式', '分配当地商家', '商家办理装机', '安装完成'],
    BizType.broadbandNewCard => const [
      '提交融合宽带与开卡信息',
      '商家接单派单',
      '师傅上门开户',
      '安排装机上门',
      '安装完成',
    ],
    BizType.broadbandNoCard => const ['提交融合宽带信息', '商家线上开户', '安排装机上门', '安装完成'],
    BizType.wifi => const ['选择 WIFI 套餐', '分配当地商家', '师傅预约上门', '现场交付拍照', '办理完成'],
    BizType.cpe => const ['提交 CPE 信息', '分配当地商家', '师傅预约上门', '现场交付拍照', '办理完成'],
    BizType.stock => const ['选择存量套餐', '商家接单安排', '师傅预约上门', '现场交付拍照', '办理完成'],
  };

  String get shortGuide => switch (this) {
    BizType.haoka => '选择当地在售号卡套餐，填写收货人信息后提交',
    BizType.contractPhone => '填写申请人、电话、品牌和可接受价位，由当地商家承接',
    BizType.broadbandNaked => '提供装机地址和联系方式，由当地商家装机',
    BizType.broadbandNewCard => '融合宽带新开卡，师傅上门开户后再装机',
    BizType.broadbandNoCard => '融合宽带无需新开卡，商家线上开户后装机',
    BizType.wifi => '选择 4G/5G、买断或租赁及当地套餐',
    BizType.cpe => '填写运营商或 WIFI 公司、电话与地址',
    BizType.stock => '按存量业务类型选择当地套餐',
  };
}

enum OrderStatus {
  listed,
  merchantAccepted,
  dispatched,
  techAccepted,
  bossOpened,
  installing,
  followUp,
  done,
  failed,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.listed => '待接单',
    OrderStatus.merchantAccepted => '商家处理中',
    OrderStatus.dispatched => '待上门',
    OrderStatus.techAccepted => '上门服务中',
    OrderStatus.bossOpened => '已开户',
    OrderStatus.installing => '装机中',
    OrderStatus.followUp => '商家跟进',
    OrderStatus.done => '已完成',
    OrderStatus.failed => '交付失败',
    OrderStatus.cancelled => '已取消',
  };

  bool get isPending => this == OrderStatus.listed;

  bool get isProcessing => switch (this) {
    OrderStatus.merchantAccepted ||
    OrderStatus.dispatched ||
    OrderStatus.techAccepted ||
    OrderStatus.bossOpened ||
    OrderStatus.installing => true,
    _ => false,
  };

  bool get isFinished => this == OrderStatus.done;
  bool get isCancelled => this == OrderStatus.cancelled;
  bool get isFailed =>
      this == OrderStatus.failed || this == OrderStatus.followUp;
}

enum OrderListFilter { all, pending, processing, done, failed, cancelled }

extension OrderListFilterX on OrderListFilter {
  String get label => switch (this) {
    OrderListFilter.all => '全部',
    OrderListFilter.pending => '待接单',
    OrderListFilter.processing => '进行中',
    OrderListFilter.done => '已完成',
    OrderListFilter.failed => '交付失败',
    OrderListFilter.cancelled => '已取消',
  };

  bool matches(OrderStatus status) => switch (this) {
    OrderListFilter.all => true,
    OrderListFilter.pending => status.isPending,
    OrderListFilter.processing => status.isProcessing,
    OrderListFilter.done => status.isFinished,
    OrderListFilter.failed => status.isFailed,
    OrderListFilter.cancelled => status.isCancelled,
  };
}

BizType bizTypeFromApi(String value) {
  return BizType.values.firstWhere(
    (e) => e.apiValue == value,
    orElse: () => BizType.haoka,
  );
}

OrderStatus orderStatusFromApi(String value) {
  return switch (value) {
    'listed' => OrderStatus.listed,
    'merchant_accepted' => OrderStatus.merchantAccepted,
    'dispatched' => OrderStatus.dispatched,
    'tech_accepted' => OrderStatus.techAccepted,
    'boss_opened' => OrderStatus.bossOpened,
    'installing' => OrderStatus.installing,
    'done' => OrderStatus.done,
    'failed' => OrderStatus.failed,
    'cancelled' => OrderStatus.cancelled,
    'follow_up' => OrderStatus.followUp,
    _ => OrderStatus.listed,
  };
}

DateTime parseApiTime(String? value) {
  if (value == null || value.isEmpty) return DateTime.now();
  return DateTime.tryParse(value.replaceFirst(' ', 'T')) ?? DateTime.now();
}

class AppOrder {
  AppOrder({
    required this.id,
    required this.orderNo,
    required this.bizType,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.productName,
    required this.carrier,
    required this.createdAt,
    this.remark,
    this.province,
    this.city,
    this.district,
    this.assignedMerchantId,
    this.assignedMerchantName,
    this.createdByUserId,
    this.stockTypeId,
    this.stockTypeName,
    this.commission,
    this.failReason,
    this.deliveryPhotos = const [],
    this.orderIntent,
    this.phoneBrand,
    this.priceRange,
    this.wifiDeviceType,
    this.wifiBizMode,
    this.customerIdNo,
  });

  final String id;
  final String orderNo;
  final BizType bizType;
  final OrderStatus status;
  final String customerName;
  final String customerPhone;
  final String address;
  final String productName;
  final String carrier;
  final DateTime createdAt;
  final String? remark;
  final String? province;
  final String? city;
  final String? district;
  final String? assignedMerchantId;
  final String? assignedMerchantName;
  final String? createdByUserId;
  final String? stockTypeId;
  final String? stockTypeName;
  final double? commission;
  final String? failReason;
  final List<String> deliveryPhotos;

  /// 意向单 / 确定套餐
  final String? orderIntent;
  final String? phoneBrand;
  final String? priceRange;

  /// 4G / 5G
  final String? wifiDeviceType;

  /// 买断 / 租赁
  final String? wifiBizMode;

  /// 收货人身份证号（号卡业务可选）
  final String? customerIdNo;

  factory AppOrder.fromJson(Map<String, dynamic> json) {
    String? s(String key) {
      final v = json[key];
      if (v == null) return null;
      final t = '$v'.trim();
      return t.isEmpty ? null : t;
    }

    return AppOrder(
      id: '${json['id'] ?? ''}',
      orderNo: '${json['orderNo'] ?? ''}',
      bizType: bizTypeFromApi('${json['bizType'] ?? 'haoka'}'),
      status: orderStatusFromApi('${json['status'] ?? 'listed'}'),
      customerName: '${json['customerName'] ?? ''}',
      customerPhone: '${json['customerPhone'] ?? ''}',
      address: '${json['address'] ?? ''}',
      productName: '${json['productName'] ?? ''}',
      carrier: '${json['carrier'] ?? ''}',
      createdAt: parseApiTime(s('createdAt')),
      remark: s('remark'),
      province: s('province'),
      city: s('city'),
      district: s('district'),
      assignedMerchantId: s('assignedMerchantId'),
      assignedMerchantName: s('assignedMerchantName'),
      createdByUserId: s('createdByUserId'),
      stockTypeId: s('stockTypeId'),
      stockTypeName: s('stockTypeName'),
      commission: json['commission'] is num
          ? (json['commission'] as num).toDouble()
          : null,
      failReason: s('failReason'),
      deliveryPhotos:
          (json['deliveryPhotos'] as List?)?.map((e) => '$e').toList() ??
          const [],
      orderIntent: s('orderIntent'),
      phoneBrand: s('phoneBrand'),
      priceRange: s('priceRange'),
      wifiDeviceType: s('wifiDeviceType'),
      wifiBizMode: s('wifiBizMode'),
      customerIdNo: s('customerIdNo'),
    );
  }

  bool get isBroadband => bizType.isBroadband;

  String get bizLabel => stockTypeName ?? bizType.label;

  String? get regionLabel {
    if (province == null && city == null && district == null) return null;
    return [province, city, district].whereType<String>().join(' ');
  }

  String get detailAddress {
    final prefix = '${province ?? ''}${city ?? ''}${district ?? ''}';
    if (prefix.isEmpty) return address;
    return address.startsWith(prefix)
        ? address.substring(prefix.length)
        : address;
  }

  bool matchesSearch(String keyword) {
    final q = keyword.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool hit(String? s) => s != null && s.toLowerCase().contains(q);
    return hit(orderNo) ||
        hit(customerName) ||
        hit(customerPhone) ||
        hit(productName) ||
        hit(address) ||
        hit(carrier) ||
        hit(bizLabel) ||
        hit(status.label) ||
        hit(assignedMerchantName) ||
        hit(regionLabel) ||
        hit(remark) ||
        hit(failReason) ||
        hit(phoneBrand) ||
        hit(priceRange) ||
        hit(orderIntent);
  }
}
