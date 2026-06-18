import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/boutique_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  List<_NavItem> _navItems(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final boutique = context.watch<BoutiqueProvider>().activeBoutique;
    final role = boutique?.currentUserRole?.toUpperCase() ?? auth.role?.toUpperCase();
    final permissions = boutique?.currentUserPermissions ?? const [];
    final ownerLike = role == 'OWNER' || role == 'ADMIN' || auth.role == 'SUPER_ADMIN';
    bool can(String permission) => ownerLike || permissions.contains(permission);

    return [
      const _NavItem(Icons.home_outlined, Icons.home, 'nav.home', '/home'),
      if (can('PRODUCT_READ')) const _NavItem(Icons.inventory_2_outlined, Icons.inventory_2, 'nav.products', '/products'),
      if (can('ORDER_READ')) const _NavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'nav.orders', '/orders'),
      if (can('ANALYTICS_READ')) const _NavItem(Icons.travel_explore_outlined, Icons.travel_explore, 'nav.traffic', '/traffic'),
      const _NavItem(Icons.more_horiz, Icons.more_horiz, 'nav.more', '__more__'),
    ];
  }

  int _currentIndex(BuildContext context, List<_NavItem> items) {
    final location = GoRouterState.of(context).uri.toString();
    final index = items.indexWhere((item) => item.route != '__more__' && location.startsWith(item.route));
    return index >= 0 ? index : items.length - 1;
  }

  void _onTap(BuildContext context, List<_NavItem> items, int index) {
    final route = items[index].route;
    if (route == '__more__') {
      _showMoreMenu(context);
    } else {
      context.go(route);
    }
  }

  void _showMoreMenu(BuildContext context) {
    final role = context.read<AuthProvider>().role;
    final boutique = context.read<BoutiqueProvider>().activeBoutique;
    final isAdmin = role == 'ADMIN';
    final isSuperAdmin = role == 'SUPER_ADMIN';
    final isOwner = role == 'OWNER';
    final ownerLike = isOwner || isAdmin || isSuperAdmin || boutique?.ownerAccess == true;
    bool can(String permission) => ownerLike || (boutique?.currentUserPermissions.contains(permission) ?? false);

    final List<_MenuItem> allItems = [
      _MenuItem(Icons.local_offer_outlined, 'menu.coupons', '/coupons', visible: can('DISCOUNT_WRITE')),
      _MenuItem(Icons.card_membership_outlined, 'menu.subscription', '/plans', visible: isAdmin || isOwner),
      _MenuItem(Icons.history_outlined, "menu.activity_log", '/admin/activities', visible: isAdmin),
      _MenuItem(Icons.admin_panel_settings_outlined, 'menu.administration', '/admin', visible: isAdmin),
      _MenuItem(Icons.shield_outlined, 'menu.super_admin', '/super-admin', visible: isSuperAdmin),
      const _MenuItem(Icons.person_outline, 'menu.profile', '/profile'),
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
                  Text('nav.more'.tr(), style: AppTypography.heading3),
                  const SizedBox(height: 16),
                  ...items.map((item) => _menuItem(ctx, item.icon, item.labelKey, item.route)),
                ],
              ),
            ),
          ),
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String labelKey, String route, {int badge = 0}) {
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
      title: Text(labelKey.tr(), style: AppTypography.body2),
      onTap: () { Navigator.pop(context); context.go(route); },
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final navItems = _navItems(context);
    final selectedIndex = _currentIndex(context, navItems);

    developer.log('[SHELL] route=$location selected=$selectedIndex');

    // NOTE: No outer Scaffold here. Each child screen has its own Scaffold.
    // This avoids Duplicate GlobalKey errors from nested Scaffolds.
    // AnimatedSwitcher is NOT used to avoid keeping two widget trees
    // simultaneously, which causes GlobalKey conflicts.
    return Column(
      children: [
        Expanded(child: child),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.5)),
          ),
          child: BottomNavigationBar(
            currentIndex: selectedIndex,
            onTap: (i) => _onTap(context, navItems, i),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textHint,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            elevation: 0,
            backgroundColor: Colors.white,
            items: navItems.map((item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              activeIcon: Icon(item.activeIcon),
              label: item.labelKey.tr(),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String labelKey;
  final String route;
  const _NavItem(this.icon, this.activeIcon, this.labelKey, this.route);
}

class _MenuItem {
  final IconData icon;
  final String labelKey;
  final String route;
  final bool visible;
  const _MenuItem(this.icon, this.labelKey, this.route, {this.visible = true});
}
