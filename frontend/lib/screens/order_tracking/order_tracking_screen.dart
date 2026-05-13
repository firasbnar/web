import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/orders_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/loading_skeleton.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});
  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final List<_TimelineStep> _steps = [
    _TimelineStep('Commande passée', 'Votre commande a été enregistrée', 'PENDING', Icons.receipt_long, 0),
    _TimelineStep('Confirmée', 'Le vendeur a confirmé votre commande', 'CONFIRMED', Icons.check_circle_outline, 1),
    _TimelineStep('Expédiée', 'Votre colis est en route', 'SHIPPED', Icons.local_shipping, 2),
    _TimelineStep('Livrée', 'Colis livré avec succès', 'DELIVERED', Icons.check_circle, 3),
  ];

  int _statusIndex(String status) {
    switch (status) {
      case 'PENDING': return 0;
      case 'CONFIRMED': return 1;
      case 'SHIPPED': return 2;
      case 'DELIVERED': return 3;
      case 'CANCELLED': return -1;
      default: return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().loadOrder(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Suivi de commande')),
      body: Consumer<OrdersProvider>(
        builder: (_, op, __) {
          if (op.loading && op.selectedOrder == null) return const LoadingSkeleton();
          final o = op.selectedOrder;
          if (o == null) return const Center(child: Text('Commande non trouvée'));

          final idx = _statusIndex(o.status);
          final cancelled = o.status == 'CANCELLED';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF6C4FFF)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.orderNumber, style: AppTypography.heading3.copyWith(color: Colors.white)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Text('${o.items.length} article(s)', style: AppTypography.body2.copyWith(color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('${o.total.toStringAsFixed(3)} TND', style: AppTypography.heading2.copyWith(color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Statut: ', style: AppTypography.body2),
                          StatusChip(status: o.status),
                        ],
                      ),
                      if (cancelled) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cancel, color: AppColors.danger, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Cette commande a été annulée', style: AppTypography.caption.copyWith(color: AppColors.danger))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!cancelled) ...[
                  const SizedBox(height: 24),
                  Text('Suivi', style: AppTypography.heading4),
                  const SizedBox(height: 16),
                  ...List.generate(_steps.length, (i) {
                    final step = _steps[i];
                    final active = i <= idx;
                    final isLast = i == _steps.length - 1;
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: active ? AppColors.primary : AppColors.border,
                                ),
                                child: Icon(step.icon, size: 16, color: active ? Colors.white : AppColors.textSecondary),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: active ? AppColors.primary : AppColors.border,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(step.title, style: AppTypography.body2.copyWith(
                                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                                  color: active ? AppColors.textPrimary : AppColors.textSecondary,
                                )),
                                const SizedBox(height: 2),
                                Text(step.subtitle, style: AppTypography.caption.copyWith(
                                  color: active ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.6),
                                )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                if (o.trackingNumber != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Transporteur', style: AppTypography.heading4),
                        const SizedBox(height: 8),
                        Text(o.deliveryCompany ?? 'Non spécifié', style: AppTypography.body2),
                        const SizedBox(height: 4),
                        Text('Numéro de suivi: ${o.trackingNumber}', style: AppTypography.caption.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final String status;
  final IconData icon;
  final int order;
  _TimelineStep(this.title, this.subtitle, this.status, this.icon, this.order);
}
