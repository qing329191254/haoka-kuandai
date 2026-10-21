import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/api/api_client.dart';
import 'package:haoka_app/store/auth_store.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/app_toast.dart';

/// 电子签：代理合作协议（正文来自后台内容接口；签章服务待对接）
class ContractSignPage extends StatefulWidget {
  const ContractSignPage({super.key});

  @override
  State<ContractSignPage> createState() => _ContractSignPageState();
}

class _ContractSignPageState extends State<ContractSignPage> {
  final _name = TextEditingController();
  bool _agreed = false;
  bool _loading = false;
  bool _docLoading = true;
  String _docTitle = '派客邦代理合作协议';
  String _docBody = '';
  String? _docError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final u = context.read<AuthStore>().user;
      if (u != null && _name.text.isEmpty) {
        _name.text = u.nickname;
      }
    });
    _loadDoc();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadDoc() async {
    setState(() {
      _docLoading = true;
      _docError = null;
    });
    try {
      final data = Map<String, dynamic>.from(
        await Api.get('/api/content/docs/contract') as Map,
      );
      final sections = (data['sections'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((e) {
            final h = '${e['heading'] ?? ''}'.trim();
            final b = '${e['body'] ?? ''}'.trim();
            if (h.isEmpty && b.isEmpty) return '';
            if (h.isEmpty) return b;
            if (b.isEmpty) return h;
            return '$h\n$b';
          })
          .where((e) => e.isNotEmpty)
          .join('\n\n');
      if (!mounted) return;
      setState(() {
        _docTitle = '${data['title'] ?? _docTitle}';
        _docBody = sections;
        _docLoading = false;
        _docError = sections.isEmpty ? '暂无协议内容，请联系运营配置' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _docLoading = false;
        _docError = e is ApiException ? e.message : '协议加载失败';
      });
    }
  }

  Future<void> _sign() async {
    if (_docBody.isEmpty) {
      AppToast.tip(context, '协议内容未加载完成');
      return;
    }
    if (!_agreed) {
      AppToast.tip(context, '请先阅读并同意协议条款');
      return;
    }
    setState(() => _loading = true);
    final err = await context.read<AuthStore>().signContract(
      signerName: _name.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      AppToast.error(context, err);
      return;
    }
    AppToast.success(context, '签署成功，请缴纳保证金');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    context.go('/audit/deposit');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;
    final deposit = user?.depositAmount ?? kAgentDepositAmount;

    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar(
        '电子签合同',
        actions: [
          TextButton(
            onPressed: () {
              context.read<AuthStore>().logout();
              context.go('/login');
            },
            child: const Text('退出'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _docTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppStyle.title,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '请先确认协议条款（含保证金 ¥${deposit.toStringAsFixed(0)}）。签署后前往缴纳保证金，运营审核通过即可转手下单。',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppStyle.subtitle,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE6EAF0)),
                  ),
                  child: _docLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _docError != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _docError!,
                              style: const TextStyle(color: AppStyle.subtitle),
                            ),
                            TextButton(
                              onPressed: _loadDoc,
                              child: const Text('重新加载'),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Text(
                            _docBody,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.55,
                              color: Color(0xFF455A64),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '签署人',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    hintText: '请输入真实姓名（电子签）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _agreed,
                  onChanged: _docBody.isEmpty
                      ? null
                      : (v) => setState(() => _agreed = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    '我已阅读并同意《$_docTitle》',
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
                if (user != null)
                  Text(
                    '主体：${user.companyName.isEmpty ? user.nickname : user.companyName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppStyle.mutedIcon,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: AppStyle.primaryPill,
            onPressed: _loading || _docBody.isEmpty ? null : _sign,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('确认电子签署'),
          ),
        ],
      ),
    );
  }
}
