import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/api/api_client.dart';
import 'package:haoka_app/models/customer_service.dart';
import 'package:haoka_app/store/auth_store.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/app_toast.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerServicePage extends StatefulWidget {
  const CustomerServicePage({super.key});

  @override
  State<CustomerServicePage> createState() => _CustomerServicePageState();
}

class _CustomerServicePageState extends State<CustomerServicePage> {
  String _category = '全部';
  bool _faqExpanded = false;
  bool _loadingCfg = true;
  bool _submitting = false;
  bool _submitted = false;
  String _msgType = '订单相关';
  String? _selectedQuickPrompt;
  int _messageTotal = 0;
  int _messagePending = 0;

  final _input = TextEditingController();
  final _msgKey = GlobalKey();
  final _faqPreviewLimit = 5;

  static const _msgTypes = ['订单相关', '入驻咨询', '号卡/宽带', '其他'];

  String _typeForQuickPrompt(String prompt) {
    if (prompt.contains('入驻')) return '入驻咨询';
    if (prompt.contains('订单') || prompt.contains('地址') || prompt.contains('取消')) {
      return '订单相关';
    }
    if (prompt.contains('号卡') || prompt.contains('宽带') || prompt.contains('装机')) {
      return '号卡/宽带';
    }
    return '其他';
  }

