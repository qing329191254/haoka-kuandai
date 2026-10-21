import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/store/auth_store.dart';
import 'package:haoka_app/widgets/app_loading.dart';
import 'package:haoka_app/widgets/app_surface.dart';
import 'package:haoka_app/widgets/app_toast.dart';

/// 忘记密码：手机号 + 短信验证码 → 设置新密码
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_countdown > 0) return;
    if (_phone.text.trim().length != 11) {
      AppToast.tip(context, '请先输入正确的 11 位手机号');
      return;
    }
    final err = await AppLoading.run(
      context,
      () => context.read<AuthStore>().sendSmsCode(_phone.text),
      message: '发送中…',
    );
    if (!mounted) return;
    if (err != null) {
      AppToast.error(context, err);
      return;
    }
    AppToast.success(context, '验证码已发送');
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        t.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final err = await AppLoading.run(
      context,
      () => context.read<AuthStore>().resetPassword(
        phone: _phone.text,
        code: _code.text,
        newPassword: _password.text,
      ),
      message: '提交中…',
    );
    if (!mounted) return;
    if (err != null) {
      AppToast.error(context, err);
      return;
    }
    AppToast.success(context, '密码已重置，请使用新密码登录');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.pageBg,
      appBar: AppStyle.softAppBar('忘记密码'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '通过短信验证码重置密码',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppStyle.title,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '验证码将发送至您的手机号',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyle.subtitle,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: AppStyle.softInput(
                          labelText: '手机号',
                          prefixIcon: const Icon(Icons.phone_iphone),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length != 11)
                            return '请输入 11 位手机号';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        decoration: AppStyle.softInput(
                          labelText: '短信验证码',
                          prefixIcon: const Icon(Icons.sms_outlined),
                          suffixIcon: TextButton(
                            onPressed: _countdown > 0 ? null : _sendCode,
                            child: Text(
                              _countdown > 0 ? '${_countdown}s' : '获取验证码',
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '请输入验证码';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: AppStyle.softInput(
                          labelText: '新密码',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 6)
                            return '密码至少 6 位';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirm,
                        obscureText: _obscure,
                        decoration: AppStyle.softInput(
                          labelText: '确认新密码',
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        validator: (v) {
                          if (v != _password.text) return '两次密码不一致';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _submit,
                        style: AppStyle.primaryPill,
                        child: const Text(
                          '确认重置',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('返回登录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
