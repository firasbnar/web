import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/order.dart';
import 'status_chip.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;

  const OrderCard({super.key, required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.orderNumber, style: AppTypography.heading4),
                  const SizedBox(height: 4),
                  Text(order.customerName ?? 'Client inconnu', style: AppTypography.caption),
                  if (order.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(order.createdAt!, style: AppTypography.caption),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${order.total.toStringAsFixed(2)} TND', style: AppTypography.heading4.copyWith(color: AppColors.primary)),
                const SizedBox(height: 4),
                StatusChip(status: order.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
