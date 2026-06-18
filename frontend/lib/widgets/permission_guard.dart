import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/boutique_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class PermissionGuard extends StatelessWidget {
  final List<String> anyPermissions;
  final Widget child;
  final String fallbackRoute;

  const PermissionGuard({
    super.key,
    required this.anyPermissions,
    required this.child,
    this.fallbackRoute = '/home',
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final boutiqueProvider = context.watch<BoutiqueProvider>();
    final boutique = boutiqueProvider.activeBoutique;

    if (auth.role == 'SUPER_ADMIN' || auth.role == 'ADMIN') {
      return child;
    }

    if (boutique == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (boutique.hasAnyPermission(anyPermissions)) {
      return child;
    }

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text('Acces refuse', style: AppTypography.heading3),
              const SizedBox(height: 8),
              Text(
                'errors.access_denied'.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go(fallbackRoute),
                child: Text('nav.home'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
