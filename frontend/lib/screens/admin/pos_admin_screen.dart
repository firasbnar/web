import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/pos_admin_provider.dart';
import '../../models/cashier.dart';
import 'package:provider/provider.dart';

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
            title: const Text('Administration Caisse'),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard), text: 'Tableau de bord'),
                Tab(icon: Icon(Icons.people), text: 'Caissiers'),
                Tab(icon: Icon(Icons.receipt_long), text: 'Commandes'),
                Tab(icon: Icon(Icons.history), text: 'Activité'),
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
              label: const Text('Réessayer'),
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
        _metricCard('Total ventes', '${d?['totalVentes'] ?? 0} TND', Icons.trending_up, AppColors.primary),
        _metricCard('Ventes aujourd\'hui', '${d?['ventesAujourdhui'] ?? 0} TND', Icons.today, Colors.green),
        _metricCard('Commandes aujourd\'hui', '${d?['commandesAujourdhui'] ?? 0}', Icons.receipt, Colors.amber),
        _metricCard('Total commandes', '${d?['totalCommandes'] ?? 0}', Icons.receipt_long, Colors.cyan),
        _metricCard('Caisses actives', '${d?['caissesActives'] ?? 0}', Icons.point_of_sale, Colors.purple),
        _metricCard('Utilisateurs connectés', '${d?['utilisateursConnectes'] ?? 0}', Icons.person, Colors.pink),
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
                    hintText: 'Rechercher un caissier...',
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
                label: const Text('Nouvel Utilisateur'),
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
          _smallStat('Caissiers', '${cs?['totalCashiers'] ?? '...'}', Icons.people, AppColors.primary),
          _smallStat('En ligne', '${cs?['onlineCashiers'] ?? '...'}', Icons.wifi, Colors.green),
          _smallStat('Ventes', '${cs?['totalSales'] ?? '...'} TND', Icons.trending_up, Colors.amber),
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
            const Text('Impossible de charger les caissiers'),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
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
      return const Center(child: Text('Aucun caissier trouvé'));
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
              child: const Text('SUSPENDU', style: TextStyle(fontSize: 10, color: AppColors.danger)),
            ),
          if (!c.isSuspended && c.online)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(30),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text('EN LIGNE', style: TextStyle(fontSize: 10, color: AppColors.success)),
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
                child: Text(c.isSuspended ? 'Activer' : 'Suspendre'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
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
          title: const Text('Nouvel Utilisateur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom complet', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(labelText: 'Rôle', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'STAFF', child: Text('STAFF')),
                  DropdownMenuItem(value: 'MANAGER', child: Text('MANAGER')),
                ],
                onChanged: (v) { if (v != null) setDialogState(() => _selectedRole = v); },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final ok = await p.createCashier(_emailCtrl.text.trim(), _nameCtrl.text.trim(), _selectedRole);
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Caissier ajouté' : p.cashierActionError ?? 'Erreur'),
                      backgroundColor: ok ? AppColors.success : AppColors.danger,
                    ),
                  );
                }
              },
              child: const Text('Ajouter'),
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
        title: const Text('Confirmer'),
        content: Text('Supprimer "${c.fullName}" de la boutique ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await p.deleteCashier(c.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Caissier supprimé' : p.cashierActionError ?? 'Erreur'),
                    backgroundColor: ok ? AppColors.success : AppColors.danger,
                  ),
                );
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
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
              ? suspend ? 'Caissier suspendu' : 'Caissier activé'
              : p.cashierActionError ?? 'Erreur'),
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
          _userTab('Tous', p.orderUserIdFilter == null, () => p.selectCashier(null)),
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
              Text('${c.commandesCount} commandes', style: AppTypography.caption),
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
            _filterChip('Tous', p.orderStatusFilter == '', () => p.setOrderStatusFilter('')),
            _filterChip('En attente', p.orderStatusFilter == 'PENDING', () => p.setOrderStatusFilter('PENDING')),
            _filterChip('Confirmée', p.orderStatusFilter == 'CONFIRMED', () => p.setOrderStatusFilter('CONFIRMED')),
            _filterChip('Préparation', p.orderStatusFilter == 'PREPARING', () => p.setOrderStatusFilter('PREPARING')),
            _filterChip('Prête', p.orderStatusFilter == 'READY', () => p.setOrderStatusFilter('READY')),
            _filterChip('Livrée', p.orderStatusFilter == 'DELIVERED', () => p.setOrderStatusFilter('DELIVERED')),
            _filterChip('Annulée', p.orderStatusFilter == 'CANCELLED', () => p.setOrderStatusFilter('CANCELLED')),
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
            const Text('Impossible de charger les commandes'),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
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
      return const Center(child: Text('Aucune commande'));
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
            _detailRow('Client', order['customerName'] ?? 'Client inconnu'),
            _detailRow('Statut', _orderStatusLabel(order['status'] ?? '')),
            _detailRow('Total', '${order['total'] ?? 0} TND'),
            _detailRow('Paiement', order['paymentStatus'] ?? 'N/A'),
            _detailRow('Méthode', order['paymentMethod'] ?? 'N/A'),
            if (order['createdAt'] != null)
              _detailRow('Date', order['createdAt'].toString().substring(0, 16)),
            if (order['notes'] != null && (order['notes'] as String).isNotEmpty)
              _detailRow('Notes', order['notes']),
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
      case 'PENDING': return 'En attente';
      case 'CONFIRMED': return 'Confirmée';
      case 'PREPARING': return 'Préparation';
      case 'READY': return 'Prête';
      case 'DELIVERED': return 'Livrée';
      case 'CANCELLED': return 'Annulée';
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
                _filterChip('Toutes', p.activityActionFilter == '', () => p.setActivityActionFilter('')),
                _filterChip('Connexion', p.activityActionFilter == 'CONNEXION_CAISSE_REUSSIE', () => p.setActivityActionFilter('CONNEXION_CAISSE_REUSSIE')),
                _filterChip('Déconnexion', p.activityActionFilter == 'DECONNEXION_CAISSE', () => p.setActivityActionFilter('DECONNEXION_CAISSE')),
                _filterChip('Commande', p.activityActionFilter == 'CREATION_COMMANDE', () => p.setActivityActionFilter('CREATION_COMMANDE')),
                _filterChip('Caisse', p.activityActionFilter == 'OUVERTURE_CAISSE', () => p.setActivityActionFilter('OUVERTURE_CAISSE')),
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
                label: const Text('Voir le journal complet', style: TextStyle(fontSize: 12)),
                onPressed: () => context.go('/admin/activities'),
              ),
              const Spacer(),
              Text('${p.activities.length} activités', style: AppTypography.caption.copyWith(fontSize: 11)),
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
                      const Text('Impossible de charger les activités'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                        onPressed: () => p.loadActivities(refresh: true),
                      ),
                    ],
                  ),
                )
              : p.loadingActivities && p.activities.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : p.activities.isEmpty
                      ? const Center(child: Text('Aucune activité'))
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
      case 'CONNEXION_CAISSE_REUSSIE': return 'Connexion';
      case 'LOGOUT':
      case 'DECONNEXION_CAISSE': return 'Déconnexion';
      case 'LOGIN_FAILED':
      case 'CONNEXION_CAISSE_ECHOUEE': return 'Échec de connexion';
      case 'ORDER_CREATED':
      case 'CREATION_COMMANDE': return 'Nouvelle commande';
      case 'ANNULATION_COMMANDE': return 'Commande annulée';
      case 'ORDER_STATUS_CHANGED': return 'Statut commande modifié';
      case 'CAISSE_OPENED':
      case 'OUVERTURE_CAISSE': return 'Caisse ouverte';
      case 'CAISSE_CLOSED':
      case 'FERMETURE_CAISSE': return 'Caisse fermée';
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
