import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../models/order.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/status_chip.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final _api = ApiClient();
  List<Order> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/orders/my-orders');
      _orders = ((res['data']?['content'] ?? res['data'] ?? []) as List)
          .map((e) => Order.fromJson(e)).toList();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'PENDING': return Colors.orange;
      case 'CONFIRMED': return AppColors.primary;
      case 'SHIPPED': return Colors.blue;
      case 'DELIVERED': return AppColors.success;
      case 'CANCELLED': return AppColors.danger;
      default: return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'PENDING': return Icons.schedule;
      case 'CONFIRMED': return Icons.check_circle_outline;
      case 'SHIPPED': return Icons.local_shipping;
      case 'DELIVERED': return Icons.check_circle;
      case 'CANCELLED': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('Aucune commande'))
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final o = _orders[i];
                      return InkWell(
                        onTap: () => context.go('/order-tracking/${o.id}'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(_statusIcon(o.status), size: 20, color: _statusColor(o.status)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(o.orderNumber, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600))),
                                  StatusChip(status: o.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('${o.total.toStringAsFixed(3)} TND', style: AppTypography.heading4.copyWith(color: AppColors.primary)),
                              const SizedBox(height: 4),
                              Text('${o.items.length} article(s)', style: AppTypography.caption),
                              if (o.createdAt != null) ...[
                                const SizedBox(height: 4),
                                Text(o.createdAt!.substring(0, 10), style: AppTypography.caption),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
