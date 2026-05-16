import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../models/plan.dart';
import '../../providers/boutique_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/stat_card.dart';

class SubscriptionDashboardScreen extends StatefulWidget {
  const SubscriptionDashboardScreen({super.key});

  @override
  State<SubscriptionDashboardScreen> createState() => _SubscriptionDashboardScreenState();
}

class _SubscriptionDashboardScreenState extends State<SubscriptionDashboardScreen> {
  final _api = ApiClient();
  Subscription? _subscription;
  List<Plan> _plans = [];
  List<Invoice> _invoices = [];
  bool _loading = true;
  bool _cancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final subRes = await _api.get('/subscriptions/mine');
      _subscription = Subscription.fromJson(subRes['data']);
      final planRes = await _api.get('/plans');
      _plans = (planRes['data'] as List).map((e) => Plan.fromJson(e)).toList();
      final invRes = await _api.get('/subscriptions/invoices');
      _invoices = (invRes['data'] as List?)?.map((e) => Invoice.fromJson(e)).toList() ?? [];
      if (mounted) context.read<BoutiqueProvider>().loadStats();
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
    }
    setState(() => _loading = false);
  }

  Future<void> _cancelSubscription() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Résilier l\'abonnement'),
        content: const Text('Voulez-vous vraiment résilier votre abonnement actif ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui, résilier')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _cancelling = true);
    try {
      await _api.post('/subscriptions/cancel', data: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abonnement résilié'), backgroundColor: AppColors.success));
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiClient.extractErrorMessage(e)), backgroundColor: AppColors.danger));
      }
    }
    setState(() => _cancelling = false);
  }

  int get _remainingDays {
    if (_subscription?.expiresAt == null) return 0;
    try {
      final expires = DateTime.parse(_subscription!.expiresAt!);
      return expires.difference(DateTime.now()).inDays.clamp(0, 9999);
    } catch (_) {
      return 0;
    }
  }

  Plan? get _currentPlan => _plans.cast<Plan?>().firstWhere(
    (p) => p!.id == (_subscription?.planId ?? 0), orElse: () => null);

  String _planName() => _currentPlan?.name ?? _subscription?.planName ?? 'Aucun';

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<BoutiqueProvider>().stats;

    return Scaffold(
      appBar: AppBar(title: const Text('Abonnement')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(_planName(), style: AppTypography.heading2.copyWith(color: Colors.white)),
                            const SizedBox(height: 8),
                            Text(_subscription?.status ?? 'INACTIF', style: AppTypography.body2.copyWith(color: Colors.white70)),
                            const SizedBox(height: 12),
                            Text('$_remainingDays jours restants', style: AppTypography.heading3.copyWith(color: Colors.white)),
                            if (_subscription?.expiresAt != null) ...[
                              const SizedBox(height: 4),
                              Text('Expire le ${_subscription!.expiresAt!.substring(0, 10)}', style: AppTypography.caption.copyWith(color: Colors.white70)),
                            ],
                            if (_subscription?.status == 'ACTIVE') ...[
                              const SizedBox(height: 16),
                              AppButton(
                                label: 'Résilier l\'abonnement',
                                onPressed: _cancelling ? null : _cancelSubscription,
                                loading: _cancelling,
                                color: AppColors.danger,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Utilisation', style: AppTypography.heading3),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _usageCard(
                              'Produits', '${stats?.totalProducts ?? 0}',
                              Icons.inventory_2_outlined,
                              used: (stats?.totalProducts ?? 0),
                              max: _currentPlan?.maxProducts,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: StatCard(
                            label: 'Commandes',
                            value: '${stats?.totalOrders ?? 0}',
                            icon: Icons.receipt_long_outlined,
                          )),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Plans disponibles', style: AppTypography.heading3),
                      const SizedBox(height: 12),
                      ...(_plans.map((plan) => _planCard(plan))),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Voir tous les plans',
                        onPressed: () => context.push('/plans'),
                        outlined: true,
                      ),
                      const SizedBox(height: 24),
                      Text('Historique des factures', style: AppTypography.heading3),
                      const SizedBox(height: 12),
                      if (_invoices.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('Aucune facture', style: TextStyle(color: AppColors.textHint)),
                        )
                      else
                        ...(_invoices.map((inv) => _invoiceCard(inv))),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _invoiceCard(Invoice inv) {
    final statusColor = inv.status == 'PAID' ? AppColors.success
        : inv.status == 'CANCELLED' ? AppColors.textHint
        : AppColors.warning;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inv.planName ?? 'Facture', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                if (inv.paidAt != null) Text(inv.paidAt!.substring(0, 10), style: AppTypography.caption),
                if (inv.paymentRef != null) Text('Réf: ${inv.paymentRef}', style: AppTypography.caption),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${inv.amount.toStringAsFixed(2)} ${inv.currency}', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(inv.status, style: TextStyle(fontSize: 10, color: statusColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _usageCard(String label, String value, IconData icon, {int used = 0, int? max}) {
    final ratio = (max != null && max > 0) ? (used / max).clamp(0.0, 1.0) : 0.0;
    return Container(
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
              Icon(icon, size: 20, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.heading2),
          Text(label, style: AppTypography.caption),
          if (max != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: AppColors.border,
                color: ratio > 0.8 ? AppColors.danger : AppColors.primary,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text('${(ratio * 100).toInt()}% de $max utilisés', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
          ],
        ],
      ),
    );
  }

  Widget _planCard(Plan plan) {
    final isCurrent = plan.id == (_subscription?.planId ?? 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.primarySurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCurrent ? AppColors.primary : AppColors.border, width: isCurrent ? 2 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                if (isCurrent) Text('Plan actuel', style: AppTypography.caption.copyWith(color: AppColors.primary)),
              ],
            ),
          ),
          Text(plan.priceDt == 0 ? 'Gratuit' : '${plan.priceDt.toStringAsFixed(0)} DT${plan.durationDays > 30 ? '/mois' : ''}', style: AppTypography.heading4),
        ],
      ),
    );
  }
}
