import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/empty_state.dart';
import '../../providers/coupons_provider.dart';
import '../../providers/boutique_provider.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});
  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bp = context.read<BoutiqueProvider>();
      if (bp.currentBoutique != null) {
        context.read<CouponsProvider>().loadCoupons(bp.currentBoutique!.id);
      }
    });
  }

  void _showAddCoupon() {
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final minCtrl = TextEditingController();
    final maxCtrl = TextEditingController();
    String type = 'PERCENT';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nouveau code promo', style: AppTypography.heading3),
              const SizedBox(height: 16),
              TextFormField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code *')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'PERCENT', child: Text('Pourcentage')),
                  DropdownMenuItem(value: 'FIXED', child: Text('Montant fixe')),
                ],
                onChanged: (v) => setSheetState(() => type = v ?? 'PERCENT'),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: valueCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: type == 'PERCENT' ? 'Valeur (%) *' : 'Valeur (TND) *')),
              const SizedBox(height: 12),
              TextFormField(controller: minCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant minimum')),
              const SizedBox(height: 12),
              TextFormField(controller: maxCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max utilisations')),
              const SizedBox(height: 20),
              AppButton(label: 'Créer', onPressed: () {
                if (codeCtrl.text.isEmpty) return;
                final bp = context.read<BoutiqueProvider>();
                final boutiqueId = bp.activeBoutique?.id;
                if (boutiqueId == null) return;
                context.read<CouponsProvider>().createCoupon({
                  'boutiqueId': boutiqueId,
                  'code': codeCtrl.text,
                  'discountType': type,
                  'discountValue': double.tryParse(valueCtrl.text) ?? 0,
                  'minOrderAmount': double.tryParse(minCtrl.text),
                  'maxUses': int.tryParse(maxCtrl.text),
                });
                Navigator.pop(ctx);
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Codes promo')),
      body: Consumer<CouponsProvider>(
        builder: (_, cp, __) {
          if (cp.loading) return const Center(child: CircularProgressIndicator());
          if (cp.coupons.isEmpty) {
            return const EmptyState(
            icon: Icons.local_offer_outlined,
            title: 'Aucun code promo',
            subtitle: 'Créez votre premier code promo',
          );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cp.coupons.length,
            itemBuilder: (_, i) {
              final coupon = cp.coupons[i];
              return Dismissible(
                key: Key(coupon.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => cp.deleteCoupon(coupon.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(coupon.code, style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          fontSize: 13,
                        )),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              coupon.discountType == 'PERCENT'
                                  ? '${coupon.discountValue.toStringAsFixed(0)}% de réduction'
                                  : '${coupon.discountValue.toStringAsFixed(2)} TND de réduction',
                              style: AppTypography.body2,
                            ),
                            if (coupon.maxUses != null)
                              Text('Utilisé ${coupon.usedCount ?? 0}/${coupon.maxUses} fois', style: AppTypography.caption),
                          ],
                        ),
                      ),
                      Switch(
                        value: coupon.isActive,
                        onChanged: (v) {},
                        activeThumbColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCoupon,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