  List<CsQuickReply> get _quickForType {
    final all = CustomerServiceData.quickReplies;
    final matched = all
        .where((q) => _typeForQuickPrompt(q.prompt) == _msgType)
        .toList();
    // 当前类型没有匹配时，仍展示全部，避免后台未按类型配置时空白。
    return matched.isNotEmpty ? matched : all;
  }

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    await Future.wait([
      CustomerServiceData.refresh(),
      _loadMyMessages(),
    ]);
    if (!mounted) return;
    setState(() => _loadingCfg = false);
  }

  Future<void> _loadMyMessages() async {
    try {
      final data = Map<String, dynamic>.from(
        await Api.get('/api/app/feedbacks') as Map,
      );
      final items = (data['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => '${e['content'] ?? ''}'.trim().isNotEmpty)
          .toList();
      final pending = items
          .where((e) => '${e['status'] ?? ''}' != 'handled')
          .length;
      if (!mounted) return;
      setState(() {
        _messageTotal = items.length;
        _messagePending = pending;
      });
    } catch (_) {
      // 未登录或离线时不展示历史。
    }
  }

  bool get _withinWorkHours {
    final now = DateTime.now();
    if (now.weekday > 5) return false;
    final minutes = now.hour * 60 + now.minute;
    return minutes >= 9 * 60 && minutes < 18 * 60;
  }

  Future<void> _callHotline() async {
    final hotline = CustomerServiceData.hotline.trim();
    if (hotline.isEmpty) {
      AppToast.tip(context, '暂未配置客服热线，请使用在线留言');
      return;
    }
    final digits = hotline.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: digits);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      AppToast.tip(context, '无法打开拨号盘，请手动拨打 $hotline');
    }
  }

  void _scrollToMessage({
    String? draft,
    String? type,
    String? quickPrompt,
    bool clearQuick = false,
  }) {
    if (draft != null) _input.text = draft;
    setState(() {
      if (type != null) _msgType = type;
      if (clearQuick) {
        _selectedQuickPrompt = null;
      } else if (quickPrompt != null) {
        _selectedQuickPrompt = quickPrompt;
      }
      _submitted = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _msgKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.15,
        );
      }
    });
  }

  void _openFaq(CsFaqItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FaqDetailPage(
          item: item,
          onNeedHelp: () {
            Navigator.of(context).pop();
            _scrollToMessage(
              draft: '关于「${item.question}」，我想进一步咨询：',
              type: item.category.contains('入驻')
                  ? '入驻咨询'
                  : item.category.contains('订单')
                  ? '订单相关'
                  : item.category.contains('号卡') ||
                        item.category.contains('宽带')
                  ? '号卡/宽带'
                  : '其他',
            );
          },
        ),
      ),
    );
  }

  Future<void> _submitMessage() async {
    final text = _input.text.trim();
    if (text.length < 5) {
      AppToast.tip(context, '请至少描述 5 个字，方便我们处理');
      return;
    }
    setState(() => _submitting = true);
    final user = context.read<AuthStore>().user;
    try {
      await Api.post('/api/app/feedback', {
        'type': _msgType,
        'content': text,
        'contact': user?.phone ?? '',
        'channel': 'service_message',
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.tip(context, e.message);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.tip(context, '提交失败，请稍后重试或拨打客服热线');
      return;
    }
    if (!mounted) return;
    await _loadMyMessages();
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitted = true;
      _selectedQuickPrompt = null;
      _input.clear();
    });
    AppToast.success(context, '留言已提交，我们会尽快回复');
  }

  List<_QuickAction> _actionsFor(UserProfile? user) {
    final approved = user?.auditStatus == AgentAuditStatus.approved;
    final pending = user?.auditStatus == AgentAuditStatus.pending;
    final rejected = user?.auditStatus == AgentAuditStatus.rejected;
    final onboarding = !approved;

    return [
      if (onboarding)
        _QuickAction(
          icon: Icons.fact_check_outlined,
          label: '入驻进度',
          hint: user == null
              ? '查看审核状态'
              : rejected
              ? '申请未通过'
              : pending
              ? '审核中'
              : user.auditStatus.label,
          onTap: () => context.go(user?.onboardingPath ?? '/audit'),
        ),
      if (approved)
        _QuickAction(
          icon: Icons.receipt_long_outlined,
          label: '我的订单',
          hint: '查看办理进度',
          onTap: () => context.go('/orders'),
        ),
      if (pending)
        _QuickAction(
          icon: Icons.campaign_outlined,
          label: '催一下审核',
          hint: '留言给运营',
          onTap: () => _scrollToMessage(
            draft: '你好，我想催一下入驻审核进度，公司/昵称：${user?.companyName.isNotEmpty == true ? user!.companyName : (user?.nickname ?? '')}',
            type: '入驻咨询',
          ),
        ),
      if (rejected)
        _QuickAction(
          icon: Icons.edit_note_outlined,
          label: '咨询驳回原因',
          hint: '重新申请协助',
          onTap: () => _scrollToMessage(
            draft:
                '入驻被驳回，驳回原因：${user?.rejectReason.isNotEmpty == true ? user!.rejectReason : '（未填写）'}。想了解如何修改后重新提交。',
            type: '入驻咨询',
          ),
        ),
      if (approved)
        _QuickAction(
          icon: Icons.cancel_outlined,
          label: '取消/改址',
          hint: '说明订单号',
          onTap: () => _scrollToMessage(
            draft: '订单号：\n问题：取消订单 / 修改上门地址（请勾选并补充）\n',
            type: '订单相关',
          ),
        ),
      _QuickAction(
        icon: Icons.sim_card_outlined,
        label: '号卡咨询',
        hint: '套餐与覆盖',
        onTap: () => _scrollToMessage(
          draft: '我想咨询号卡，所在城市：\n想了解的套餐：\n',
          type: '号卡/宽带',
        ),
      ),
      _QuickAction(
        icon: Icons.wifi_outlined,
        label: '宽带咨询',
        hint: '装机与开户',
        onTap: () => _scrollToMessage(
          draft: '我想咨询宽带，装机地址：\n是否需要新开卡：\n',
          type: '号卡/宽带',
        ),
      ),
    ];
  }

  Widget _quickServiceTile(List<_QuickAction> actions, int index) {
    if (index >= actions.length) {
      return const SizedBox(height: 48);
    }
    final a = actions[index];
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: a.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppStyle.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(a.icon, size: 18, color: AppStyle.brand),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppStyle.title,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppStyle.subtitle,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppStyle.chevron,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;
    final faqs = CustomerServiceData.byCategory(_category);
    final visibleFaqs = _faqExpanded || faqs.length <= _faqPreviewLimit
        ? faqs
        : faqs.take(_faqPreviewLimit).toList();
    final actions = _actionsFor(user);
    final offHours = !_withinWorkHours;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppStyle.pageBg,
        body: Column(
          children: [
            SoftPageHeader(
              title: '客服中心',
              subtitle:
                  '优先留言沟通 · 服务时间 ${CustomerServiceData.workTime.isEmpty ? '以后台配置为准' : CustomerServiceData.workTime}',
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppStyle.brand,
                onRefresh: _loadConfig,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                          if (offHours) ...[
                            SoftCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.schedule_outlined,
                                    size: 20,
                                    color: AppStyle.brand.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      '当前可能非服务时间，留言将在下一工作时段优先处理。',
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: AppStyle.title,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          SoftCard(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () => _scrollToMessage(),
                                        icon: const Icon(
                                          Icons.chat_bubble_outline,
                                          size: 18,
                                        ),
                                        label: const Text('在线留言'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppStyle.brand,
                                          minimumSize: const Size.fromHeight(
                                            46,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _callHotline,
                                        icon: const Icon(
                                          Icons.phone_in_talk_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('客服热线'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppStyle.brand,
                                          side: BorderSide(
                                            color: AppStyle.brand.withValues(
                                              alpha: 0.45,
                                            ),
                                          ),
                                          minimumSize: const Size.fromHeight(
                                            46,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone_outlined,
                                      size: 16,
                                      color: AppStyle.subtitle,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      CustomerServiceData.hotline.isEmpty
                                          ? '热线未配置'
                                          : CustomerServiceData.hotline,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppStyle.title,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        CustomerServiceData.workTime.isEmpty
                                            ? ''
                                            : CustomerServiceData.workTime,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppStyle.subtitle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '快捷服务',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppStyle.title,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SoftCard(
                            child: Column(
                              children: [
                                for (
                                  var row = 0;
                                  row < (actions.length + 1) ~/ 2;
                                  row++
                                ) ...[
                                  if (row > 0) const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      for (var col = 0; col < 2; col++) ...[
                                        if (col > 0) const SizedBox(width: 8),
                                        Expanded(
                                          child: _quickServiceTile(
                                            actions,
                                            row * 2 + col,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Text(
                                '常见问题',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppStyle.title,
                                ),
                              ),
                              if (_loadingCfg) ...[
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 36,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: CustomerServiceData.categories.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final c = CustomerServiceData.categories[i];
                                final selected = c == _category;
                                return Material(
                                  color: selected
                                      ? AppStyle.brand.withValues(alpha: 0.12)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => setState(() {
                                      _category = c;
                                      _faqExpanded = false;
                                    }),
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: selected
                                              ? AppStyle.brand.withValues(
                                                  alpha: 0.4,
                                                )
                                              : const Color(0xFFE6EAF0),
                                        ),
                                        boxShadow: selected
                                            ? null
                                            : AppStyle.softShadow,
                                      ),
                                      child: Text(
                                        c,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: selected
                                              ? AppStyle.brand
                                              : AppStyle.title,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          SoftCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (var i = 0; i < visibleFaqs.length; i++) ...[
                                  if (i > 0)
                                    const Divider(
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                      color: AppStyle.divider,
                                    ),
                                  InkWell(
                                    onTap: () => _openFaq(visibleFaqs[i]),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              visibleFaqs[i].question,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                height: 1.3,
                                                color: AppStyle.title,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right,
                                            color: AppStyle.chevron,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if (faqs.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 28),
                                    child: Text(
                                      '该分类暂无问题',
                                      style: TextStyle(
                                        color: AppStyle.subtitle,
                                      ),
                                    ),
                                  ),
                                if (faqs.length > _faqPreviewLimit) ...[
                                  const Divider(
                                    height: 1,
                                    color: AppStyle.divider,
                                  ),
                                  InkWell(
                                    onTap: () => setState(
                                      () => _faqExpanded = !_faqExpanded,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Center(
                                        child: Text(
                                          _faqExpanded
                                              ? '收起'
                                              : '查看更多（${faqs.length - _faqPreviewLimit}）',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppStyle.brand,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          KeyedSubtree(
                            key: _msgKey,
                            child: SoftCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '给客服留言',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppStyle.title,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _withinWorkHours
                                        ? '工作时间内一般会在 1–2 小时内回复'
                                        : '非服务时间留言，将在下一工作日优先处理',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppStyle.subtitle,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (_submitted)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Color(0xFF2E7D32),
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                '留言已提交',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF2E7D32),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            '我们已收到你的问题，客服会尽快通过电话或后续联系方式回复。',
                                            style: TextStyle(
                                              fontSize: 13,
                                              height: 1.4,
                                              color: Color(0xFF37474F),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              TextButton(
                                                onPressed: () => setState(
                                                  () => _submitted = false,
                                                ),
                                                child: const Text('再留一条'),
                                              ),
                                              TextButton(
                                                onPressed: () => context.push(
                                                  '/service/messages',
                                                ),
                                                child: const Text('查看我的留言'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    )
                                  else ...[
                                    const Text(
                                      '留言类型',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppStyle.title,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GridView.count(
                                      crossAxisCount: 2,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      childAspectRatio: 3.2,
                                      children: [
                                        for (final t in _msgTypes)
                                          Material(
                                            color: _msgType == t
                                                ? AppStyle.brand.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : const Color(0xFFF3F5F7),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              onTap: () => setState(() {
                                                _msgType = t;
                                                _selectedQuickPrompt = null;
                                              }),
                                              child: Container(
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: _msgType == t
                                                        ? AppStyle.brand
                                                              .withValues(
                                                                alpha: 0.45,
                                                              )
                                                        : Colors.transparent,
                                                  ),
                                                ),
                                                child: Text(
                                                  t,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: _msgType == t
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: _msgType == t
                                                        ? AppStyle.brand
                                                        : AppStyle.title,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (_quickForType.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      const Text(
                                        '快捷填写',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppStyle.title,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        '点选后填入输入框，可再补充细节',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppStyle.subtitle,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _quickForType.map((q) {
                                          final selected =
                                              _selectedQuickPrompt == q.prompt;
                                          return InkWell(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            onTap: () => _scrollToMessage(
                                              draft: '${q.prompt}：\n',
                                              type: _typeForQuickPrompt(
                                                q.prompt,
                                              ),
                                              quickPrompt: q.prompt,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 7,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: selected
                                                    ? AppStyle.brand.withValues(
                                                        alpha: 0.08,
                                                      )
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: selected
                                                      ? AppStyle.brand
                                                            .withValues(
                                                              alpha: 0.5,
                                                            )
                                                      : const Color(0xFFD7DEE8),
                                                  style: BorderStyle.solid,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.edit_note_outlined,
                                                    size: 14,
                                                    color: selected
                                                        ? AppStyle.brand
                                                        : AppStyle.mutedIcon,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    q.prompt,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: selected
                                                          ? AppStyle.brand
                                                          : AppStyle.title,
                                                      fontWeight: selected
                                                          ? FontWeight.w600
                                                          : FontWeight.w400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _input,
                                      maxLines: 5,
                                      minLines: 3,
                                      maxLength: 500,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.45,
                                      ),
                                      decoration: AppStyle.softInput(
                                        hintText:
                                            '描述你的问题，建议附上订单号、城市或联系电话…',
                                      ),
                                    ),
                                    if (user?.phone.isNotEmpty == true) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '将使用登录手机号 ${user!.phone} 作为联系方式',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppStyle.subtitle,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    FilledButton(
                                      onPressed: _submitting
                                          ? null
                                          : _submitMessage,
                                      style: AppStyle.primaryPill,
                                      child: Text(
                                        _submitting ? '提交中…' : '提交留言',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SoftCard(
                            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                            onTap: () async {
                              await context.push('/service/messages');
                              if (mounted) await _loadMyMessages();
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppStyle.brand.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.forum_outlined,
                                    color: AppStyle.brand,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '我的留言',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppStyle.title,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _messageTotal == 0
                                            ? '查看历史留言与客服回复'
                                            : _messagePending > 0
                                            ? '共 $_messageTotal 条 · $_messagePending 条处理中'
                                            : '共 $_messageTotal 条 · 均已回复',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppStyle.subtitle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_messagePending > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF3E0),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$_messagePending',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFEF6C00),
                                      ),
                                    ),
                                  ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppStyle.chevron,
                                ),
                              ],
                            ),
                          ),
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

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
}

class _FaqDetailPage extends StatelessWidget {
  const _FaqDetailPage({required this.item, required this.onNeedHelp});

  final CsFaqItem item;
  final VoidCallback onNeedHelp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppBar(
        title: const Text('问题详情'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppStyle.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppStyle.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: AppStyle.title,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppStyle.divider),
                const SizedBox(height: 16),
                Text(
                  item.answer,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Color(0xFF37474F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '没有解决你的问题？',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppStyle.title,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '可以带着这个问题直接留言给客服，我们会尽快回复。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppStyle.subtitle,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onNeedHelp,
                  style: AppStyle.primaryPill,
                  child: const Text('去留言'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
