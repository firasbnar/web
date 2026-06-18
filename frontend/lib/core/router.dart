import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:makewebsite_app/screens/auth/change_password_screen.dart';
import 'package:makewebsite_app/screens/auth/forgot_password_screen.dart';
import 'package:makewebsite_app/screens/auth/login_screen.dart';
import 'package:makewebsite_app/screens/auth/register_screen.dart';
import 'package:makewebsite_app/screens/auth/reset_password_screen.dart';
import 'package:makewebsite_app/screens/landing_screen.dart';
import 'package:makewebsite_app/screens/splash_screen.dart';
import '../providers/auth_provider.dart';

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
import '../screens/subscription/subscription_checkout_return_screen.dart';
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

import '../models/conversation.dart';
import '../widgets/main_scaffold.dart';
import '../widgets/permission_guard.dart';

GoRouter createRouter(AuthProvider auth) {
  // Saved intended URL before splash redirect, restored after auth init completes
  String? pendingPath;

  return GoRouter(
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.uri.toString();
      final path = state.uri.path;
      final isLoggedIn = auth.isAuthenticated;
      final role = auth.role;

      developer.log('[ROUTER] redirect: path="$path" isLoggedIn=$isLoggedIn role=$role initialized=${auth.isInitialized}');

      // --- AUTH INIT CHECK — show splash until auth state is restored from storage ---
      if (!auth.isInitialized) {
        if (path == '/splash') return null;
        pendingPath = state.uri.toString();
        developer.log('[ROUTER] Auth not initialized, saving pending=$pendingPath, redirecting to /splash');
        return '/splash';
      }

      // After init: if still on splash, always leave it
      if (path == '/splash') {
        if (pendingPath != null) {
          final target = pendingPath!;
          pendingPath = null;
          developer.log('[ROUTER] Leaving splash: restoring pending=$target');
          return target;
        }
        if (isLoggedIn) {
          final target = role == 'SUPER_ADMIN' ? '/super-admin' : (role == 'ADMIN' ? '/admin' : '/home');
          developer.log('[ROUTER] Leaving splash: logged in, going to $target');
          return target;
        }
        developer.log('[ROUTER] Leaving splash: not logged in, going to /landing');
        return '/landing';
      }

      // Root path → landing
      if (location == '/' || location.isEmpty) return '/landing';

      // /dashboard is an alias for /home
      if (path == '/dashboard') return '/home';

      // Public store browsings
      if (path.startsWith('/explore')) return null;

      final publicRoutes = ['/landing', '/login', '/register', '/signup', '/verify-email', '/forgot-password', '/reset-password', '/plans', '/create-store', '/store-selector', '/stores', '/subscription/checkout-return'];
      final isPublic = publicRoutes.any((r) => location == r || location.startsWith('$r/') || location.startsWith('$r?'));

      // --- SUPER_ADMIN is platform-level only, no access to owner/merchant routes ---
      if (isLoggedIn && role == 'SUPER_ADMIN') {
        if (path.startsWith('/super-admin')) return null;
        if (isPublic) return '/super-admin';
        if (path == '/change-password' || path == '/reset-password') return null;
        developer.log('[ROUTER] SUPER_ADMIN redirecting to /super-admin');
        return '/super-admin';
      }

      // Not logged in → allow public routes, otherwise redirect to login
      if (!isLoggedIn) {
        if (isPublic) return null;
        developer.log('[ROUTER] Not logged in, redirecting to /login');
        return '/login';
      }

      // --- LOGGED IN (non-SUPER_ADMIN) ---
      // Redirect away from auth pages to appropriate dashboard
      if (path == '/login' || path.startsWith('/login?') ||
          path == '/register' || path == '/signup' ||
          path == '/landing') {
        final target = role == 'ADMIN' ? '/admin' : '/home';
        developer.log('[ROUTER] Logged in on auth page, redirecting to $target');
        return target;
      }

      final teamMemberBlockedPath = path.startsWith('/create-store') ||
          path.startsWith('/create-boutique') ||
          path.startsWith('/plans') ||
          path.startsWith('/subscription-checkout') ||
          path.startsWith('/subscription/checkout') ||
          path == '/subscription';
      if (auth.isTeamMember && teamMemberBlockedPath) {
        developer.log('[ROUTER] Team member blocked from owner onboarding/subscription path, redirecting to /home');
        return '/home';
      }

      if (isPublic) return null;

      if (path == '/change-password') return null;

      if (auth.mustChangePassword && path != '/change-password') {
        developer.log('[ROUTER] Must change password, redirecting');
        return '/change-password';
      }

      // Deep link handling: Stripe checkout return
      // (covers both old backend URL with session_id and new URL with sessionId)
      final query = state.uri.queryParameters;
      if ((path == '/subscription' || path == '/subscription/checkout-return') && query.containsKey('status')) {
        final sessionId = query['sessionId'] ?? query['session_id'] ?? '';
        final status = query['status'] ?? 'pending';
        developer.log('[ROUTER] Stripe return deep link: status=$status sessionId=$sessionId');
        if (path != '/subscription/checkout-return') {
          return '/subscription/checkout-return?status=$status&sessionId=$sessionId';
        }
        return null;
      }

      // Subscription guard: non-SUPER_ADMIN needs active subscription for protected routes
      // /plans and /create-store are exempt (onboarding flow)
      if (path.startsWith('/plans') || path.startsWith('/create-store') || path.startsWith('/subscription/checkout-return')) return null;
      final subRequiredPaths = ['/home', '/store-selector', '/products', '/orders', '/customers',
          '/analytics', '/traffic', '/delivery', '/inventory', '/pos', '/subscription',
          '/coupons', '/reviews', '/team', '/messages', '/notifications', '/boutique-settings',
          '/payment-settings', '/ai-assistant', '/stores'];
      final needsSub = subRequiredPaths.any((p) => path == p || path.startsWith('$p/'));
      if (needsSub && role != 'SUPER_ADMIN' && !auth.isTeamMember && !auth.subscriptionActive) {
        if (auth.isSubscriptionChecking) {
          developer.log('[ROUTER] Subscription status still loading, allowing navigation');
          return null;
        }
        developer.log('[ROUTER] No active subscription, redirecting to /plans');
        return '/plans';
      }



      if (path.startsWith('/super-admin')) {
        developer.log('[ROUTER] Non-SUPER_ADMIN blocked from /super-admin');
        return '/home';
      }

      if ((path == '/admin' || path == '/admin/activities') && role != 'ADMIN') {
        developer.log('[ROUTER] Non-ADMIN blocked from /admin');
        return '/home';
      }

      if (path == '/team' && role != 'OWNER' && role != 'ADMIN') {
        developer.log('[ROUTER] Non-OWNER/ADMIN blocked from /team');
        return '/home';
      }

      if (path.startsWith('/pos/admin') && role != 'ADMIN' && role != 'OWNER') {
        developer.log('[ROUTER] Non-ADMIN/OWNER blocked from /pos/admin');
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
      GoRoute(
        path: '/subscription/checkout-return',
        builder: (_, state) => SubscriptionCheckoutReturnScreen(
          status: state.uri.queryParameters['status'] ?? 'pending',
          sessionId: state.uri.queryParameters['sessionId'] ?? state.uri.queryParameters['session_id'],
        ),
      ),
      GoRoute(path: '/super-admin', builder: (_, __) => const SuperAdminDashboardScreen()),

      ShellRoute(
        builder: (_, __, child) => MainScaffold(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const StoreDashboardScreen()),
          GoRoute(path: '/messages', builder: (_, __) => const PermissionGuard(anyPermissions: ['MESSAGE_READ'], child: MessagesScreen())),
          GoRoute(path: '/messages/:id', builder: (_, state) => PermissionGuard(anyPermissions: const ['MESSAGE_READ'], child: ConversationScreen(conversation: state.extra as Conversation))),
          GoRoute(path: '/team', builder: (_, __) => const PermissionGuard(anyPermissions: ['TEAM_READ', 'TEAM_WRITE'], child: TeamScreen())),
          GoRoute(path: '/reviews', builder: (_, __) => const PermissionGuard(anyPermissions: ['REVIEW_READ', 'REVIEW_WRITE'], child: ReviewsScreen())),
          GoRoute(path: '/pos/admin', builder: (_, __) => const PermissionGuard(anyPermissions: ['POS_ACCESS'], child: PosAdminScreen())),
          GoRoute(path: '/telegram', builder: (_, __) => const PermissionGuard(anyPermissions: ['SETTINGS_READ', 'SETTINGS_WRITE'], child: TelegramSettingsScreen())),
          GoRoute(path: '/products', builder: (_, __) => const PermissionGuard(anyPermissions: ['PRODUCT_READ'], child: ProductsScreen())),
          GoRoute(path: '/orders', builder: (_, __) => const PermissionGuard(anyPermissions: ['ORDER_READ'], child: OrdersScreen())),
          GoRoute(path: '/orders/:id', builder: (_, state) => PermissionGuard(anyPermissions: const ['ORDER_READ'], child: OrderDetailScreen(orderId: state.pathParameters['id']!))),
          GoRoute(path: '/customers', builder: (_, __) => const PermissionGuard(anyPermissions: ['CUSTOMER_READ'], child: CustomersScreen())),
          GoRoute(path: '/customers/:id', builder: (_, state) => PermissionGuard(anyPermissions: const ['CUSTOMER_READ'], child: CustomerDetailScreen(customerId: state.pathParameters['id']!))),
          GoRoute(path: '/pos', builder: (_, __) => const PermissionGuard(anyPermissions: ['POS_ACCESS'], child: PosScreen())),
          GoRoute(path: '/inventory', builder: (_, __) => const PermissionGuard(anyPermissions: ['STOCK_UPDATE', 'INVENTORY_WRITE'], child: InventoryScreen())),
          GoRoute(path: '/delivery', builder: (_, __) => const PermissionGuard(anyPermissions: ['SETTINGS_READ', 'SETTINGS_WRITE'], child: DeliveryCompanyScreen())),
          GoRoute(path: '/analytics', builder: (_, __) => const PermissionGuard(anyPermissions: ['ANALYTICS_READ'], child: AnalyticsScreen())),
          GoRoute(path: '/traffic', builder: (_, __) => const PermissionGuard(anyPermissions: ['ANALYTICS_READ'], child: TrafficScreen())),
          GoRoute(path: '/traffic/analytics', builder: (_, __) => const PermissionGuard(anyPermissions: ['ANALYTICS_READ'], child: TrafficAnalyticsScreen())),
          // Multi-store scoped routes
          GoRoute(
            path: '/stores/:boutiqueId/dashboard',
            builder: (_, state) => StoreDashboardScreen(
              boutiqueId: state.pathParameters['boutiqueId'],
            ),
          ),
          GoRoute(
            path: '/stores/:boutiqueId/products',
            builder: (_, __) => const PermissionGuard(anyPermissions: ['PRODUCT_READ'], child: ProductsScreen()),
          ),
          GoRoute(
            path: '/stores/:boutiqueId/orders',
            builder: (_, __) => const PermissionGuard(anyPermissions: ['ORDER_READ'], child: OrdersScreen()),
          ),
          GoRoute(
            path: '/stores/:boutiqueId/customers',
            builder: (_, __) => const PermissionGuard(anyPermissions: ['CUSTOMER_READ'], child: CustomersScreen()),
          ),
          GoRoute(
            path: '/stores/:boutiqueId/traffic',
            builder: (_, __) => const PermissionGuard(anyPermissions: ['ANALYTICS_READ'], child: TrafficScreen()),
          ),
          GoRoute(
            path: '/stores/:boutiqueId/settings',
            builder: (_, __) => const PermissionGuard(anyPermissions: ['SETTINGS_READ', 'SETTINGS_WRITE'], child: BoutiqueSettingsScreen()),
          ),
          GoRoute(
            path: '/stores/:boutiqueId',
            redirect: (_, state) => '/stores/${state.pathParameters['boutiqueId']}/dashboard',
          ),
          GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
          GoRoute(path: '/admin/activities', builder: (_, __) => const JournalActiviteScreen()),
          GoRoute(path: '/payment-settings', redirect: (_, __) => '/boutique-settings'),
          GoRoute(path: '/ai-assistant', builder: (_, __) => const PermissionGuard(anyPermissions: ['AI_ASSISTANT'], child: AiAssistantScreen())),
          GoRoute(path: '/boutique-settings', builder: (_, __) => const PermissionGuard(anyPermissions: ['SETTINGS_READ', 'SETTINGS_WRITE'], child: BoutiqueSettingsScreen())),
          GoRoute(path: '/plans', builder: (_, __) => const PlansScreen()),
          GoRoute(path: '/subscription', builder: (_, __) => const SubscriptionDashboardScreen()),
          GoRoute(path: '/coupons', builder: (_, __) => const PermissionGuard(anyPermissions: ['DISCOUNT_WRITE'], child: CouponsScreen())),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/products/add', builder: (_, __) => const PermissionGuard(anyPermissions: ['PRODUCT_WRITE'], child: AddEditProductScreen())),
      GoRoute(path: '/products/edit/:id', builder: (_, state) => PermissionGuard(anyPermissions: const ['PRODUCT_WRITE'], child: AddEditProductScreen(productId: state.pathParameters['id']))),
      GoRoute(path: '/products/bulk-add', builder: (_, __) => const PermissionGuard(anyPermissions: ['PRODUCT_WRITE'], child: BulkAddProductsScreen())),
      GoRoute(path: '/products/variants/:id', builder: (_, state) => PermissionGuard(anyPermissions: const ['PRODUCT_WRITE'], child: ProductManagerScreen(productId: state.pathParameters['id']))),
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
      GoRoute(path: '/store-selector', builder: (_, __) => const StoreSelectorScreen()),
      GoRoute(path: '/stores', redirect: (_, __) => '/store-selector'),
      GoRoute(path: '/explore', builder: (_, __) => const StoresBrowserScreen()),
      GoRoute(path: '/create-store', builder: (_, __) => const CreateStoreScreen()),

    ],
  );
}
