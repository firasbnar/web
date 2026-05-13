import 'package:flutter/material.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MakeWebsiteApp());
}

class MakeWebsiteApp extends StatelessWidget {
  const MakeWebsiteApp({super.key});

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
       ],
      builder: (context, _) {
        final auth = context.watch<AuthProvider>();
        return MaterialApp.router(
          title: 'MakeWebsite',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: createRouter(auth),
        );
      },
    );
  }
}
