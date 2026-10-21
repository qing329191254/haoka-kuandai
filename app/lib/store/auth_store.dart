import 'package:flutter/foundation.dart';
import 'package:haoka_app/api/api_client.dart';
import 'package:haoka_app/data/local_merchants.dart';
import 'package:haoka_app/models/customer_service.dart';
import 'package:haoka_app/data/products.dart';

enum UserGender { unknown, male, female }

extension UserGenderX on UserGender {
  String get label => switch (this) {
    UserGender.unknown => '保密',
    UserGender.male => '男',
    UserGender.female => '女',
  };
}

/// 入驻进度：电子签 → 交押金 → 待运营审核 → 通过 / 驳回
enum AgentAuditStatus { needContract, needDeposit, pending, approved, rejected }

extension AgentAuditStatusX on AgentAuditStatus {
  String get label => switch (this) {
    AgentAuditStatus.needContract => '待签合同',
    AgentAuditStatus.needDeposit => '待交押金',
    AgentAuditStatus.pending => '待审核',
    AgentAuditStatus.approved => '已通过',
    AgentAuditStatus.rejected => '已驳回',
  };
}

/// 入驻押金（合作期内占用，解约退还；演示固定档）
const double kAgentDepositAmount = 5000;

class DepositPayResult {
  const DepositPayResult({
    this.error,
    this.paid = false,
    this.needClientPay = false,
    this.orderStr = '',
    this.env = '',
    this.channel = '',
  });

  final String? error;
  final bool paid;
  final bool needClientPay;
  final String orderStr;
  final String env;
  final String channel;
}

class DepositQuote {
  const DepositQuote({
    required this.amount,
    required this.scale,
    required this.scaleLabel,
    required this.scope,
  });

  final double amount;
  final String scale;
  final String scaleLabel;
  final String scope;
}

const agentScaleOptions = <({String id, String label})>[
  (id: 'county', label: '区县级'),
  (id: 'city', label: '地市级'),
  (id: 'province', label: '省级'),
];

