import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/landing_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/change_password_screen.dart';

import '../screens/auth/verification_pending_screen.dart';
import '../screens/home/store_dashboard_screen.dart';
import '../screens/home/store_selector_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/products/add_edit_product_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/customers/customer_detail_screen.dart';
import '../screens/pos/pos_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/ai_assistant/ai_assistant_screen.dart';
import '../screens/boutique/boutique_settings_screen.dart';
import '../screens/reviews/reviews_screen.dart';
import '../screens/plans/plans_screen.dart';
import '../screens/coupons/coupons_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/wishlist/wishlist_screen.dart';
import '../screens/checkout/checkout_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/store_catalog/store_catalog_screen.dart';
import '../screens/product_detail/product_detail_screen.dart';
import '../screens/subscription/subscription_dashboard_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/delivery/delivery_company_screen.dart';
import '../screens/create_store/create_store_screen.dart';
import '../screens/stores_browser/stores_browser_screen.dart';
import '../screens/order_history/order_history_screen.dart';
import '../screens/order_tracking/order_tracking_screen.dart';
import '../screens/traffic/traffic_screen.dart';
import '../screens/traffic/traffic_analytics_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/pos_admin_screen.dart';
import '../screens/admin/journal_activite_screen.dart';
import '../screens/super_admin/super_admin_dashboard_screen.dart';
import '../screens/product_manager/product_manager_screen.dart';

import '../screens/products/bulk_add_products_screen.dart';
import '../screens/team/team_screen.dart';

import '../screens/messages/messages_screen.dart';
import '../screens/messages/conversation_screen.dart';
import '../screens/boutique/telegram_settings_screen.dart';
import '../screens/public_storefront/public_storefront_screen.dart';
import '../screens/public_storefront/public_product_detail_screen.dart';
import '../screens/public_storefront/public_cart_screen.dart';
import '../screens/public_storefront/public_checkout_screen.dart';
import '../screens/public_storefront/public_order_success_screen.dart';
import '../models/conversation.dart';
import '../widgets/main_scaffold.dart';

