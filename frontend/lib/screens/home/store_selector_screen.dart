import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/boutique_provider.dart';
import '../../widgets/app_back_arrow.dart';

class StoreSelectorScreen extends StatefulWidget {
  const StoreSelectorScreen({super.key});

  @override
  State<StoreSelectorScreen> createState() => _StoreSelectorScreenState();
}

class _StoreSelectorScreenState extends State<StoreSelectorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bp = context.read<BoutiqueProvider>();
      if (bp.boutiques.isEmpty) {
        final auth = context.read<AuthProvider>();
        await bp.loadBoutiques(teamMember: auth.isTeamMember);
        if (mounted && bp.boutiques.isEmpty) {
          if (auth.canCreateBoutique) {
            context.go('/create-store');
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackArrow(),
        title: Text('store_selector.my_stores'.tr()),
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (_, auth, __) {
          if (!auth.canCreateBoutique) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => context.go('/create-store'),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text('store_selector.create_store'.tr(), style: const TextStyle(color: Colors.white)),
          );
        },
      ),
      body: Consumer<BoutiqueProvider>(
        builder: (_, bp, __) {
          if (bp.loading) return const Center(child: CircularProgressIndicator());
          if (bp.boutiques.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.store_outlined, size: 64, color: AppColors.textHint.withAlpha(100)),
                  const SizedBox(height: 16),
                  Text('store_selector.no_stores'.tr(), style: AppTypography.heading3),
                  const SizedBox(height: 8),
                  Text('store_selector.create_first_store'.tr(), style: AppTypography.body2.copyWith(color: AppColors.textHint)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bp.boutiques.length,
            itemBuilder: (_, i) {
              final boutique = bp.boutiques[i];
              final isActive = bp.activeBoutique?.id == boutique.id;
              return GestureDetector(
                onTap: () {
                  bp.switchBoutique(boutique.id);
                  context.go('/home');
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive ? AppColors.primary : AppColors.border,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary,
                        backgroundImage: boutique.logoUrl != null && boutique.logoUrl!.isNotEmpty
                            ? NetworkImage(boutique.logoUrl!) : null,
                        child: boutique.logoUrl == null || boutique.logoUrl!.isEmpty
                            ? Text((boutique.name)[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(boutique.name, style: AppTypography.body1.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('/store/${boutique.slug}',
                                style: AppTypography.caption.copyWith(color: AppColors.textHint)),
                          ],
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text('common.active'.tr(), style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppColors.textHint),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
