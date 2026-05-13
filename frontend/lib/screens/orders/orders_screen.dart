import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/order_card.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../providers/orders_provider.dart';
import '../../providers/boutique_provider.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _scrollController = ScrollController();
  final List<String> _tabs = ['Tous', 'En attente', 'Confirmé', 'Expédié', 'Livré', 'Annulé'];
  final List<String> _tabValues = ['ALL', 'PENDING', 'CONFIRMED', 'SHIPPED', 'DELIVERED', 'CANCELLED'];
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bp = context.read<BoutiqueProvider>();
      if (bp.activeBoutique == null && bp.boutiques.isEmpty) {
        await bp.loadBoutiques();
      }
      if (bp.activeBoutique != null) {
        context.read<OrdersProvider>().loadOrders(bp.activeBoutique!.id, refresh: true);
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final bp = context.read<BoutiqueProvider>();
      if (bp.activeBoutique != null) {
        context.read<OrdersProvider>().loadOrders(bp.activeBoutique!.id);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Commandes'),
        actions: [
          IconButton(icon: const Icon(Icons.file_download_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _tabs.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedTab = i);
                    final bp = context.read<BoutiqueProvider>();
                    if (bp.currentBoutique != null) {
                      context.read<OrdersProvider>().setStatusFilter(_tabValues[i], bp.currentBoutique!.id);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedTab == i ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(_tabs[i], style: TextStyle(
                      color: _selectedTab == i ? Colors.white : AppColors.textPrimary,
                      fontSize: 13, fontWeight: FontWeight.w500,
                    )),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer<OrdersProvider>(
              builder: (_, op, __) {
                if (op.loading && op.orders.isEmpty) return const LoadingSkeleton();
                if (op.error != null) {
                  return ErrorState(message: op.error!, onRetry: () {
                  final bp = context.read<BoutiqueProvider>();
                  if (bp.activeBoutique != null) op.loadOrders(bp.activeBoutique!.id, refresh: true);
                });
                }
                if (op.orders.isEmpty) {
                  return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Aucune commande',
                  subtitle: 'Les commandes apparaîtront ici',
                );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: op.orders.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OrderCard(
                      order: op.orders[i],
                      onTap: () => context.go('/orders/${op.orders[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
