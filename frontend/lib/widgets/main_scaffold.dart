import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
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
    if (location.startsWith('/traffic')) return 3;
    return 4;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/home');
      case 1: context.go('/products');
      case 2: context.go('/orders');
      case 3: context.go('/traffic');
      case 4: _showMoreMenu(context);
    }
  }

  void _showMoreMenu(BuildContext context) {
    final role = context.read<AuthProvider>().role;
    final isAdmin = role == 'ADMIN';
    final isSuperAdmin = role == 'SUPER_ADMIN';
    final isOwner = role == 'OWNER';

    final List<_MenuItem> allItems = [
      const _MenuItem(Icons.local_offer_outlined, 'menu.coupons', '/coupons'),
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
    final selectedIndex = _currentIndex(context);

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
            onTap: (i) => _onTap(context, i),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textHint,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            elevation: 0,
            backgroundColor: Colors.white,
            items: [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'nav.home'.tr()),
              BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'nav.products'.tr()),
              BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'nav.orders'.tr()),
              BottomNavigationBarItem(icon: Icon(Icons.travel_explore_outlined), activeIcon: Icon(Icons.travel_explore), label: 'nav.traffic'.tr()),
              BottomNavigationBarItem(icon: Icon(Icons.more_horiz), activeIcon: Icon(Icons.more_horiz), label: 'nav.more'.tr()),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String labelKey;
  final String route;
  final bool visible;
  const _MenuItem(this.icon, this.labelKey, this.route, {this.visible = true});
}
