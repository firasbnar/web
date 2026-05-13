import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/orders_provider.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final bp = context.read<BoutiqueProvider>();
    if (bp.activeBoutique != null) {
      context.read<OrdersProvider>().loadOrders(bp.activeBoutique!.id, refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Messages'), centerTitle: true),
      body: Consumer<OrdersProvider>(
        builder: (_, op, __) {
          final orders = op.orders.where((o) => o.notes != null && o.notes!.isNotEmpty).toList();
          if (op.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.message_outlined, size: 64, color: AppColors.textHint.withAlpha(60)),
                  const SizedBox(height: 16),
                  Text('Aucun message', style: AppTypography.body2.copyWith(color: AppColors.textHint)),
                  const SizedBox(height: 8),
                  Text('Les messages des clients apparaîtront ici', style: AppTypography.caption),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final o = orders[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySurface,
                    child: Text((o.customerName ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  title: Text(o.customerName ?? 'Client', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(o.notes ?? '', style: AppTypography.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('#${o.orderNumber}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () => context.go('/orders/${o.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