GoRouter createRouter(AuthProvider auth) {
  return GoRouter(
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.uri.toString();
      final isLoggedIn = auth.isAuthenticated;
      final role = auth.role;

      // ignore: avoid_print
      developer.log('[ROUTER] redirect: location="$location" isLoggedIn=$isLoggedIn role=$role');
      // ignore: avoid_print
      print('ROUTER PATH: ${state.uri.path}');

      // Public store routes — no auth required, never redirect to landing/login
      if (state.uri.path.startsWith('/store/')) {
        return null;
      }

      // Root path → landing
      if (location == '/' || location.isEmpty) return '/landing';

      final publicRoutes = ['/landing', '/splash', '/login', '/register', '/signup', '/verify-email', '/forgot-password', '/reset-password', '/public-store'];
      final isPublic = publicRoutes.any((r) => location == r || location.startsWith('$r/') || location.startsWith('$r?'));

      // --- SUPER_ADMIN is platform-level only, no access to owner/merchant routes ---
      if (isLoggedIn && role == 'SUPER_ADMIN') {
        // Allow super admin routes and public routes
        if (location.startsWith('/super-admin')) return null;
        if (isPublic) return '/super-admin'; // redirect from public to super admin
        if (location == '/change-password') return null;
        // Everything else → super admin dashboard
        return '/super-admin';
      }

      // Not logged in → allow public routes, otherwise redirect to login
      if (!isLoggedIn) {
        if (isPublic) return null;
        return '/login';
      }

      // --- LOGGED IN (non-SUPER_ADMIN) ---
      // Redirect away from auth pages to appropriate dashboard
      if (location == '/login' || location.startsWith('/login?') ||
          location == '/register' || location == '/signup' ||
          location == '/landing' || location == '/splash') {
        return role == 'ADMIN' ? '/admin' : '/home';
      }

      // Allow public routes for logged-in users
      if (isPublic) return null;

      // Allow change-password when authenticated
      if (location == '/change-password') return null;

      // Must change password → force to change-password
      if (auth.mustChangePassword && location != '/change-password') return '/change-password';

      // Super admin routes — non-SUPER_ADMIN blocked
      if (location.startsWith('/super-admin')) return '/home';

      // Admin routes
      if ((location == '/admin' || location == '/admin/activities') && role != 'ADMIN') {
        return '/home';
      }
      // Team management (owner or admin only)
      if (location == '/team' && role != 'OWNER' && role != 'ADMIN') {
        return '/home';
      }
      // Caisse admin routes (admin or boutique owner)
      if (location.startsWith('/pos/admin') && role != 'ADMIN' && role != 'OWNER') {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/landing', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/login',
        builder: (_, state) {
          final email = state.uri.queryParameters['email'];
          return LoginScreen(initialEmail: email);
        },
      ),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/verify-email', builder: (_, state) => VerificationPendingScreen(email: state.extra as String? ?? '')),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) {
          final token = state.uri.queryParameters['token'];
          return ResetPasswordScreen(token: token);
        },
      ),
      GoRoute(path: '/change-password', builder: (_, __) => const ChangePasswordScreen()),
      GoRoute(path: '/super-admin', builder: (_, __) => const SuperAdminDashboardScreen()),
      GoRoute(path: '/store/:slug', builder: (_, state) => PublicStorefrontScreen(slug: state.pathParameters['slug']!)),
      GoRoute(path: '/store/:slug/product/:productId', builder: (_, state) => PublicProductDetailScreen(slug: state.pathParameters['slug']!, productId: state.pathParameters['productId']!)),
      GoRoute(path: '/store/:slug/cart', builder: (_, state) => PublicCartScreen(slug: state.pathParameters['slug']!)),
      GoRoute(path: '/store/:slug/checkout', builder: (_, state) => PublicCheckoutScreen(slug: state.pathParameters['slug']!)),
      GoRoute(path: '/store/:slug/order-success/:orderId', builder: (_, state) => PublicOrderSuccessScreen(slug: state.pathParameters['slug']!, orderId: state.pathParameters['orderId']!)),
      ShellRoute(
        builder: (_, __, child) => MainScaffold(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const StoreDashboardScreen()),
          GoRoute(path: '/store-selector', builder: (_, __) => const StoreSelectorScreen()),
          GoRoute(path: '/messages', builder: (_, __) => const MessagesScreen()),
          GoRoute(path: '/messages/:id', builder: (_, state) => ConversationScreen(conversation: state.extra as Conversation)),
          GoRoute(path: '/team', builder: (_, __) => const TeamScreen()),
          GoRoute(path: '/reviews', builder: (_, __) => const ReviewsScreen()),
          GoRoute(path: '/boutique/theme', builder: (_, __) => Scaffold(appBar: AppBar(title: const Text('Theme')))),
          GoRoute(path: '/boutique/template', builder: (_, __) => Scaffold(appBar: AppBar(title: const Text('Template')))),
          GoRoute(path: '/pos/admin', builder: (_, __) => const PosAdminScreen()),
          GoRoute(path: '/telegram', builder: (_, __) => const TelegramSettingsScreen()),
          GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
          GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
          GoRoute(path: '/orders/:id', builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!)),
          GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
          GoRoute(path: '/customers/:id', builder: (_, state) => CustomerDetailScreen(customerId: state.pathParameters['id']!)),
          GoRoute(path: '/pos', builder: (_, __) => const PosScreen()),
          GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
          GoRoute(path: '/delivery', builder: (_, __) => const DeliveryCompanyScreen()),
          GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
          GoRoute(path: '/traffic', builder: (_, __) => const TrafficScreen()),
           GoRoute(path: '/traffic/analytics', builder: (_, __) => const TrafficAnalyticsScreen()),
          GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
          GoRoute(path: '/admin/activities', builder: (_, __) => const JournalActiviteScreen()),
          GoRoute(path: '/payment-settings', redirect: (_, __) => '/boutique-settings'),
          GoRoute(path: '/ai-assistant', builder: (_, __) => const AiAssistantScreen()),
          GoRoute(path: '/boutique-settings', builder: (_, __) => const BoutiqueSettingsScreen()),
          GoRoute(path: '/plans', builder: (_, __) => const PlansScreen()),
          GoRoute(path: '/subscription', builder: (_, __) => const SubscriptionDashboardScreen()),
          GoRoute(path: '/coupons', builder: (_, __) => const CouponsScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/products/add', builder: (_, __) => const AddEditProductScreen()),
      GoRoute(path: '/products/edit/:id', builder: (_, state) => AddEditProductScreen(productId: state.pathParameters['id'])),
      GoRoute(path: '/products/bulk-add', builder: (_, __) => const BulkAddProductsScreen()),
      GoRoute(path: '/products/variants/:id', builder: (_, state) => ProductManagerScreen(productId: state.pathParameters['id'])),
      GoRoute(path: '/edit-profile', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/catalog/:boutiqueId', builder: (_, state) {
        final extra = state.extra;
        String? name;
        String? slug;
        if (extra is Map) {
          name = extra['name'] as String?;
          slug = extra['slug'] as String?;
        } else {
          name = extra as String?;
        }
        return StoreCatalogScreen(boutiqueId: state.pathParameters['boutiqueId']!, boutiqueName: name, boutiqueSlug: slug);
      }),
      GoRoute(path: '/product/:id', builder: (_, state) => ProductDetailScreen(productId: state.pathParameters['id']!, boutiqueId: state.extra as String?)),
      GoRoute(path: '/cart/:boutiqueId', builder: (_, state) => CartScreen(boutiqueId: state.pathParameters['boutiqueId']!)),
      GoRoute(path: '/checkout/:boutiqueId', builder: (_, state) => CheckoutScreen(boutiqueId: state.pathParameters['boutiqueId']!)),
      GoRoute(path: '/wishlist', builder: (_, __) => const WishlistScreen()),
      GoRoute(path: '/order-history', builder: (_, __) => const OrderHistoryScreen()),
      GoRoute(path: '/order-tracking/:id', builder: (_, state) => OrderTrackingScreen(orderId: state.pathParameters['id']!)),
      GoRoute(path: '/stores', builder: (_, __) => const StoresBrowserScreen()),
      GoRoute(path: '/create-store', builder: (_, __) => const CreateStoreScreen()),
      GoRoute(path: '/public-store/:slug', builder: (_, state) => PublicStorefrontScreen(slug: state.pathParameters['slug']!)),
    ],
  );
}
