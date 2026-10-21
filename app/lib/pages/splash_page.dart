import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/store/auth_store.dart';

/// 启动页：Logo 首帧即可见（衔接原生静态图），再做明显弹跳 / 标题入场
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _bounce;
  late final AnimationController _content;
  late final AnimationController _dots;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _hintOpacity;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.96), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeInOut));

    _content = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _titleOpacity = CurvedAnimation(parent: _content, curve: Curves.easeOut);
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _content, curve: Curves.easeOutCubic));
    _hintOpacity = CurvedAnimation(
      parent: _content,
      curve: const Interval(0.45, 1, curve: Curves.easeOut),
    );

    // 「...」循环：. → .. → ...
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    await _bounce.forward();
    if (!mounted) return;
    await _bounce.forward(from: 0);
    if (!mounted) return;
    await _content.forward();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await context.read<AuthStore>().ready;
    _goNext();
  }

  void _goNext() {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go('/');
  }

  @override
  void dispose() {
    _bounce.dispose();
    _content.dispose();
    _dots.dispose();
    super.dispose();
  }

  String get _dotText {
    final step = (_dots.value * 3).floor() % 3;
    return ['.', '..', '...'][step];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SizedBox.expand(
          child: Column(
            children: [
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _logoScale,
                builder: (context, child) {
                  return Transform.scale(scale: _logoScale.value, child: child);
                },
                child: Image.asset(
                  'assets/branding/splash_logo.png',
                  width: width * 0.58,
                  filterQuality: FilterQuality.high,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
              const SizedBox(height: 28),
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleOpacity,
                  child: const Column(
                    children: [
                      Text(
                        '派客邦',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1565C0),
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 6,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '号卡 · 宽带 · 一站式服务',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF78909C),
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
              FadeTransition(
                opacity: _hintOpacity,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: AnimatedBuilder(
                    animation: _dots,
                    builder: (context, _) {
                      return Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            color: Color(0xFF78909C),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          children: [
                            const TextSpan(text: '正在进入'),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: SizedBox(
                                width: 28,
                                child: Text(
                                  _dotText,
                                  style: const TextStyle(
                                    color: Color(0xFF78909C),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
