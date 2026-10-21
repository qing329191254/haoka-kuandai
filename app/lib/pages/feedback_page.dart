import 'package:flutter/material.dart';
import 'package:haoka_app/api/api_client.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/app_toast.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _content = TextEditingController();
  final _contact = TextEditingController();
  String _type = '功能建议';
  bool _submitting = false;

  static const _types = ['功能建议', '体验问题', '订单相关', '入驻咨询', '号卡/宽带', '其他'];

  @override
  void dispose() {
    _content.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_content.text.trim().length < 5) {
      AppToast.tip(context, '请至少填写 5 个字的反馈内容');
      return;
    }
    setState(() => _submitting = true);
    try {
      await Api.post('/api/app/feedback', {
        'type': _type,
        'content': _content.text.trim(),
        'contact': _contact.text.trim(),
        'channel': 'app_feedback',
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.tip(context, e.message);
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    AppToast.success(context, '反馈已提交，我们会尽快处理');
    Navigator.of(context).pop();
  }

  InputDecoration _fieldDecoration(String hint) {
    return AppStyle.softInput(hintText: hint);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar('意见反馈'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '反馈类型',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppStyle.title,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _types.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 40,
                  ),
                  itemBuilder: (context, i) {
                    final t = _types[i];
                    final selected = _type == t;
                    return Material(
                      color: selected
                          ? AppStyle.brand.withValues(alpha: 0.1)
                          : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _type = t),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? AppStyle.brand
                                  : const Color(0xFFE8E8E8),
                            ),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected ? AppStyle.brand : AppStyle.title,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '反馈内容',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppStyle.title,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _content,
                  maxLines: 6,
                  maxLength: 500,
                  style: const TextStyle(fontSize: 15, height: 1.45),
                  decoration: _fieldDecoration('请描述您的问题或建议…'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '联系方式（选填）',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppStyle.title,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contact,
                  style: const TextStyle(fontSize: 15),
                  decoration: _fieldDecoration('手机号 / 微信，方便我们回复'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: AppStyle.primaryPill,
            child: Text(_submitting ? '提交中…' : '提交反馈'),
          ),
        ],
      ),
    );
  }
}
