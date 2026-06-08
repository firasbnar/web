import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/empty_state.dart';
import '../../providers/coupons_provider.dart';
import '../../providers/boutique_provider.dart';
import '../../widgets/app_back_arrow.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});
  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bp = context.read<BoutiqueProvider>();
      await bp.ensureActiveBoutique();
      if (!mounted) return;
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
              Text('coupons.add_coupon'.tr(), style: AppTypography.heading3),
              const SizedBox(height: 16),
              TextFormField(controller: codeCtrl, decoration: InputDecoration(labelText: '${'coupons.code'.tr()} *')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: [
                  DropdownMenuItem(value: 'PERCENT', child: Text('coupons.percentage'.tr())),
                  DropdownMenuItem(value: 'FIXED', child: Text('coupons.fixed_amount'.tr())),
                ],
                onChanged: (v) => setSheetState(() => type = v ?? 'PERCENT'),
                decoration: InputDecoration(labelText: 'coupons.discount_type'.tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: valueCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '${'coupons.discount_value'.tr()} *')),
              const SizedBox(height: 12),
              TextFormField(controller: minCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'coupons.min_order_amount'.tr())),
              const SizedBox(height: 12),
              TextFormField(controller: maxCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'coupons.max_uses'.tr())),
              const SizedBox(height: 20),
              AppButton(label: 'coupons.add_coupon'.tr(), onPressed: () {
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
      appBar: AppBar(
        leading: const AppBackArrow(),
        title: Text('coupons.title'.tr()),
      ),
      body: Consumer<CouponsProvider>(
        builder: (_, cp, __) {
          if (cp.loading) return const Center(child: CircularProgressIndicator());
          if (cp.coupons.isEmpty) {
            return EmptyState(
            icon: Icons.local_offer_outlined,
            title: 'coupons.no_coupons'.tr(),
            subtitle: 'coupons.add_coupon'.tr(),
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
                                  ? '${coupon.discountValue.toStringAsFixed(0)}% ${'coupons.percentage'.tr()}'
                                  : '${'coupons.fixed_amount'.tr()} ${coupon.discountValue.toStringAsFixed(2)} TND',
                              style: AppTypography.body2,
                            ),
                            if (coupon.maxUses != null)
                              Text('${'coupons.used_count'.tr()}: ${coupon.usedCount ?? 0}/${coupon.maxUses}', style: AppTypography.caption),
                          ],
                        ),
                      ),
                      Switch(
                        value: coupon.isActive,
                        onChanged: (v) => cp.toggleActive(coupon.id),
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
