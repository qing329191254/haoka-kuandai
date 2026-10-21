import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:haoka_app/api/api_client.dart';
import 'package:haoka_app/widgets/app_surface.dart';

enum _MsgFilter { all, pending, replied }

/// 客服留言历史：独立页，避免挤在客服首页。
class MyMessagesPage extends StatefulWidget {
  const MyMessagesPage({super.key});

  @override
  State<MyMessagesPage> createState() => _MyMessagesPageState();
}

class _MyMessagesPageState extends State<MyMessagesPage> {
  _MsgFilter _filter = _MsgFilter.all;
  bool _loading = true;
  String? _error;
  final List<_MessageItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = Map<String, dynamic>.from(
        await Api.get('/api/app/feedbacks') as Map,
      );
      final items = (data['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(_MessageItem.fromJson)
          .where((e) => e.content.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败，请下拉重试';
      });
    }
  }

  List<_MessageItem> get _visible {
    return switch (_filter) {
      _MsgFilter.all => _items,
      _MsgFilter.pending => _items.where((e) => !e.handled).toList(),
      _MsgFilter.replied => _items.where((e) => e.handled).toList(),
    };
  }

  int get _pendingCount => _items.where((e) => !e.handled).length;

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppStyle.pageBg,
        appBar: AppStyle.softAppBar(
          '我的留言',
          actions: [
            TextButton(
              onPressed: () => context.go('/service'),
              child: const Text('去留言'),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _FilterChip(
                    label: '全部',
                    count: _items.length,
                    selected: _filter == _MsgFilter.all,
                    onTap: () => setState(() => _filter = _MsgFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '处理中',
                    count: _pendingCount,
                    selected: _filter == _MsgFilter.pending,
                    onTap: () => setState(() => _filter = _MsgFilter.pending),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '已回复',
                    count: _items.length - _pendingCount,
                    selected: _filter == _MsgFilter.replied,
                    onTap: () => setState(() => _filter = _MsgFilter.replied),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppStyle.brand,
                onRefresh: _load,
                child: _buildBody(visible),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<_MessageItem> visible) {
    if (_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: AppStyle.brand)),
        ],
      );
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
        children: [
          Icon(Icons.wifi_off_outlined, size: 48, color: AppStyle.mutedIcon),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppStyle.subtitle, height: 1.4),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(onPressed: _load, child: const Text('重新加载')),
          ),
        ],
      );
    }

    if (visible.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 52,
            color: AppStyle.mutedIcon.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 14),
          Text(
            _items.isEmpty
                ? '还没有留言'
                : _filter == _MsgFilter.pending
                ? '没有处理中的留言'
                : '没有已回复的留言',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppStyle.title,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _items.isEmpty ? '有问题可在客服页留言，我们会尽快回复' : '换个筛选条件看看',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppStyle.subtitle),
          ),
          if (_items.isEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 160,
                child: FilledButton(
                  onPressed: () => context.go('/service'),
                  style: AppStyle.primaryPill,
                  child: const Text('去留言'),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _MessageCard(item: visible[i]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppStyle.brand : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppStyle.brand : const Color(0xFFE6EAF0),
            ),
          ),
          child: Text(
            '$label $count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppStyle.title,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.item});

  final _MessageItem item;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: item.handled
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.handled ? '已回复' : '处理中',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: item.handled
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFEF6C00),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.type,
                style: const TextStyle(fontSize: 12, color: AppStyle.subtitle),
              ),
              const Spacer(),
              Text(
                item.createdAt,
                style: const TextStyle(fontSize: 11, color: AppStyle.subtitle),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppStyle.title,
            ),
          ),
          if (item.reply.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF5FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '客服回复',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppStyle.brand,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.reply,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF37474F),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageItem {
  const _MessageItem({
    required this.type,
    required this.content,
    required this.createdAt,
    required this.handled,
    required this.reply,
  });

  final String type;
  final String content;
  final String createdAt;
  final bool handled;
  final String reply;

  factory _MessageItem.fromJson(Map<String, dynamic> json) {
    return _MessageItem(
      type: '${json['type'] ?? '其他'}',
      content: '${json['content'] ?? ''}',
      createdAt: '${json['createdAt'] ?? ''}',
      handled: '${json['status'] ?? ''}' == 'handled',
      reply: '${json['reply'] ?? ''}',
    );
  }
}
