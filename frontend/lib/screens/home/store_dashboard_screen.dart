import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/reviews_provider.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/status_chip.dart';


class StoreDashboardScreen extends StatefulWidget {
  const StoreDashboardScreen({super.key});
  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _loadingDashboard = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final bp = context.read<BoutiqueProvider>();
    if (bp.boutiques.isEmpty) {
      await bp.loadBoutiques();
    }
    if (bp.activeBoutique != null) {
      _dashboardData = await bp.loadDashboard();
      context.read<OrdersProvider>().loadOrders(bp.activeBoutique!.id, refresh: true);
      context.read<NotificationsProvider>().loadUnreadCount();
      context.read<ReviewsProvider>().loadPendingCount(bp.activeBoutique!.id);
      bp.loadStats();
    }
    if (mounted) setState(() => _loadingDashboard = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Consumer<BoutiqueProvider>(
          builder: (_, bp, __) => GestureDetector(
            onTap: () => context.go('/store-selector'),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                backgroundImage: bp.activeBoutique?.logoUrl != null && bp.activeBoutique!.logoUrl!.isNotEmpty
                    ? NetworkImage(bp.activeBoutique!.logoUrl!) : null,
                child: bp.activeBoutique?.logoUrl == null || bp.activeBoutique!.logoUrl!.isEmpty
                    ? Text((bp.activeBoutique?.name ?? 'S')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))
                    : null,
              ),
            ),
          ),
        ),
        title: Consumer<BoutiqueProvider>(
          builder: (_, bp, __) => Text(bp.activeBoutique?.name ?? 'MakeWebsite', style: AppTypography.heading4),
        ),
        actions: [
          Consumer<NotificationsProvider>(
            builder: (_, np, __) => Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.go('/notifications'),
                ),
                if (np.unreadCount > 0)
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                      child: Text('${np.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { await _loadData(); },
        child: _loadingDashboard
            ? const LoadingSkeleton()
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStoreHeader(),
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                    _buildQuickActionsRow1(),
                    const SizedBox(height: 8),
                    _buildQuickActionsRow2(),
                    const SizedBox(height: 16),
                    _buildBigCTAButtons(),
                    const SizedBox(height: 16),
                    _buildRecentOrders(),
                    const SizedBox(height: 16),
                    _buildLowStockAlert(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStoreHeader() {
    final bp = context.watch<BoutiqueProvider>();
    final boutique = bp.activeBoutique;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primary,
            backgroundImage: boutique?.logoUrl != null && boutique!.logoUrl!.isNotEmpty
                ? NetworkImage(boutique.logoUrl!) : null,
            child: boutique?.logoUrl == null || boutique!.logoUrl!.isEmpty
                ? Text((boutique?.name ?? 'S')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(boutique?.name ?? '', style: AppTypography.heading2),
                const SizedBox(height: 2),
                Text('${boutique?.slug ?? ''}.makewebsite.io',
                    style: AppTypography.caption.copyWith(color: AppColors.textHint)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('Ecommerce', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final data = _dashboardData;
    final views = data != null ? '${data['views'] ?? 0}' : '0';
    final products = data != null ? '${data['productCount'] ?? 0}' : '0';
    final daysLeft = data != null ? '${data['subscriptionDaysLeft'] ?? 0}' : '0';
    final plan = data != null ? '${data['subscriptionPlan'] ?? 'Free'}' : '';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _statColumn(views, 'Views')),
            const VerticalDivider(color: AppColors.border, width: 1),
            Expanded(child: _statColumn(products, 'Products')),
            const VerticalDivider(color: AppColors.border, width: 1),
            Expanded(child: _statColumn('$daysLeft\njours', plan)),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, textAlign: TextAlign.center,
            style: TextStyle(fontSize: value.length > 6 ? 20 : 28,
                fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                height: 1.1)),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.caption.copyWith(color: AppColors.textHint)),
      ],
    );
  }

  Widget _buildQuickActionsRow1() {
    final bp = context.watch<BoutiqueProvider>();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _actionChip(Icons.open_in_new, 'Voir la boutique', true, () {
            final b = bp.activeBoutique;
            if (b != null) context.push('/store/${b.id}', extra: {'name': b.name, 'slug': b.slug});
          }),
          const SizedBox(width: 8),
          _actionChip(Icons.settings, 'Paramètres', false, () => context.go('/boutique-settings')),
          const SizedBox(width: 8),
          _actionChip(Icons.add, 'Ajouter un produit', false, () => context.go('/products/add'), grey: true),
          const SizedBox(width: 8),
          _actionChip(Icons.upload_file, 'Ajouter des produits', false, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Import en masse - à venir'), behavior: SnackBarBehavior.floating));
          }, grey: true),
          const SizedBox(width: 8),
          _actionChip(Icons.inventory_2_outlined, 'Produits', false, () => context.go('/products'), grey: true),
          const SizedBox(width: 8),
          _actionChip(Icons.shopping_cart_outlined, 'Commandes', false, () => context.go('/orders'), grey: true),
          const SizedBox(width: 8),
          _actionChip(Icons.people_outline, 'My Clients', false, () => context.go('/customers'), grey: true),
          const SizedBox(width: 8),
          _actionChip(Icons.local_shipping_outlined, 'Société de livraison', false, () => context.go('/delivery'), grey: true),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow2() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _actionChip(Icons.bar_chart, 'Traffic', false, () => context.go('/analytics'), grey: true),
          const SizedBox(width: 8),
          _actionChip(Icons.message_outlined, 'Messages', false, () => context.go('/messages'), grey: true),
          const SizedBox(width: 8),
          _actionChip(Icons.group_outlined, 'Équipe', false, () => context.go('/team'), grey: true),
          const SizedBox(width: 8),
          Consumer<ReviewsProvider>(
            builder: (_, rp, __) => GestureDetector(
              onTap: () => context.go('/reviews'),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_outline, size: 16, color: AppColors.textPrimary),
                    const SizedBox(width: 6),
                    const Text('Avis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                    if (rp.pendingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text('${rp.pendingCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _actionChip(Icons.palette_outlined, 'Theme', false, () => context.go('/boutique/theme'), grey: true),
          const SizedBox(width: 8),
          _actionChip(Icons.layers_outlined, 'Template', false, () => context.go('/boutique/template'), grey: true),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Client messaging', style: AppTypography.caption),
              const SizedBox(width: 4),
              SizedBox(
                height: 24,
                child: Switch(
                  value: true,
                  activeTrackColor: Colors.green.shade300,
                  activeThumbColor: Colors.green,
                  onChanged: (v) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Messaging ${v ? 'activé' : 'désactivé'}'), behavior: SnackBarBehavior.floating));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, bool filled, VoidCallback onTap, {bool grey = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: filled ? AppColors.primary : (grey ? AppColors.border : AppColors.primary)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : (grey ? AppColors.textPrimary : AppColors.primary)),
            const SizedBox(width: 6),
            Text(label,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: filled ? Colors.white : (grey ? AppColors.textPrimary : AppColors.primary),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildBigCTAButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _bigCTA(Icons.dashboard_outlined, 'Ouvrir mon tableau de bord', const Color(0xFF4040C8), () => context.go('/analytics'))),
              const SizedBox(width: 8),
              Expanded(child: _bigCTA(Icons.point_of_sale, 'Ouvrir mon point de vente', const Color(0xFF1E7D4E), () => context.go('/pos'))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _bigCTA(Icons.admin_panel_settings_outlined, 'Administration Caisse', const Color(0xFF8B2FC9), () => context.go('/pos/admin'))),
              const SizedBox(width: 8),
              Expanded(child: _bigCTA(Icons.telegram, 'Telegram', const Color(0xFF0098C7), () => context.go('/telegram'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bigCTA(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Consumer<OrdersProvider>(
      builder: (_, op, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Commandes récentes', style: AppTypography.heading3),
                  TextButton(
                    onPressed: () => context.go('/orders'),
                    child: const Text('Voir tout', style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (op.loading)
                const LoadingSkeleton(itemCount: 3)
              else if (op.orders.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textHint.withAlpha(80)),
                        const SizedBox(height: 8),
                        Text('Aucune commande', style: AppTypography.body2.copyWith(color: AppColors.textHint)),
                      ],
                    ),
                  ),
                )
              else
                ...op.orders.take(5).map((order) => GestureDetector(
                  onTap: () => context.go('/orders/${order.id}'),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.orderNumber, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(order.customerName ?? 'Client inconnu', style: AppTypography.caption),
                            ],
                          ),
                        ),
                        Text('${order.total.toStringAsFixed(2)} TND', style: AppTypography.body2.copyWith(color: AppColors.primary)),
                        const SizedBox(width: 8),
                        StatusChip(status: order.status),
                      ],
                    ),
                  ),
                )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLowStockAlert() {
    final lowStock = _dashboardData != null ? (_dashboardData!['lowStockProducts'] as List? ?? []) : [];
    if (lowStock.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.danger),
              const SizedBox(width: 6),
              Text('Stock faible', style: AppTypography.heading3),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: lowStock.length,
              itemBuilder: (_, i) {
                final item = lowStock[i] as Map<String, dynamic>;
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withAlpha(80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item['name']?.toString() ?? '', style: AppTypography.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withAlpha(30),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text('Stock: ${item['stock'] ?? 0}',
                            style: const TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.w600)),
                      ),
                    ],
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
