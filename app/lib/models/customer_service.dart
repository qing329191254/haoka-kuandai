import 'package:haoka_app/api/api_client.dart';

/// 客服常见问题与热线配置（仅接口数据）
class CsFaqItem {
  const CsFaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });

  final String category;
  final String question;
  final String answer;
}

class CsQuickReply {
  const CsQuickReply({required this.prompt, required this.reply});

  final String prompt;
  final String reply;
}

class CustomerServiceData {
  static String hotline = '';
  static String workTime = '';
  static List<CsFaqItem> faqs = [];
  static List<CsQuickReply> quickReplies = [];
  static bool loaded = false;
  static bool offline = false;

  static List<String> get categories =>
      <String>{'全部', ...faqs.map((e) => e.category)}.toList();

  static Future<void> refresh() async {
    try {
      final results = await Future.wait([
        Api.get('/api/content/faqs'),
        Api.get('/api/content/service'),
      ]);
      final faqData = Map<String, dynamic>.from(results[0] as Map);
      faqs = (faqData['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(
            (e) => CsFaqItem(
              category: '${e['category'] ?? '其他'}',
              question: '${e['question'] ?? ''}',
              answer: '${e['answer'] ?? ''}',
            ),
          )
          .where((e) => e.question.isNotEmpty && e.answer.isNotEmpty)
          .toList();

      final service = Map<String, dynamic>.from(results[1] as Map);
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
      loaded = true;
      offline = false;
    } catch (_) {
      offline = !loaded;
    }
  }

  static List<CsFaqItem> byCategory(String category) {
    if (category == '全部') return faqs;
    return faqs.where((e) => e.category == category).toList();
  }
}
