import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reviews_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/products')) return 1;
    if (location.startsWith('/orders')) return 2;
    if (location.startsWith('/analytics')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/home');
      case 1: context.go('/products');
      case 2: context.go('/orders');
      case 3: context.go('/analytics');
      case 4: _showMoreMenu(context);
    }
  }

  void _showMoreMenu(BuildContext context) {
    final role = context.read<AuthProvider>().role;
    final isAdmin = role == 'ADMIN';
    final isSuperAdmin = role == 'SUPER_ADMIN';
    final isOwner = role == 'OWNER';

    final List<_MenuItem> allItems = [
      const _MenuItem(Icons.people_outline, 'Clients', '/customers'),
      const _MenuItem(Icons.point_of_sale, 'POS', '/pos'),
      const _MenuItem(Icons.local_offer_outlined, 'Codes promo', '/coupons'),
      const _MenuItem(Icons.smart_toy_outlined, 'Assistant IA', '/ai-assistant'),
      const _MenuItem(Icons.storefront_outlined, 'Explorer', '/explore'),
      const _MenuItem(Icons.payments_outlined, 'Paiements', '/boutique-settings'),
      const _MenuItem(Icons.store_outlined, 'Paramètres boutique', '/boutique-settings'),
      const _MenuItem(Icons.message_outlined, 'Messages', '/messages'),
      _MenuItem(Icons.group_outlined, 'Équipe', '/team', visible: isAdmin || isOwner),
      // Avis handled separately below with badge
      const _MenuItem(Icons.palette_outlined, 'Theme', '/boutique/theme'),
      const _MenuItem(Icons.layers_outlined, 'Template', '/boutique/template'),
      const _MenuItem(Icons.local_shipping_outlined, 'Livraison', '/delivery'),
      const _MenuItem(Icons.telegram, 'Telegram', '/telegram'),
      _MenuItem(Icons.admin_panel_settings_outlined, 'POS Admin', '/pos/admin', visible: isAdmin),
      _MenuItem(Icons.card_membership_outlined, 'Abonnement', '/plans', visible: isAdmin || isOwner),
      const _MenuItem(Icons.notifications_outlined, 'Notifications', '/notifications'),
      _MenuItem(Icons.history_outlined, 'Journal d\'activité', '/admin/activities', visible: isAdmin),
      _MenuItem(Icons.admin_panel_settings_outlined, 'Administration', '/admin', visible: isAdmin),
      _MenuItem(Icons.shield_outlined, 'Super Admin', '/super-admin', visible: isSuperAdmin),
      _MenuItem(Icons.travel_explore_outlined, 'Trafic', '/traffic', visible: isAdmin || isOwner),
      const _MenuItem(Icons.receipt_long_outlined, 'Mes commandes', '/order-history'),
      const _MenuItem(Icons.person_outline, 'Profil', '/profile'),
    ];

    final items = allItems.where((item) => item.visible).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plus', style: AppTypography.heading3),
                  const SizedBox(height: 16),
                  ...items.map((item) => _menuItem(ctx, item.icon, item.label, item.route)),
                  Consumer<ReviewsProvider>(
                    builder: (_, rp, __) => _menuItem(
                      ctx, Icons.star_outline, 'Avis', '/reviews',
                      badge: rp.pendingCount,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label, String route, {int badge = 0}) {
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: AppColors.primary),
          if (badge > 0)
            Positioned(
              right: -8, top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
        ],
      ),
      title: Text(label, style: AppTypography.body2),
      onTap: () { Navigator.pop(context); context.go(route); },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex(context),
        onTap: (i) => _onTap(context, i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Produits'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Commandes'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), activeIcon: Icon(Icons.more_horiz), label: 'Plus'),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String route;
  final bool visible;
  const _MenuItem(this.icon, this.label, this.route, {this.visible = true});
}
