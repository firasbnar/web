import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/api_client.dart';
import '../../services/csv_export_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/order_card.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../providers/orders_provider.dart';
import '../../providers/boutique_provider.dart';
import '../../widgets/app_back_arrow.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _scrollController = ScrollController();
  final List<String> _tabs = ['orders.filter_all', 'orders.status_pending', 'orders.status_processing', 'orders.status_shipped', 'orders.status_delivered', 'orders.status_cancelled'];
  final List<String> _tabValues = ['ALL', 'PENDING', 'CONFIRMED', 'SHIPPED', 'DELIVERED', 'CANCELLED'];
  int _selectedTab = 0;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bp = context.read<BoutiqueProvider>();
      developer.log('[ORDERS] init route=${GoRouterState.of(context).uri} active=${bp.activeBoutiqueId}');
      await bp.ensureActiveBoutique();
      if (bp.activeBoutique != null) {
        developer.log('[ORDERS] loading data active=${bp.activeBoutique!.id}');
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

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      final bp = context.read<BoutiqueProvider>();
      if (bp.activeBoutique != null) {
        context.read<OrdersProvider>().loadOrders(
          bp.activeBoutique!.id, refresh: true,
          startDate: _startDate!.toIso8601String().substring(0, 10),
          endDate: _endDate!.toIso8601String().substring(0, 10),
        );
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
    developer.log('[ORDERS] build width=${MediaQuery.of(context).size.width}');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackArrow(),
        title: Text('orders.title'.tr()),
        actions: [
          if (_startDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() { _startDate = null; _endDate = null; });
                final bp = context.read<BoutiqueProvider>();
                if (bp.activeBoutique != null) {
                  context.read<OrdersProvider>().loadOrders(bp.activeBoutique!.id, refresh: true);
                }
              },
            ),
          IconButton(
            icon: Icon(Icons.date_range, color: _startDate != null ? AppColors.primary : null),
            onPressed: _pickDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () async {
              final bp = context.read<BoutiqueProvider>();
              if (bp.activeBoutique == null) return;
              try {
                final params = <String, dynamic>{'boutiqueId': bp.activeBoutique!.id};
                if (_startDate != null) {
                  params['startDate'] = _startDate!.toIso8601String().substring(0, 10);
                  params['endDate'] = _endDate!.toIso8601String().substring(0, 10);
                }
                final response = await ApiClient().dio.get('/orders/export',
                    queryParameters: params,
                    options: Options(responseType: ResponseType.bytes));
                final csv = utf8.decode(response.data as List<int>);
                CsvExportService.download(csv, 'commandes.csv');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('common.operation_success'.tr()), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${'common.error'.tr()}: ${ApiClient.extractErrorMessage(e)}'), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
          ),
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
                    child: Text(_tabs[i].tr(), style: TextStyle(
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
                  return EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'orders.no_orders'.tr(),
                  subtitle: 'orders.no_orders'.tr(),
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
