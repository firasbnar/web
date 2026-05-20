import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'core/router.dart';
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
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

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
          ? 'Éditeur de texte non disponible'
          : msg.contains('RenderViewport')
              ? 'Erreur d\'affichage'
              : 'Une erreur est survenue';
      return ColoredBox(
        color: Color(0xFFFFF3F0),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(userMsg, style: TextStyle(color: Color(0xFFD32F2F), fontSize: 14)),
        ),
      );
    };
  })();
  runApp(const MakeWebsiteApp());
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
      ],
      builder: (context, _) {
        _router ??= createRouter(context.read<AuthProvider>());

        return MaterialApp.router(
          title: 'MakeWebsite',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: _router!,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('fr', 'FR'),
            Locale('en', 'US'),
          ],
        );
      },
    );
  }
}