/// 预设头像（也可搭配本地相册/拍照）
class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.emoji,
    required this.color,
  });
  final String id;
  final String emoji;
  final int color;

  static const presets = <AvatarOption>[
    AvatarOption(id: 'a1', emoji: '🙂', color: 0xFF90CAF9),
    AvatarOption(id: 'a2', emoji: '😊', color: 0xFFA5D6A7),
    AvatarOption(id: 'a3', emoji: '😎', color: 0xFFFFCC80),
    AvatarOption(id: 'a4', emoji: '🧑‍💼', color: 0xFFCE93D8),
    AvatarOption(id: 'a5', emoji: '👩‍💻', color: 0xFF80CBC4),
    AvatarOption(id: 'a6', emoji: '🧔', color: 0xFFEF9A9A),
    AvatarOption(id: 'a7', emoji: '🦊', color: 0xFFFFAB91),
    AvatarOption(id: 'a8', emoji: '🐱', color: 0xFFFFF59D),
  ];

  static AvatarOption byId(String id) =>
      presets.firstWhere((e) => e.id == id, orElse: () => presets.first);
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.nickname,
    required this.phone,
    this.email = '',
    this.gender = UserGender.unknown,
    this.avatarId = 'a1',
    this.avatarPath,
    this.companyName = '',
    this.auditStatus = AgentAuditStatus.needContract,
    this.rejectReason = '',
    this.depositAmount = kAgentDepositAmount,
    this.scale = 'city',
    this.scaleLabel = '地市级',
    this.depositPaid = false,
    this.depositPaidAt = '',
    this.contractSigned = false,
    this.contractSignedAt = '',
    this.contractNo = '',
    this.signerName = '',
  });

  final String id;
  final String nickname;
  final String phone;
  final String email;
  final UserGender gender;
  final String avatarId;
  final String? avatarPath;
  final String companyName;
  final AgentAuditStatus auditStatus;
  final String rejectReason;
  final double depositAmount;
  final String scale;
  final String scaleLabel;
  final bool depositPaid;
  final String depositPaidAt;
  final bool contractSigned;
  final String contractSignedAt;
  final String contractNo;
  final String signerName;

  AvatarOption get avatar => AvatarOption.byId(avatarId);

  String get name => nickname;
  String get avatarLabel =>
      nickname.isNotEmpty ? nickname.substring(0, 1) : '代';

  bool get canPlaceOrder => auditStatus == AgentAuditStatus.approved;

  /// 入驻未完成前的下一步路由
  String get onboardingPath => switch (auditStatus) {
    AgentAuditStatus.needContract => '/audit/contract',
    AgentAuditStatus.needDeposit => '/audit/deposit',
    AgentAuditStatus.pending ||
    AgentAuditStatus.rejected ||
    AgentAuditStatus.approved => '/audit',
  };

  UserProfile copyWith({
    String? nickname,
    String? phone,
    String? email,
    UserGender? gender,
    String? avatarId,
    String? avatarPath,
    bool clearAvatarPath = false,
    String? companyName,
    AgentAuditStatus? auditStatus,
    String? rejectReason,
    double? depositAmount,
    String? scale,
    String? scaleLabel,
    bool? depositPaid,
    String? depositPaidAt,
    bool? contractSigned,
    String? contractSignedAt,
    String? contractNo,
    String? signerName,
  }) {
    return UserProfile(
      id: id,
      nickname: nickname ?? this.nickname,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      avatarId: avatarId ?? this.avatarId,
      avatarPath: clearAvatarPath ? null : (avatarPath ?? this.avatarPath),
      companyName: companyName ?? this.companyName,
      auditStatus: auditStatus ?? this.auditStatus,
      rejectReason: rejectReason ?? this.rejectReason,
      depositAmount: depositAmount ?? this.depositAmount,
      scale: scale ?? this.scale,
      scaleLabel: scaleLabel ?? this.scaleLabel,
      depositPaid: depositPaid ?? this.depositPaid,
      depositPaidAt: depositPaidAt ?? this.depositPaidAt,
      contractSigned: contractSigned ?? this.contractSigned,
      contractSignedAt: contractSignedAt ?? this.contractSignedAt,
      contractNo: contractNo ?? this.contractNo,
      signerName: signerName ?? this.signerName,
    );
  }
}

UserGender genderFromApi(String? value) {
  return switch (value) {
    '男' || 'male' => UserGender.male,
    '女' || 'female' => UserGender.female,
    _ => UserGender.unknown,
  };
}

AgentAuditStatus auditFromApi(String? value) {
  return switch (value) {
    'need_contract' || 'needContract' => AgentAuditStatus.needContract,
    'need_deposit' || 'needDeposit' => AgentAuditStatus.needDeposit,
    'pending' => AgentAuditStatus.pending,
    'approved' => AgentAuditStatus.approved,
    'rejected' => AgentAuditStatus.rejected,
    _ => AgentAuditStatus.needContract,
  };
}

class AuthStore extends ChangeNotifier {
  UserProfile? _user;
  Future<void>? _restoreFuture;

  AuthStore() {
    _restoreFuture = restore();
  }

  Future<void> get ready => _restoreFuture ?? Future.value();

  final ValueNotifier<int> sessionVersion = ValueNotifier<int>(0);

  UserProfile? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get canPlaceOrder => _user?.canPlaceOrder == true;

  void _bumpSession() => sessionVersion.value++;

  UserProfile _profileFrom(Map<String, dynamic> json) {
    final amount = json['depositAmount'];
    final rawAvatar = '${json['avatarId'] ?? 'a1'}';
    final isUrl = rawAvatar.startsWith('http');
    return UserProfile(
      id: '${json['id'] ?? ''}',
      nickname: '${json['nickname'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      email: '${json['email'] ?? ''}',
      gender: genderFromApi('${json['gender'] ?? ''}'),
      avatarId: isUrl || rawAvatar.isEmpty ? 'a1' : rawAvatar,
      avatarPath: isUrl ? rawAvatar : null,
      companyName: '${json['companyName'] ?? ''}',
      auditStatus: auditFromApi('${json['auditStatus'] ?? ''}'),
      rejectReason: '${json['rejectReason'] ?? ''}',
      depositAmount: amount is num ? amount.toDouble() : kAgentDepositAmount,
      scale: '${json['scale'] ?? 'city'}',
      scaleLabel: '${json['scaleLabel'] ?? '地市级'}',
      depositPaid: json['depositPaid'] == true,
      depositPaidAt: '${json['depositPaidAt'] ?? ''}',
      contractSigned: json['contractSigned'] == true,
      contractSignedAt: '${json['contractSignedAt'] ?? ''}',
      contractNo: '${json['contractNo'] ?? ''}',
      signerName: '${json['signerName'] ?? ''}',
    );
  }

