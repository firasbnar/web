import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/loading_skeleton.dart';
import '../../providers/orders_provider.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _trackingCtrl = TextEditingController();
  String _selectedStatus = '';
  static const List<String> _statusOptions = ['PENDING', 'CONFIRMED', 'SHIPPED', 'DELIVERED', 'CANCELLED'];
  static const List<String> _deliveryOptions = ['Adeex', 'Jax', 'Intigo'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<OrdersProvider>().loadOrder(widget.orderId);
      final order = context.read<OrdersProvider>().selectedOrder;
      if (mounted && order != null) {
        setState(() => _selectedStatus = order.status);
      }
    });
  }

  @override
  void dispose() {
    _trackingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Consumer<OrdersProvider>(
          builder: (_, op, __) => Text(op.selectedOrder?.orderNumber ?? 'Détail commande'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share('Commande ${context.read<OrdersProvider>().selectedOrder?.orderNumber ?? ""}'),
          ),
        ],
      ),
      body: Consumer<OrdersProvider>(
        builder: (_, op, __) {
          if (op.loading && op.selectedOrder == null) return const LoadingSkeleton();
          final order = op.selectedOrder;
          if (order == null) return const Center(child: Text('Commande non trouvée'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      Text('Client', style: AppTypography.heading4),
                      const SizedBox(height: 8),
                      Text(order.customerName ?? 'Client inconnu', style: AppTypography.body1),
                      Text(order.paymentMethod ?? "", style: AppTypography.caption),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                      Text('Articles', style: AppTypography.heading4),
                      const SizedBox(height: 8),
                      ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.productName, style: AppTypography.body2)),
                            Text('${item.quantity} × ${item.unitPrice.toStringAsFixed(2)}', style: AppTypography.caption),
                            const SizedBox(width: 8),
                            Text('${item.subtotal.toStringAsFixed(2)} TND', style: AppTypography.body2),
                          ],
                        ),
                      )),
                      const Divider(),
                      _summaryRow('Sous-total', '${order.subtotal.toStringAsFixed(2)} TND'),
                      _summaryRow('Livraison', '${order.shippingFee.toStringAsFixed(2)} TND'),
                      if (order.discount > 0) _summaryRow('Remise', '-${order.discount.toStringAsFixed(2)} TND'),
                      _summaryRow('Total', '${order.total.toStringAsFixed(2)} TND', bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                      Text('Statut', style: AppTypography.heading4),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StatusChip(status: _selectedStatus.isNotEmpty ? _selectedStatus : order.status),
                          const Spacer(),
                          SizedBox(
                            width: 140,
                            child: DropdownButtonFormField<String>(
                              initialValue: _statusOptions.contains(_selectedStatus) ? _selectedStatus : null,
                              items: _statusOptions
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _selectedStatus = v);
                              },
                              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedStatus.isNotEmpty && _selectedStatus != order.status) ...[
                        const SizedBox(height: 8),
                        AppButton(label: 'Confirmer', onPressed: () {
                          op.updateStatus(widget.orderId, _selectedStatus);
                        }),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                      Text('Paiement', style: AppTypography.heading4),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('${order.paymentMethod ?? ""} — ', style: AppTypography.body2),
                          StatusChip(status: order.paymentStatus ?? 'UNPAID'),
                        ],
                      ),
                      if (order.paymentRef != null) Text('Ref: ${order.paymentRef}', style: AppTypography.caption),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                      Text('Livraison', style: AppTypography.heading4),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _deliveryOptions.contains(order.deliveryCompany) ? order.deliveryCompany : null,
                        decoration: const InputDecoration(labelText: 'Transporteur'),
                        items: _deliveryOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) {},
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _trackingCtrl..text = order.trackingNumber ?? '',
                        decoration: const InputDecoration(labelText: 'Numéro de suivi'),
                      ),
                      const SizedBox(height: 8),
                      AppButton(label: 'Mettre à jour', onPressed: () {
                        op.updateTracking(widget.orderId, order.deliveryCompany ?? '', _trackingCtrl.text);
                      }),
                    ],
                  ),
                ),
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
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
                        Text('Notes', style: AppTypography.heading4),
                        const SizedBox(height: 8),
                        Text(order.notes!, style: AppTypography.body2),
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

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bold ? AppTypography.body2.copyWith(fontWeight: FontWeight.w600) : AppTypography.caption),
          Text(value, style: bold ? AppTypography.heading4.copyWith(color: AppColors.primary) : AppTypography.body2),
        ],
      ),
    );
  }
}
