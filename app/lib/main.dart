import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:haoka_app/api/api_client.dart';
import 'package:haoka_app/data/china_regions.dart';
import 'package:haoka_app/router.dart';
import 'package:haoka_app/store/auth_store.dart';
import 'package:haoka_app/store/order_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  // 预加载全国省市区，避免首次打开选择器等待
  ChinaRegions.ensureLoaded();
  runApp(const HaokaApp());
}

class HaokaApp extends StatefulWidget {
  const HaokaApp({super.key});

  @override
  State<HaokaApp> createState() => _HaokaAppState();
}

class _HaokaAppState extends State<HaokaApp> {
  late final AuthStore _auth;
  late final OrderStore _orders;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _auth = AuthStore();
    _orders = OrderStore();
    Api.onUnauthorized = () {
      _auth.logout();
      _orders.clear();
    };
    _router = createRouter(_auth);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _orders),
      ],
      child: MaterialApp.router(
        title: '派客邦',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: Colors.white,
              systemNavigationBarIconBrightness: Brightness.dark,
              systemNavigationBarDividerColor: Colors.transparent,
            ),
          ),
        ),
        routerConfig: _router,
      ),
    );
  }
}