  void _applyUser(Map<String, dynamic> json) {
    _user = _profileFrom(json);
    notifyListeners();
    _bumpSession();
  }

  String? _validatePhone(String phone) {
    final p = phone.trim();
    if (p.length != 11 || int.tryParse(p) == null) return '请输入正确的手机号';
    return null;
  }

  Future<void> restore() async {
    await Api.init();
    await Future.wait([
      CatalogProducts.refresh(),
      LocalMerchants.refresh(),
      CustomerServiceData.refresh(),
    ]);
    if (Api.token == null || Api.token!.isEmpty) return;
    try {
      await refreshMe();
    } catch (_) {
      await Api.clearToken();
      _user = null;
    }
  }

  Future<void> refreshMe() async {
    final me = await Api.get('/api/app/me');
    _applyUser(Map<String, dynamic>.from(me as Map));
  }

  Future<String?> _afterAuth(dynamic data) async {
    final map = Map<String, dynamic>.from(data as Map);
    final token = '${map['token'] ?? ''}';
    if (token.isEmpty) return '登录失败';
    await Api.saveToken(token);
    final user = map['user'];
    if (user is Map) {
      _applyUser(Map<String, dynamic>.from(user));
    } else {
      final me = await Api.get('/api/app/me');
      _applyUser(Map<String, dynamic>.from(me as Map));
    }
    await Future.wait([
      CatalogProducts.refresh(),
      LocalMerchants.refresh(),
      CustomerServiceData.refresh(),
    ]);
    return null;
  }

