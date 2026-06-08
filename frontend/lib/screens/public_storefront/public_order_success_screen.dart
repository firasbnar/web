import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class PublicOrderSuccessScreen extends StatelessWidget {
  final String slug;
  final String orderId;
  const PublicOrderSuccessScreen({super.key, required this.slug, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 80, color: AppColors.success),
              const SizedBox(height: 24),
              Text('public_store.order_confirmed'.tr(), style: AppTypography.heading2),
              const SizedBox(height: 8),
              Text('public_store.order_success_message'.tr(), style: AppTypography.body1, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('${'public_store.order_number'.tr()}: $orderId', style: AppTypography.caption),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  onPressed: () => context.go('/store/$slug'),
                  child: Text('public_store.continue_shopping'.tr(), style: AppTypography.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
