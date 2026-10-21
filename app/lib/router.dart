import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haoka_app/data/products.dart';
import 'package:haoka_app/models/order.dart';
import 'package:haoka_app/pages/agent_apply_page.dart';
import 'package:haoka_app/pages/audit_status_page.dart';
import 'package:haoka_app/pages/biz_hub_page.dart';
import 'package:haoka_app/pages/contract_sign_page.dart';
import 'package:haoka_app/pages/create_order_page.dart';
import 'package:haoka_app/pages/customer_service_page.dart';
import 'package:haoka_app/pages/deposit_pay_page.dart';
import 'package:haoka_app/pages/doc_pages.dart';
import 'package:haoka_app/pages/feedback_page.dart';
import 'package:haoka_app/pages/forgot_password_page.dart';
import 'package:haoka_app/pages/catalog_product_list_page.dart';
import 'package:haoka_app/pages/catalog_purchase_page.dart';
import 'package:haoka_app/pages/stock_type_list_page.dart';
import 'package:haoka_app/pages/home_page.dart';
import 'package:haoka_app/pages/login_page.dart';
import 'package:haoka_app/pages/my_orders_page.dart';
import 'package:haoka_app/pages/order_detail_page.dart';
import 'package:haoka_app/pages/personal_info_page.dart';
import 'package:haoka_app/pages/profile_page.dart';
import 'package:haoka_app/pages/shell_page.dart';
import 'package:haoka_app/pages/splash_page.dart';
import 'package:haoka_app/store/auth_store.dart';

