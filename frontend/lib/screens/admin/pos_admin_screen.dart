import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/pos_admin_provider.dart';
import '../../models/cashier.dart';
import 'package:provider/provider.dart';
import '../../widgets/app_back_arrow.dart';

class PosAdminScreen extends StatefulWidget {
  const PosAdminScreen({super.key});
  @override
  State<PosAdminScreen> createState() => _PosAdminScreenState();
}

class _PosAdminScreenState extends State<PosAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  PosAdminProvider? _provider;
  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _selectedRole = 'STAFF';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bp = context.read<BoutiqueProvider>();
      if (bp.currentBoutique != null && _provider == null) {
        final p = PosAdminProvider();
        p.init(bp.currentBoutique!.id);
        _provider = p;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _provider?.dispose();
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_provider == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<PosAdminProvider>(
        builder: (_, p, __) => Scaffold(
          appBar: AppBar(
            leading: const AppBackArrow(),
            title: Text('menu.pos_admin'.tr()),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: [
                Tab(icon: Icon(Icons.dashboard), text: 'dashboard.title'.tr()),
                Tab(icon: Icon(Icons.people), text: 'team.staff'.tr()),
                Tab(icon: Icon(Icons.receipt_long), text: 'orders.title'.tr()),
                Tab(icon: Icon(Icons.history), text: 'super_admin.activity'.tr()),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _dashboardTab(p),
              _cashiersTab(p),
              _ordersTab(p),
              _activitiesTab(p),
            ],
          ),
        ),
      ),
    );
  }

  // ========== DASHBOARD TAB ==========

  Widget _dashboardTab(PosAdminProvider p) {
    if (p.loadingDashboard && p.dashboard == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.dashboardError != null && p.dashboard == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(p.dashboardError!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text('common.retry'.tr()),
              onPressed: p.loadDashboard,
            ),
          ],
        ),
      );
    }
    final d = p.dashboard;
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _metricCard('dashboard.total_sales'.tr(), '${d?['totalVentes'] ?? 0} TND', Icons.trending_up, AppColors.primary),
        _metricCard('dashboard.today'.tr(), '${d?['ventesAujourdhui'] ?? 0} TND', Icons.today, Colors.green),
        _metricCard('dashboard.today'.tr(), '${d?['commandesAujourdhui'] ?? 0}', Icons.receipt, Colors.amber),
        _metricCard('dashboard.total_orders'.tr(), '${d?['totalCommandes'] ?? 0}', Icons.receipt_long, Colors.cyan),
        _metricCard('dashboard.total_sales'.tr(), '${d?['caissesActives'] ?? 0}', Icons.point_of_sale, Colors.purple),
        _metricCard('super_admin.active_users'.tr(), '${d?['utilisateursConnectes'] ?? 0}', Icons.person, Colors.pink),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.heading3.copyWith(color: color), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ========== CASHIERS TAB ==========

  Widget _cashiersTab(PosAdminProvider p) {
    return Column(
      children: [
        _cashierStatsRow(p),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'admin.search'.tr(),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => p.setCashierSearchQuery(v),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.person_add),
                label: Text('team.add_member'.tr()),
                onPressed: () => _showCreateCashierDialog(p),
              ),
            ],
          ),
        ),
        Expanded(child: _cashiersList(p)),
      ],
    );
  }

  Widget _cashierStatsRow(PosAdminProvider p) {
    final cs = p.cashierStats;
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _smallStat('team.staff'.tr(), '${cs?['totalCashiers'] ?? '...'}', Icons.people, AppColors.primary),
          _smallStat('common.active'.tr(), '${cs?['onlineCashiers'] ?? '...'}', Icons.wifi, Colors.green),
          _smallStat('dashboard.total_sales'.tr(), '${cs?['totalSales'] ?? '...'} TND', Icons.trending_up, Colors.amber),
        ],
      ),
    );
  }

  Widget _smallStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(label, style: AppTypography.caption.copyWith(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cashiersList(PosAdminProvider p) {
    if (p.cashiers.isEmpty && p.cashiersError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text('common.no_data'.tr()),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text('common.retry'.tr()),
              onPressed: () => p.loadCashiers(refresh: true),
            ),
          ],
        ),
      );
    }
    if (p.loadingCashiers && p.cashiers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.cashiers.isEmpty) {
      return Center(child: Text('common.no_results'.tr()));
    }
    return RefreshIndicator(
      onRefresh: () => p.loadCashiers(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: p.cashiers.length + (p.cashiersDone ? 0 : 1),
        itemBuilder: (_, i) {
          if (i >= p.cashiers.length) {
            p.loadCashiers();
            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          }
          return _cashierItem(p, p.cashiers[i]);
        },
      ),
    );
  }

  Widget _cashierItem(PosAdminProvider p, Cashier c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: c.online ? AppColors.success.withAlpha(30) : AppColors.border,
            child: Text(
              (c.fullName.isNotEmpty ? c.fullName[0] : '?').toUpperCase(),
              style: TextStyle(
                color: c.online ? AppColors.success : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.fullName, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                Text(c.email, style: AppTypography.caption),
                Row(
                  children: [
                    Text('${c.role} · ', style: AppTypography.caption.copyWith(fontSize: 10)),
                    if (c.totalVentes > 0 || c.commandesCount > 0)
                      Text('${c.totalVentes.toStringAsFixed(2)} TND · ${c.commandesCount} commandes',
                          style: AppTypography.caption.copyWith(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          if (c.isSuspended)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger.withAlpha(30),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('admin.suspend'.tr(), style: TextStyle(fontSize: 10, color: AppColors.danger)),
            ),
          if (!c.isSuspended && c.online)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(30),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('common.active'.tr(), style: TextStyle(fontSize: 10, color: AppColors.success)),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (v) {
              if (v == 'delete') _confirmDeleteCashier(p, c);
              if (v == 'toggle') _toggleCashierStatus(p, c.id, !c.isSuspended);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(c.isSuspended ? 'admin.activate'.tr() : 'admin.suspend'.tr()),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('admin.delete'.tr(), style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateCashierDialog(PosAdminProvider p) {
    _nameCtrl.clear();
    _emailCtrl.clear();
    _selectedRole = 'STAFF';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('team.add_member'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: 'auth.full_name'.tr(), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(labelText: 'auth.email'.tr(), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: InputDecoration(labelText: 'team.role'.tr(), border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'STAFF', child: Text('STAFF')),
                  DropdownMenuItem(value: 'MANAGER', child: Text('MANAGER')),
                ],
                onChanged: (v) { if (v != null) setDialogState(() => _selectedRole = v); },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
            ElevatedButton(
              onPressed: () async {
                final ok = await p.createCashier(_emailCtrl.text.trim(), _nameCtrl.text.trim(), _selectedRole);
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'common.operation_success'.tr() : p.cashierActionError ?? 'errors.unknown'.tr()),
                      backgroundColor: ok ? AppColors.success : AppColors.danger,
                    ),
                  );
                }
              },
              child: Text('team.add_member'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCashier(PosAdminProvider p, Cashier c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('common.confirm'.tr()),
        content: Text('${'common.confirm_delete'.tr()} "${c.fullName}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await p.deleteCashier(c.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'common.operation_success'.tr() : p.cashierActionError ?? 'errors.unknown'.tr()),
                    backgroundColor: ok ? AppColors.success : AppColors.danger,
                  ),
                );
              }
            },
            child: Text('common.delete'.tr(), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCashierStatus(PosAdminProvider p, String userId, bool suspend) async {
    final ok = await p.toggleCashierStatus(userId, suspend);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'common.operation_success'.tr()
              : p.cashierActionError ?? 'errors.unknown'.tr()),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  // ========== ORDERS TAB ==========

  Widget _ordersTab(PosAdminProvider p) {
    return Column(
      children: [
        _orderUserTabs(p),
        _orderFilters(p),
        if (p.selectedCashier != null) _userSummaryCard(p),
        Expanded(child: _ordersList(p)),
      ],
    );
  }

  Widget _orderUserTabs(PosAdminProvider p) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _userTab('common.all'.tr(), p.orderUserIdFilter == null, () => p.selectCashier(null)),
          ...p.cashiers.map((c) => _userTab(
            c.fullName.split(' ').first,
            p.orderUserIdFilter == c.id,
            () => p.selectCashier(c),
          )),
        ],
      ),
    );
  }

  Widget _userTab(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _userSummaryCard(PosAdminProvider p) {
    final c = p.selectedCashier!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withAlpha(30),
            child: Text(c.fullName[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.fullName, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                Text(c.email, style: AppTypography.caption),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${c.totalVentes.toStringAsFixed(2)} TND', style: AppTypography.body2.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
              Text('${c.commandesCount} ${'orders.title'.tr()}', style: AppTypography.caption),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderFilters(PosAdminProvider p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('common.all'.tr(), p.orderStatusFilter == '', () => p.setOrderStatusFilter('')),
            _filterChip('orders.status_pending'.tr(), p.orderStatusFilter == 'PENDING', () => p.setOrderStatusFilter('PENDING')),
            _filterChip('orders.status_processing'.tr(), p.orderStatusFilter == 'CONFIRMED', () => p.setOrderStatusFilter('CONFIRMED')),
            _filterChip('orders.status_processing'.tr(), p.orderStatusFilter == 'PREPARING', () => p.setOrderStatusFilter('PREPARING')),
            _filterChip('orders.status_processing'.tr(), p.orderStatusFilter == 'READY', () => p.setOrderStatusFilter('READY')),
            _filterChip('orders.status_delivered'.tr(), p.orderStatusFilter == 'DELIVERED', () => p.setOrderStatusFilter('DELIVERED')),
            _filterChip('orders.status_cancelled'.tr(), p.orderStatusFilter == 'CANCELLED', () => p.setOrderStatusFilter('CANCELLED')),
          ],
        ),
      ),
    );
  }

  Widget _ordersList(PosAdminProvider p) {
    if (p.orders.isEmpty && p.ordersError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text('common.no_data'.tr()),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text('common.retry'.tr()),
              onPressed: () => p.loadOrders(refresh: true),
            ),
          ],
        ),
      );
    }
    if (p.loadingOrders && p.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.orders.isEmpty) {
      return Center(child: Text('orders.no_orders'.tr()));
    }
    return RefreshIndicator(
      onRefresh: () => p.loadOrders(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: p.orders.length + (p.ordersDone ? 0 : 1),
        itemBuilder: (_, i) {
          if (i >= p.orders.length) {
            p.loadOrders();
            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          }
          final o = p.orders[i];
          return GestureDetector(
            onTap: () => _showOrderDetail(o),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _orderStatusColor(o['status'] ?? '').withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.receipt, color: _orderStatusColor(o['status'] ?? '')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o['orderNumber'] ?? '', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                        if (o['customerName'] != null)
                          Text(o['customerName'], style: AppTypography.caption),
                        Row(
                          children: [
                            Text('${o['total'] ?? 0} TND', style: AppTypography.body2.copyWith(color: AppColors.primary)),
                            const SizedBox(width: 8),
                            _statusBadge(o['status'] ?? ''),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (o['createdAt'] != null)
                    Text(_formatDate(o['createdAt']), style: AppTypography.caption.copyWith(fontSize: 10)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showOrderDetail(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(order['orderNumber'] ?? '', style: AppTypography.heading3),
            const SizedBox(height: 8),
            _detailRow('orders.customer'.tr(), order['customerName'] ?? 'orders.unknown_customer'.tr()),
            _detailRow('orders.order_status'.tr(), _orderStatusLabel(order['status'] ?? '')),
            _detailRow('orders.total'.tr(), '${order['total'] ?? 0} TND'),
            _detailRow('orders.payment_status'.tr(), order['paymentStatus'] ?? 'N/A'),
            _detailRow('orders.payment_method'.tr(), order['paymentMethod'] ?? 'N/A'),
            if (order['createdAt'] != null)
              _detailRow('common.date'.tr(), order['createdAt'].toString().substring(0, 16)),
            if (order['notes'] != null && (order['notes'] as String).isNotEmpty)
              _detailRow('orders.notes'.tr(), order['notes']),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: AppTypography.caption)),
          Expanded(child: Text(value, style: AppTypography.body2)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _orderStatusColor(status).withAlpha(30),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        _orderStatusLabel(status),
        style: TextStyle(fontSize: 10, color: _orderStatusColor(status)),
      ),
    );
  }

  Color _orderStatusColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'CONFIRMED': return Colors.blue;
      case 'PREPARING': return Colors.amber;
      case 'READY': return Colors.teal;
      case 'DELIVERED': return AppColors.success;
      case 'CANCELLED': return AppColors.danger;
      default: return AppColors.textSecondary;
    }
  }

  String _orderStatusLabel(String status) {
    switch (status) {
      case 'PENDING': return 'orders.status_pending'.tr();
      case 'CONFIRMED': return 'orders.status_processing'.tr();
      case 'PREPARING': return 'orders.status_processing'.tr();
      case 'READY': return 'orders.status_processing'.tr();
      case 'DELIVERED': return 'orders.status_delivered'.tr();
      case 'CANCELLED': return 'orders.status_cancelled'.tr();
      default: return status;
    }
  }

  // ========== ACTIVITIES TAB ==========

  Widget _activitiesTab(PosAdminProvider p) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('common.all'.tr(), p.activityActionFilter == '', () => p.setActivityActionFilter('')),
                _filterChip('auth.login'.tr(), p.activityActionFilter == 'CONNEXION_CAISSE_REUSSIE', () => p.setActivityActionFilter('CONNEXION_CAISSE_REUSSIE')),
                _filterChip('auth.logout'.tr(), p.activityActionFilter == 'DECONNEXION_CAISSE', () => p.setActivityActionFilter('DECONNEXION_CAISSE')),
                _filterChip('orders.title'.tr(), p.activityActionFilter == 'CREATION_COMMANDE', () => p.setActivityActionFilter('CREATION_COMMANDE')),
                _filterChip('pos.title'.tr(), p.activityActionFilter == 'OUVERTURE_CAISSE', () => p.setActivityActionFilter('OUVERTURE_CAISSE')),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text('admin.logs'.tr(), style: TextStyle(fontSize: 12)),
                onPressed: () => context.go('/admin/activities'),
              ),
              const Spacer(),
              Text('${p.activities.length} ${'super_admin.activity'.tr()}', style: AppTypography.caption.copyWith(fontSize: 11)),
            ],
          ),
        ),
        Expanded(
          child: p.activities.isEmpty && p.activitiesError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                      const SizedBox(height: 12),
                      Text('common.no_data'.tr()),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: Text('common.retry'.tr()),
                        onPressed: () => p.loadActivities(refresh: true),
                      ),
                    ],
                  ),
                )
              : p.loadingActivities && p.activities.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : p.activities.isEmpty
                      ? Center(child: Text('common.no_results'.tr()))
                      : RefreshIndicator(
                          onRefresh: () => p.loadActivities(refresh: true),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: p.activities.length + (p.activitiesDone ? 0 : 1),
                            itemBuilder: (_, i) {
                              if (i >= p.activities.length) {
                                p.loadActivities();
                                return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                              }
                              final a = p.activities[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(_activityIcon(a.action), size: 20, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(a.userName, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                                          Text(_activityLabel(a.action), style: AppTypography.caption),
                                          if (a.details != null && a.details!.isNotEmpty)
                                            Text(a.details!, style: AppTypography.caption.copyWith(fontSize: 11, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    if (a.createdAt != null)
                                      Text(_formatDate(a.createdAt!), style: AppTypography.caption.copyWith(fontSize: 10)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  IconData _activityIcon(String action) {
    switch (action) {
      case 'LOGIN':
      case 'CONNEXION_CAISSE_REUSSIE': return Icons.login;
      case 'LOGOUT':
      case 'DECONNEXION_CAISSE': return Icons.logout;
      case 'LOGIN_FAILED':
      case 'CONNEXION_CAISSE_ECHOUEE': return Icons.warning;
      case 'ORDER_CREATED':
      case 'CREATION_COMMANDE': return Icons.add_shopping_cart;
      case 'ANNULATION_COMMANDE': return Icons.cancel;
      case 'ORDER_STATUS_CHANGED': return Icons.update;
      case 'CAISSE_OPENED':
      case 'OUVERTURE_CAISSE': return Icons.point_of_sale;
      case 'CAISSE_CLOSED':
      case 'FERMETURE_CAISSE': return Icons.power_off;
      default: return Icons.circle;
    }
  }

  String _activityLabel(String action) {
    switch (action) {
      case 'LOGIN':
      case 'CONNEXION_CAISSE_REUSSIE': return 'auth.login'.tr();
      case 'LOGOUT':
      case 'DECONNEXION_CAISSE': return 'auth.logout'.tr();
      case 'LOGIN_FAILED':
      case 'CONNEXION_CAISSE_ECHOUEE': return 'auth.invalid_credentials'.tr();
      case 'ORDER_CREATED':
      case 'CREATION_COMMANDE': return 'orders.title'.tr();
      case 'ANNULATION_COMMANDE': return 'orders.status_cancelled'.tr();
      case 'ORDER_STATUS_CHANGED': return 'orders.order_status'.tr();
      case 'CAISSE_OPENED':
      case 'OUVERTURE_CAISSE': return 'pos.title'.tr();
      case 'CAISSE_CLOSED':
      case 'FERMETURE_CAISSE': return 'pos.title'.tr();
      default: return action;
    }
  }

  // ========== SHARED WIDGETS ==========

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      return iso.substring(0, 10);
    } catch (_) {
      return iso;
    }
  }
}
