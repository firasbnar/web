import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/boutique_provider.dart';

class StoreSelectorScreen extends StatelessWidget {
  const StoreSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes boutiques'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/create-store'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Créer une boutique', style: TextStyle(color: Colors.white)),
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
                Text('Aucune boutique', style: AppTypography.heading3),
                const SizedBox(height: 8),
                Text('Créez votre première boutique', style: AppTypography.body2.copyWith(color: AppColors.textHint)),
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
                            Text('${boutique.slug}.makewebsite.io',
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
                          child: const Text('Actif', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
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