  Future<String?> login({
    required String phone,
    required String password,
  }) async {
    final err = _validatePhone(phone);
    if (err != null) return err;
    if (password.trim().length < 6) return '密码至少 6 位';
    try {
      final data = await Api.post('/api/app/auth/login', {
        'phone': phone.trim(),
        'password': password.trim(),
      });
      return _afterAuth(data);
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> loginBySms({
    required String phone,
    required String code,
  }) async {
    final err = _validatePhone(phone);
    if (err != null) return err;
    try {
      final data = await Api.post('/api/app/auth/login-sms', {
        'phone': phone.trim(),
        'code': code.trim(),
      });
      return _afterAuth(data);
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> submitApplication({
    required String phone,
    required String password,
    required String code,
    required String contact,
    required String companyName,
    required String province,
    required String city,
    required String district,
    required String address,
    required String wechat,
    required String backupPhone,
    required String idNo,
    required String licensePath,
    required String remark,
    String scale = 'city',
  }) async {
    final err = _validatePhone(phone);
    if (err != null) return err;
    if (password.trim().length < 6) return '密码至少 6 位';
    if (contact.trim().isEmpty) return '请填写联系人姓名';
    if (companyName.trim().isEmpty) return '请填写公司 / 门店名称';
    if (province.isEmpty || city.isEmpty || district.isEmpty) return '请选择合作区域';
    if (address.trim().isEmpty) return '请填写详细地址';
    if (idNo.trim().isEmpty) return '请填写身份证号或统一社会信用代码';
    if (licensePath.trim().isEmpty) return '请上传证件照片';
    try {
      var licenseName = licensePath.trim();
      if (!licenseName.startsWith('http')) {
        licenseName = await Api.uploadImage(licensePath, apply: true);
      }
      final data = await Api.post('/api/app/auth/register', {
        'phone': phone.trim(),
        'password': password.trim(),
        'code': code.trim(),
        'contact': contact.trim(),
        'companyName': companyName.trim(),
        'province': province,
        'city': city,
        'district': district,
        'address': address.trim(),
        'wechat': wechat.trim(),
        'backupPhone': backupPhone.trim(),
        'idNo': idNo.trim(),
        'licenseName': licenseName,
        'remark': remark.trim(),
        'scale': scale,
      });
      return _afterAuth(data);
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<DepositQuote?> quoteDeposit({
    required String province,
    required String city,
    required String scale,
  }) async {
    try {
      final data = await Api.get('/api/deposit-quote', query: {
        'province': province,
        'city': city,
        'scale': scale,
      });
      if (data is! Map) return null;
      final amount = data['amount'];
      return DepositQuote(
        amount: amount is num ? amount.toDouble() : kAgentDepositAmount,
        scale: '${data['scale'] ?? scale}',
        scaleLabel: '${data['scaleLabel'] ?? ''}',
        scope: '${data['scope'] ?? ''}',
      );
    } on ApiException {
      return null;
    }
  }

  Future<String?> signContract({required String signerName}) async {
    final name = signerName.trim();
    if (name.isEmpty) return '请填写签署人姓名';
    if (name.length < 2) return '请填写真实姓名';
    if (_user == null) return '请先登录';
    try {
      final data = await Api.post('/api/app/me/contract', {'signerName': name});
      _applyUser(Map<String, dynamic>.from(data as Map));
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<DepositPayResult> payDeposit({String channel = 'alipay'}) async {
    if (_user == null) {
      return const DepositPayResult(error: '请先登录');
    }
    try {
      final data = await Api.post('/api/app/me/deposit', {'channel': channel});
      final map = Map<String, dynamic>.from(data as Map);
      final user = map['user'];
      if (user is Map) {
        _applyUser(Map<String, dynamic>.from(user));
      }
      final paymentRaw = map['payment'];
      final payment = paymentRaw is Map
          ? Map<String, dynamic>.from(paymentRaw)
          : <String, dynamic>{};
      final paid = payment['paid'] == true;
      final needClientPay = payment['needClientPay'] == true;
      final orderStr = '${payment['orderStr'] ?? ''}';
      return DepositPayResult(
        paid: paid,
        needClientPay: needClientPay,
        orderStr: orderStr,
        env: '${payment['env'] ?? ''}',
        channel: '${payment['channel'] ?? channel}',
      );
    } on ApiException catch (e) {
      return DepositPayResult(error: e.message);
    }
  }

  Future<String?> sendSmsCode(String phone) async {
    final err = _validatePhone(phone);
    if (err != null) return err;
    try {
      await Api.post('/api/app/auth/sms', {'phone': phone.trim()});
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    final err = _validatePhone(phone);
    if (err != null) return err;
    if (newPassword.trim().length < 6) return '密码至少 6 位';
    try {
      await Api.post('/api/app/auth/reset-password', {
        'phone': phone.trim(),
        'code': code.trim(),
        'password': newPassword.trim(),
      });
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> updateProfile({
    String? nickname,
    String? email,
    UserGender? gender,
    String? avatarId,
    String? avatarPath,
    bool clearAvatarPath = false,
  }) async {
    if (_user == null) return '请先登录';
    try {
      var nextAvatarId = avatarId;
      if (avatarPath != null && avatarPath.trim().isNotEmpty) {
        nextAvatarId = await Api.uploadImage(avatarPath);
      }
      final data = await Api.put('/api/app/me', {
        'nickname': ?nickname,
        'email': ?email,
        'gender': ?gender?.label,
        'avatarId': ?nextAvatarId,
        if (_user!.companyName.isNotEmpty) 'companyName': _user!.companyName,
      });
      final next = _profileFrom(Map<String, dynamic>.from(data as Map));
      _user = next.copyWith(
        avatarPath: next.avatarPath ?? (clearAvatarPath ? null : avatarPath),
        clearAvatarPath: clearAvatarPath && next.avatarPath == null,
      );
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async {
    _user = null;
    await Api.clearToken();
    notifyListeners();
    _bumpSession();
  }
}
