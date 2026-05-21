import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/reviews_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import 'package:shimmer/shimmer.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/ai_chat_widget.dart';


class StoreDashboardScreen extends StatefulWidget {
  const StoreDashboardScreen({super.key});
  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _boutiqueSummary;
  bool _loadingDashboard = true;
  bool _togglingMessaging = false;

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
    // Guard: if still no boutique after load, redirect user to create one
    if (bp.boutiques.isEmpty) {
      if (mounted) context.go('/create-store');
      return;
    }
    if (bp.activeBoutique != null) {
      _dashboardData = await bp.loadDashboard();
      _boutiqueSummary = await bp.loadBoutiqueSummary();
      context.read<OrdersProvider>().loadOrders(bp.activeBoutique!.id, refresh: true);
      context.read<NotificationsProvider>().loadUnreadCount();
      context.read<ReviewsProvider>().loadPendingCount(bp.activeBoutique!.id);
      bp.loadStats();
    }
    if (mounted) setState(() => _loadingDashboard = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
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
                        Consumer<BoutiqueProvider>(
                          builder: (_, bp, __) {
                            if (bp.activeBoutique?.publicationStatus != 'FROZEN') return const SizedBox.shrink();
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Boutique gelée',
                                          style: AppTypography.body2.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade900)),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Votre boutique est gelée. Vous pouvez consulter vos données, mais les ventes sont désactivées.',
                                          style: AppTypography.caption.copyWith(color: Colors.orange.shade800)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        _buildPublicUrlCard(),
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
        ),
        // Floating AI chatbot
        Positioned(
          bottom: (MediaQuery.of(context).size.width <= 480 ? 88 : 20) + MediaQuery.of(context).padding.bottom,
          right: MediaQuery.of(context).size.width <= 480 ? 32 : 20,
          child: Consumer<BoutiqueProvider>(
            builder: (_, bp, __) {
              if (bp.activeBoutique == null) return const SizedBox.shrink();
              return AiChatWidget(
                boutiqueId: bp.activeBoutique!.id.toString(),
                boutiqueName: bp.activeBoutique!.name ?? '',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPublicUrlCard() {
    final bp = context.watch<BoutiqueProvider>();
    final boutique = bp.activeBoutique;
    if (boutique == null) return const SizedBox.shrink();
    final url = boutique.publicUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    final absUrl = Uri.base.origin + url;
    final pubStatus = boutique.publicationStatus ?? (boutique.isPublished ? 'PUBLISHED' : 'DRAFT');

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (pubStatus) {
      case 'FROZEN':
        statusColor = Colors.lightBlue;
        statusLabel = 'GELÉE';
        statusIcon = Icons.ac_unit;
      case 'SUSPENDED':
        statusColor = AppColors.danger;
        statusLabel = 'SUSPENDUE';
        statusIcon = Icons.block;
      case 'DRAFT':
        statusColor = Colors.orange;
        statusLabel = 'BROUILLON';
        statusIcon = Icons.edit_note;
      default:
        statusColor = AppColors.success;
        statusLabel = 'PUBLIÉE';
        statusIcon = Icons.check_circle;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Lien public de votre boutique', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusLabel, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: absUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL copiée !'), behavior: SnackBarBehavior.floating));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(url, style: AppTypography.caption.copyWith(color: AppColors.primary)),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.copy, size: 16, color: AppColors.textHint),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (pubStatus == 'DRAFT')
                _smallBtn(Icons.publish, 'Publier', AppColors.primary, () async {
                  final ok = await context.read<BoutiqueProvider>().publishBoutique();
                  if (mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Boutique publiée !'), behavior: SnackBarBehavior.floating));
                  }
                })
              else if (pubStatus == 'PUBLISHED')
                _smallBtn(Icons.unpublished, 'Dépublier', Colors.orange, () async {
                  final ok = await context.read<BoutiqueProvider>().unpublishBoutique();
                  if (mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Boutique dépubliée'), behavior: SnackBarBehavior.floating));
                  }
                }),
              const SizedBox(width: 8),
              _smallBtn(Icons.open_in_new, 'Ouvrir', AppColors.primary, () async {
                await launchUrl(Uri.parse(absUrl), mode: LaunchMode.externalApplication);
              }),
              const SizedBox(width: 8),
              _smallBtn(Icons.share, 'Partager', AppColors.primary, () {
                Clipboard.setData(ClipboardData(text: absUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lien copié: $absUrl'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ],
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
                Text('/store/${boutique?.slug ?? ''}',
                    style: AppTypography.caption.copyWith(color: AppColors.primary)),
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
    if (_loadingDashboard) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Shimmer.fromColors(
          baseColor: AppColors.border,
          highlightColor: AppColors.surfaceAlt,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    if (_boutiqueSummary == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withAlpha(80)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 18, color: AppColors.danger),
            const SizedBox(width: 8),
            Text('Impossible de charger les statistiques',
                style: AppTypography.caption.copyWith(color: AppColors.danger)),
          ],
        ),
      );
    }

    final data = _boutiqueSummary!;
    // ignore: avoid_print
    print('[Dashboard] boutique-summary data=$data');
    final views = '${data['views'] ?? 0}';
    final products = '${data['products'] ?? 0}';

    final daysRaw = data['remainingDays'];
    final subStatus = data['subscriptionStatus'] as String? ?? 'FREE';
    final plan = data['planName'] as String? ?? 'Free';

    final bool isExpired = subStatus == 'EXPIRED';
    final bool isUnlimited = daysRaw is int && daysRaw == -1;
    final bool isError = subStatus == 'ERROR';

    String daysValue;
    String planLabel;
    Color daysColor = AppColors.textPrimary;

    if (isError) {
      daysValue = '--';
      planLabel = 'Erreur';
      daysColor = AppColors.danger;
    } else if (isUnlimited) {
      daysValue = '∞';
      planLabel = 'Illimité';
    } else if (isExpired) {
      daysValue = '0';
      planLabel = 'Expiré';
      daysColor = AppColors.danger;
    } else {
      daysValue = '${daysRaw ?? 0}';
      planLabel = plan;
    }

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
            Expanded(
              child: _statColumn(
                daysValue == '∞' ? '∞' : '$daysValue\njours',
                planLabel,
                valueColor: daysColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String value, String label, {Color? valueColor}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, textAlign: TextAlign.center,
            style: TextStyle(fontSize: value.length > 8 ? 18 : 26,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
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
            if (b != null) context.push('/catalog/${b.id}', extra: {'name': b.name, 'slug': b.slug});
          }),
          const SizedBox(width: 8),
          _actionChip(Icons.settings, 'Paramètres', false, () => context.go('/boutique-settings')),
          const SizedBox(width: 8),
          _actionChip(Icons.add, 'Ajouter un produit', false, () => context.push('/products/add'), grey: true),
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
          Consumer<BoutiqueProvider>(
            builder: (_, bp, __) {
              final enabled = bp.activeBoutique?.clientMessagingEnabled ?? true;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Client messaging', style: AppTypography.caption),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 24,
                    child: _togglingMessaging
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : Switch(
                            value: enabled,
                            activeTrackColor: Colors.green.shade300,
                            activeThumbColor: Colors.green,
                            onChanged: (v) async {
                              setState(() => _togglingMessaging = true);
                              try {
                                await bp.saveConfig({'clientMessagingEnabled': v ? 'yes' : 'no'});
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Messaging ${v ? 'activé' : 'désactivé'}'), behavior: SnackBarBehavior.floating));
                                }
                              } catch (_) {}
                              if (mounted) setState(() => _togglingMessaging = false);
                            },
                          ),
                  ),
                ],
              );
            },
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
              SectionHeader(
                title: 'Commandes récentes',
                actionLabel: 'Voir tout',
                onAction: () => context.go('/orders'),
              ),
              const SizedBox(height: 8),
              if (op.loading)
                const LoadingSkeleton(itemCount: 3)
              else               if (op.orders.isEmpty)
                const AppCard(
                  padding: EdgeInsets.zero,
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucune commande',
                    subtitle: 'Les commandes apparaîtront ici',
                  ),
                )
              else
                ...op.orders.take(5).map((order) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => context.go('/orders/${order.id}'),
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
          SectionHeader(title: 'Stock faible'),
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
