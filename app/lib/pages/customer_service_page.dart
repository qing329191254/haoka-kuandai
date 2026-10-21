import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/api/api_client.dart';
import 'package:haoka_app/models/customer_service.dart';
import 'package:haoka_app/store/auth_store.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/app_toast.dart';
import 'package:haoka_app/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 在线客服：气泡聊天（用户侧统一显示「派客邦客服」）。
class CustomerServicePage extends StatefulWidget {
  const CustomerServicePage({super.key});

  @override
  State<CustomerServicePage> createState() => _CustomerServicePageState();
}

class _CustomerServicePageState extends State<CustomerServicePage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  String _conversationId = '';
  String _agentDisplayName = '派客邦客服';
  final List<_ChatMsg> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _showEmoji = false;
  bool _didInitialScroll = false;
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _wsReconnect;
  Timer? _wsPing;
  bool _wsDisposed = false;

  static const _emojis = [
    '😀', '😁', '😂', '🤣', '😊', '😍', '😘', '😜',
    '🤔', '😅', '😭', '😡', '👍', '👎', '🙏', '👏',
    '🎉', '❤️', '🔥', '✅', '❌', '💯', '🤝', '💪',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _wsDisposed = true;
    _wsReconnect?.cancel();
    _wsPing?.cancel();
    _wsSub?.cancel();
    try {
      _ws?.sink.close();
    } catch (_) {}
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await CustomerServiceData.refresh();
    await _loadSession();
    if (mounted) _connectWs();
  }

  Future<void> _loadSession({bool silent = false}) async {
    final showSpinner = !silent && _messages.isEmpty;
    if (showSpinner && mounted) {
      setState(() => _loading = true);
    }
    try {
      final data = Map<String, dynamic>.from(
        await Api.get('/api/app/cs/session') as Map,
      );
      final conv = Map<String, dynamic>.from(data['conversation'] as Map? ?? {});
      final items = (data['messages'] as List? ?? [])
          .map((e) => _ChatMsg.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (!mounted) return;
      final wasEmpty = _messages.isEmpty;
      setState(() {
        _conversationId = '${conv['id'] ?? ''}';
        _agentDisplayName = '${data['agentDisplayName'] ?? '派客邦客服'}';
        _messages
          ..clear()
          ..addAll(items);
        _loading = false;
      });
      if (wasEmpty || !_didInitialScroll) {
        _didInitialScroll = true;
        _scrollToBottom(jump: true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent) AppToast.tip(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent) AppToast.tip(context, '客服加载失败，请稍后重试');
    }
  }

  void _connectWs() {
    _wsReconnect?.cancel();
    _wsPing?.cancel();
    _wsSub?.cancel();
    try {
      _ws?.sink.close();
    } catch (_) {}
    if (_wsDisposed || !mounted) return;
    final token = Api.token;
    if (token == null || token.isEmpty) return;

    try {
      final channel = WebSocketChannel.connect(Api.csWsUri());
      _ws = channel;
      _wsSub = channel.stream.listen(
        _onWsData,
        onError: (_) => _scheduleWsReconnect(),
        onDone: _scheduleWsReconnect,
        cancelOnError: true,
      );
      _wsPing = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _ws?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      });
    } catch (_) {
      _scheduleWsReconnect();
    }
  }

  void _scheduleWsReconnect() {
    _wsPing?.cancel();
    _wsReconnect?.cancel();
    if (_wsDisposed || !mounted) return;
    _wsReconnect = Timer(const Duration(seconds: 3), () {
      if (!_wsDisposed && mounted) _connectWs();
    });
  }

  void _onWsData(dynamic raw) {
    try {
      final data = raw is String
          ? jsonDecode(raw)
          : raw is Map
          ? raw
          : null;
      if (data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final type = '${map['type'] ?? ''}';
      if (type == 'message') {
        final itemRaw = map['item'];
        if (itemRaw is! Map) return;
        final itemMap = Map<String, dynamic>.from(itemRaw);
        final cid = '${itemMap['conversationId'] ?? ''}';
        if (_conversationId.isNotEmpty &&
            cid.isNotEmpty &&
            cid != _conversationId) {
          return;
        }
        final msg = _ChatMsg.fromJson(itemMap);
        if (!mounted || msg.id.isEmpty) return;
        if (_messages.any((e) => e.id == msg.id)) return;
        setState(() => _messages.add(msg));
        _scrollToBottom();
      } else if (type == 'ready') {
        final cid = '${map['conversationId'] ?? ''}';
        if (cid.isNotEmpty) {
          setState(() => _conversationId = cid);
        }
        final name = '${map['agentDisplayName'] ?? ''}';
        if (name.isNotEmpty) {
          setState(() => _agentDisplayName = name);
        }
      }
    } catch (_) {
      /* ignore malformed frames */
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(max);
      } else {
        _scroll.animateTo(
          max,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _showEmoji = false;
    });
    try {
      final data = Map<String, dynamic>.from(
        await Api.post('/api/app/cs/messages', {
          'content': text,
          'msgType': 'text',
        }) as Map,
      );
      final item = _ChatMsg.fromJson(
        Map<String, dynamic>.from(data['item'] as Map? ?? {}),
      );
      _ChatMsg? autoReply;
      final autoRaw = data['autoReply'];
      if (autoRaw is Map) {
        autoReply = _ChatMsg.fromJson(Map<String, dynamic>.from(autoRaw));
      }
      if (!mounted) return;
      _input.clear();
      setState(() {
        if (!_messages.any((e) => e.id == item.id)) {
          _messages.add(item);
        }
        if (autoReply != null && !_messages.any((e) => e.id == autoReply!.id)) {
          _messages.add(autoReply);
        }
        _sending = false;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.tip(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.tip(context, '发送失败，请重试');
    }
  }

  Future<void> _sendImage() async {
    if (_sending) return;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return;
    setState(() => _sending = true);
    try {
      final url = await Api.uploadImage(file.path);
      final data = Map<String, dynamic>.from(
        await Api.post('/api/app/cs/messages', {
          'content': url,
          'msgType': 'image',
        }) as Map,
      );
      final item = _ChatMsg.fromJson(
        Map<String, dynamic>.from(data['item'] as Map? ?? {}),
      );
      if (!mounted) return;
      setState(() {
        if (!_messages.any((e) => e.id == item.id)) {
          _messages.add(item);
        }
        _sending = false;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.tip(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.tip(context, '图片发送失败');
    }
  }

  Future<void> _callHotline() async {
    final phone = CustomerServiceData.hotline.trim();
    if (phone.isEmpty) {
      AppToast.tip(context, '暂未配置客服热线');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      AppToast.tip(context, '无法拨打电话');
      return;
    }
    await launchUrl(uri);
  }

  void _onQuick(CsQuickReply q) {
    final text = q.prompt.trim();
    if (text.isNotEmpty) _sendText(text);
  }

  bool _showTime(_ChatMsg cur, _ChatMsg? prev) {
    if (prev == null) return true;
    try {
      final a = DateTime.parse(prev.createdAt.replaceFirst(' ', 'T'));
      final b = DateTime.parse(cur.createdAt.replaceFirst(' ', 'T'));
      return b.difference(a).inMinutes >= 5;
    } catch (_) {
      return cur.createdAt != prev.createdAt;
    }
  }

  String _formatTime(String raw) {
    if (raw.length >= 16) return raw.substring(5, 16);
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;
    final quick = CustomerServiceData.quickReplies;

    final workTime = CustomerServiceData.workTime.trim();
    final headerSubtitle = workTime.isEmpty
        ? '在线沟通 · 有问题随时找我们'
        : '在线沟通 · 服务时间 $workTime';

    return SoftPageScaffold(
      body: Column(
        children: [
          SoftPageHeader(
            title: '人工客服',
            subtitle: headerSubtitle,
          ),
          _Banner(
            hotline: CustomerServiceData.hotline,
            onCall: _callHotline,
          ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final msg = _messages[i];
                        final prev = i > 0 ? _messages[i - 1] : null;
                        return Column(
                          children: [
                            if (_showTime(msg, prev))
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  _formatTime(msg.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF9AA3B2),
                                  ),
                                ),
                              ),
                            _Bubble(
                              msg: msg,
                              agentName: _agentDisplayName,
                              user: user,
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (quick.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '快捷问题',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9AA3B2)),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: quick.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final q = quick[i];
                          return ActionChip(
                            label: Text(
                              q.prompt,
                              style: const TextStyle(fontSize: 13),
                            ),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFE0E4EA)),
                            onPressed: _sending ? null : () => _onQuick(q),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            _InputBar(
              controller: _input,
              sending: _sending,
              showEmoji: _showEmoji,
              onToggleEmoji: () => setState(() => _showEmoji = !_showEmoji),
              onSend: () => _sendText(_input.text),
              onPickImage: _sendImage,
            ),
            if (_showEmoji)
              _EmojiPanel(
                emojis: _emojis,
                onPick: (e) {
                  final t = _input.text;
                  final sel = _input.selection;
                  final start = sel.start >= 0 ? sel.start : t.length;
                  final end = sel.end >= 0 ? sel.end : t.length;
                  final next = t.replaceRange(start, end, e);
                  _input.value = TextEditingValue(
                    text: next,
                    selection: TextSelection.collapsed(offset: start + e.length),
                  );
                },
              ),
          ],
        ),
    );
  }
}

class _ChatMsg {
  _ChatMsg({
    required this.id,
    required this.senderType,
    required this.msgType,
    required this.content,
    required this.createdAt,
    required this.displayName,
  });

  factory _ChatMsg.fromJson(Map<String, dynamic> j) {
    return _ChatMsg(
      id: '${j['id'] ?? ''}',
      senderType: '${j['senderType'] ?? 'user'}',
      msgType: '${j['msgType'] ?? 'text'}',
      content: '${j['content'] ?? ''}',
      createdAt: '${j['createdAt'] ?? ''}',
      displayName: '${j['displayName'] ?? ''}',
    );
  }

  final String id;
  final String senderType;
  final String msgType;
  final String content;
  final String createdAt;
  final String displayName;

  bool get isMine => senderType == 'user';
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.hotline,
    required this.onCall,
  });

  final String hotline;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final phone = hotline.trim();
    if (phone.isEmpty) return const SizedBox.shrink();

    // 不另铺底色，避免与整页渐变形成接缝；只用描边卡片浮在同一背景上
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onCall,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppStyle.brand.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.phone_in_talk_outlined,
                    color: AppStyle.brand,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '客服热线 $phone（点击拨打）',
                    style: const TextStyle(
                      color: AppStyle.title,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppStyle.chevron,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.msg,
    required this.agentName,
    required this.user,
  });

  final _ChatMsg msg;
  final String agentName;
  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    final mine = msg.isMine;
    final avatar = mine
        ? (user == null
            ? CircleAvatar(
                radius: 18,
                backgroundColor: AppStyle.brand.withValues(alpha: 0.15),
                child: const Icon(Icons.person, size: 18, color: AppStyle.brand),
              )
            : UserAvatar.fromUser(user!, radius: 18))
        : CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE8F1FF),
            child: Icon(Icons.support_agent, size: 18, color: AppStyle.brand),
          );

    final name = mine ? '我' : agentName;
    final bubbleColor = mine ? const Color(0xFF95EC69) : Colors.white;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(mine ? 14 : 4),
      bottomRight: Radius.circular(mine ? 4 : 14),
    );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
      padding: msg.msgType == 'image'
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: msg.msgType == 'image'
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                msg.content,
                width: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('图片加载失败', style: TextStyle(fontSize: 13)),
                ),
              ),
            )
          : Text(
              msg.content,
              style: const TextStyle(fontSize: 15, height: 1.4, color: AppStyle.title),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!mine) ...[avatar, const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9AA3B2)),
                  ),
                ),
                bubble,
              ],
            ),
          ),
          if (mine) ...[const SizedBox(width: 8), avatar],
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.showEmoji,
    required this.onToggleEmoji,
    required this.onSend,
    required this.onPickImage,
  });

  final TextEditingController controller;
  final bool sending;
  final bool showEmoji;
  final VoidCallback onToggleEmoji;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.of(context).padding.bottom * 0.35,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onToggleEmoji,
            icon: Icon(
              showEmoji ? Icons.keyboard_alt_outlined : Icons.emoji_emotions_outlined,
              color: AppStyle.subtitle,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: '请输入',
                filled: true,
                fillColor: const Color(0xFFF5F7FB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: sending ? null : onPickImage,
            icon: const Icon(Icons.add_circle_outline, color: AppStyle.subtitle),
          ),
          IconButton(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, color: AppStyle.brand),
          ),
        ],
      ),
    );
  }
}

class _EmojiPanel extends StatelessWidget {
  const _EmojiPanel({required this.emojis, required this.onPick});

  final List<String> emojis;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: const Color(0xFFF7F8FA),
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        itemCount: emojis.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemBuilder: (context, i) {
          final e = emojis[i];
          return InkWell(
            onTap: () => onPick(e),
            borderRadius: BorderRadius.circular(8),
            child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
          );
        },
      ),
    );
  }
}
