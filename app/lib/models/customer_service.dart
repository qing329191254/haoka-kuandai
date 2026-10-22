import 'package:haoka_app/api/api_client.dart';

class CsQuickReply {
  const CsQuickReply({required this.prompt, required this.reply});

  final String prompt;
  final String reply;
}

/// 客服页配置：热线、服务时间、快捷问题（FAQ 已改由帮助中心/后台维护，App 聊天页不再拉取）。
class CustomerServiceData {
  static String hotline = '';
  static String workTime = '';
  static List<CsQuickReply> quickReplies = [];

  static Future<void> refresh() async {
    try {
      final service = Map<String, dynamic>.from(
        await Api.get('/api/content/service') as Map,
      );
      hotline = '${service['hotline'] ?? ''}'.trim();
      workTime = '${service['workTime'] ?? ''}'.trim();
      quickReplies = (service['quickReplies'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(
            (e) => CsQuickReply(
              prompt: '${e['prompt'] ?? ''}',
              reply: '${e['reply'] ?? ''}',
            ),
          )
          .where((e) => e.prompt.isNotEmpty)
          .toList();
    } catch (_) {
      /* 保留上次缓存 */
    }
  }
}
