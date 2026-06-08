import 'package:flutter/material.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'core/router.dart';
import 'core/storage.dart';
import 'providers/auth_provider.dart';
import 'providers/boutique_provider.dart';
import 'providers/products_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/customers_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/coupons_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/reviews_provider.dart';
import 'providers/traffic_provider.dart';
import 'providers/messages_provider.dart';
import 'providers/public_cart_provider.dart';
import 'providers/public_wishlist_provider.dart';
import 'providers/public_messages_provider.dart';
import 'providers/websocket_provider.dart';
import 'services/app_link_handler.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  usePathUrlStrategy();
  final storedLocaleCode = await AppStorage().getLocaleCode();
  final startLocale = storedLocaleCode != null && storedLocaleCode.isNotEmpty ? Locale(storedLocaleCode) : null;

  ErrorWidget.builder = (() {
    String lastMsg = '';
    int repeatCount = 0;
    return (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg == lastMsg) {
        repeatCount++;
        if (repeatCount > 2) return const SizedBox.shrink();
      } else {
        lastMsg = msg;
        repeatCount = 0;
      }
      final userMsg = msg.contains('FlutterQuillLocalizations')
          ? tr('common.error')
          : msg.contains('RenderViewport')
              ? tr('common.error')
              : tr('common.error');
      return ColoredBox(
        color: Color(0xFFFFF3F0),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(userMsg, style: TextStyle(color: Color(0xFFD32F2F), fontSize: 14)),
        ),
      );
    };
  })();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      path: 'assets/i18n',
      fallbackLocale: const Locale('fr'),
      startLocale: startLocale,
      saveLocale: true,
      child: const MakeWebsiteApp(),
    ),
  );
}

class MakeWebsiteApp extends StatefulWidget {
  const MakeWebsiteApp({super.key});

  @override
  State<MakeWebsiteApp> createState() => _MakeWebsiteAppState();
}

class _MakeWebsiteAppState extends State<MakeWebsiteApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BoutiqueProvider()),
        ChangeNotifierProvider(create: (_) => ProductsProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => CustomersProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
        ChangeNotifierProvider(create: (_) => PosProvider()),
        ChangeNotifierProvider(create: (_) => CouponsProvider()),
        ChangeNotifierProvider(create: (_) => AiProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => ReviewsProvider()),
        ChangeNotifierProvider(create: (_) => TrafficProvider()),
        ChangeNotifierProvider(create: (_) => MessagesProvider()),
        ChangeNotifierProvider(create: (_) => PublicCartProvider()),
        ChangeNotifierProvider(create: (_) => PublicWishlistProvider()),
        ChangeNotifierProvider(create: (_) => PublicMessagesProvider()),
        ChangeNotifierProvider(create: (_) => WebSocketProvider()),
      ],
      builder: (context, _) {
        final auth = context.read<AuthProvider>();
        final bp = context.read<BoutiqueProvider>();

        // Wire up: on logout, clear boutique provider state
        auth.onLogout = () => bp.clear();

        _router ??= createRouter(auth);
        unawaited(AppLinkHandler.instance.attach(_router!));

        return MaterialApp.router(
          title: 'MakeWebsite',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: _router!,
          locale: context.locale,
          localizationsDelegates: [
            ...context.localizationDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: context.supportedLocales,
        );
      },
    );
  }
}
