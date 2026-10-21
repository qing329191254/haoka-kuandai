import 'package:flutter/material.dart';
import 'package:haoka_app/api/api_client.dart';
import 'package:haoka_app/widgets/app_surface.dart';

class DocSection {
  const DocSection(this.heading, this.body);
  final String heading;
  final String body;
}

/// 用户协议 / 隐私政策 / 帮助中心：仅展示接口内容。
class DocPage extends StatefulWidget {
  const DocPage({
    super.key,
    required this.docId,
    required this.title,
  });

  final String docId;
  final String title;

  @override
  State<DocPage> createState() => _DocPageState();
}

class _DocPageState extends State<DocPage> {
  late String _title = widget.title;
  List<DocSection> _sections = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = Map<String, dynamic>.from(
        await Api.get('/api/content/docs/${widget.docId}') as Map,
      );
      final sections = (data['sections'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((e) => DocSection('${e['heading'] ?? ''}', '${e['body'] ?? ''}'))
          .where((e) => e.heading.isNotEmpty || e.body.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _title = '${data['title'] ?? widget.title}';
        _sections = sections;
        _loading = false;
        _error = sections.isEmpty ? '暂无内容' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : '加载失败，请稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar(_title),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _sections.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: AppStyle.subtitle)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _refresh, child: const Text('重新加载')),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppStyle.brand,
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: _sections.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final s = _sections[i];
                  return SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.heading,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppStyle.title,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.body,
                          style: const TextStyle(
                            height: 1.55,
                            color: Color(0xFF455A64),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class AgreementPage extends StatelessWidget {
  const AgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocPage(docId: 'agreement', title: '用户协议');
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocPage(docId: 'privacy', title: '隐私政策');
  }
}

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  List<_HelpItem> _items = const [];
  int? _expandedIndex = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  IconData _iconFor(String question) {
    if (question.contains('入驻')) return Icons.badge_outlined;
    if (question.contains('号卡')) return Icons.sim_card_outlined;
    if (question.contains('宽带')) return Icons.router_outlined;
    if (question.contains('客服')) return Icons.support_agent_outlined;
    if (question.contains('个人') || question.contains('账号')) {
      return Icons.person_outline;
    }
    if (question.contains('订单')) return Icons.receipt_long_outlined;
    return Icons.help_outline;
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = Map<String, dynamic>.from(
        await Api.get('/api/content/docs/help') as Map,
      );
      final remote = (data['sections'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(
            (e) => _HelpItem(
              icon: _iconFor('${e['heading'] ?? ''}'),
              question: '${e['heading'] ?? ''}',
              answer: '${e['body'] ?? ''}',
            ),
          )
          .where((e) => e.question.isNotEmpty && e.answer.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _items = remote;
        _loading = false;
        _error = remote.isEmpty ? '暂无帮助内容' : null;
        if (_expandedIndex != null && _expandedIndex! >= _items.length) {
          _expandedIndex = _items.isEmpty ? null : 0;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : '加载失败，请稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar('帮助中心'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: AppStyle.subtitle)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _refresh, child: const Text('重新加载')),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppStyle.brand,
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final item = _items[i];
                  final open = _expandedIndex == i;
                  return SoftCard(
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () =>
                          setState(() => _expandedIndex = open ? null : i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: open
                                ? AppStyle.brand.withValues(alpha: 0.35)
                                : const Color(0x00000000),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SoftIconTile(icon: item.icon, size: 36),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.question,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: open
                                          ? AppStyle.brand
                                          : AppStyle.title,
                                    ),
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: open ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 220),
                                  child: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: open
                                        ? AppStyle.brand
                                        : AppStyle.chevron,
                                  ),
                                ),
                              ],
                            ),
                            AnimatedCrossFade(
                              firstChild: const SizedBox(width: double.infinity),
                              secondChild: Padding(
                                padding: const EdgeInsets.only(
                                  left: 48,
                                  top: 10,
                                  right: 4,
                                ),
                                child: Text(
                                  item.answer,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.55,
                                    color: AppStyle.subtitle,
                                  ),
                                ),
                              ),
                              crossFadeState: open
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 220),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _HelpItem {
  const _HelpItem({
    required this.icon,
    required this.question,
    required this.answer,
  });

  final IconData icon;
  final String question;
  final String answer;
}