GoRouter createRouter(AuthStore auth) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth.sessionVersion,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == '/splash') return null;

      final loggedIn = auth.isLoggedIn;
      final approved = auth.canPlaceOrder;
      final onboarding = auth.user?.onboardingPath;
      final onAuthPage =
          loc == '/login' ||
          loc == '/login/apply' ||
          loc == '/login/forgot' ||
          loc == '/login/account' ||
          loc == '/login/register';
      final onPublicDoc =
          loc == '/profile/agreement' || loc == '/profile/privacy';
      final onAuditFlow =
          loc == '/audit' ||
          loc == '/audit/deposit' ||
          loc == '/audit/contract';
      final onService =
          loc == '/service' || loc.startsWith('/service/');

      if (!loggedIn && !onAuthPage && !onPublicDoc) return '/login';

      if (loggedIn && onAuthPage) {
        return approved ? '/' : (onboarding ?? '/audit');
      }

      // 未通过审核：只能走入驻步骤 / 客服 / 协议
      if (loggedIn && !approved && !onAuditFlow && !onService && !onPublicDoc) {
        return onboarding ?? '/audit';
      }

      // 已登录未通过时，强制到当前应完成的步骤
      if (loggedIn &&
          !approved &&
          onAuditFlow &&
          onboarding != null &&
          loc != onboarding) {
        // 允许在 deposit/contract/audit 间按状态纠正
        if (onboarding == '/audit/deposit' ||
            onboarding == '/audit/contract' ||
            onboarding == '/audit') {
          return onboarding;
        }
      }

      if (loggedIn && approved && onAuditFlow) return '/';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/login/apply',
        builder: (context, state) => const AgentApplyPage(),
      ),
      // 兼容旧入口
      GoRoute(path: '/login/account', redirect: (context, state) => '/login'),
      GoRoute(
        path: '/login/register',
        redirect: (context, state) => '/login/apply',
      ),
      GoRoute(
        path: '/login/forgot',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/audit',
        builder: (context, state) => const AuditStatusPage(),
      ),
      GoRoute(
        path: '/audit/deposit',
        builder: (context, state) => const DepositPayPage(),
      ),
      GoRoute(
        path: '/audit/contract',
        builder: (context, state) => const ContractSignPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellPage(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: const HomePage()),
          ),
          GoRoute(
            path: '/orders',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const MyOrdersPage(),
            ),
          ),
          GoRoute(
            path: '/service',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const CustomerServicePage(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ProfilePage(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/service/messages',
        redirect: (context, state) => '/service',
      ),
      GoRoute(
        path: '/profile/info',
        builder: (context, state) => const PersonalInfoPage(),
        routes: [
          GoRoute(
            path: 'avatar',
            builder: (context, state) => const AvatarPreviewPage(),
          ),
          GoRoute(
            path: 'nickname',
            builder: (context, state) => const EditNicknamePage(),
          ),
          GoRoute(
            path: 'gender',
            builder: (context, state) => const EditGenderPage(),
          ),
          GoRoute(
            path: 'email',
            builder: (context, state) => const EditEmailPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/profile/agreement',
        builder: (context, state) => const AgreementPage(),
      ),
      GoRoute(
        path: '/profile/privacy',
        builder: (context, state) => const PrivacyPage(),
      ),
      GoRoute(
        path: '/profile/help',
        builder: (context, state) => const HelpCenterPage(),
      ),
      GoRoute(
        path: '/profile/feedback',
        builder: (context, state) => const FeedbackPage(),
      ),
      GoRoute(
        path: '/haoka/products',
        redirect: (context, state) => '/catalog?type=haoka',
      ),
      GoRoute(
        path: '/catalog',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'haoka';
          final stockTypeId = state.uri.queryParameters['stockTypeId'];
          final stockTypeName = state.uri.queryParameters['stockTypeName'];
          final bizType = switch (type) {
            'wifi' => BizType.wifi,
            'cpe' => BizType.cpe,
            'stock' => BizType.stock,
            _ => BizType.haoka,
          };
          return CatalogProductListPage(
            bizType: bizType,
            stockTypeId: stockTypeId,
            stockTypeName: stockTypeName,
          );
        },
      ),
      GoRoute(
        path: '/broadband',
        builder: (context, state) => const BroadbandHubPage(),
      ),
      GoRoute(path: '/wifi', builder: (context, state) => const WifiHubPage()),
      GoRoute(
        path: '/stock/types',
        builder: (context, state) => const StockTypeListPage(),
      ),
      GoRoute(
        path: '/haoka/purchase',
        redirect: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          return '/catalog/purchase?id=$id';
        },
      ),
      GoRoute(
        path: '/catalog/purchase',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          return _CatalogPurchaseLoader(productId: id);
        },
      ),
      GoRoute(
        path: '/create',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'haoka';
          if (type == 'haoka')
            return const CatalogProductListPage(bizType: BizType.haoka);
          if (type == 'wifi')
            return const CatalogProductListPage(bizType: BizType.wifi);
          if (type == 'cpe')
            return const CatalogProductListPage(bizType: BizType.cpe);
          if (type == 'stock') return const StockTypeListPage();
          final bizType = switch (type) {
            'contract_phone' => BizType.contractPhone,
            'broadband_naked' => BizType.broadbandNaked,
            'broadband_new_card' => BizType.broadbandNewCard,
            'broadband_no_card' => BizType.broadbandNoCard,
            _ => BizType.haoka,
          };
          return CreateOrderPage(bizType: bizType);
        },
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) =>
            OrderDetailPage(id: state.pathParameters['id']!),
      ),
    ],
  );
}

class _CatalogPurchaseLoader extends StatefulWidget {
  const _CatalogPurchaseLoader({required this.productId});

  final String productId;

  @override
  State<_CatalogPurchaseLoader> createState() => _CatalogPurchaseLoaderState();
}

class _CatalogPurchaseLoaderState extends State<_CatalogPurchaseLoader> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!CatalogProducts.loaded || CatalogProducts.byId(widget.productId) == null) {
      await CatalogProducts.refresh();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final product = CatalogProducts.byId(widget.productId);
    if (product == null) {
      return const CatalogProductListPage(bizType: BizType.haoka);
    }
    return CatalogPurchasePage(product: product);
  }
}
