import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/boutique_provider.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _plans = [];
  Map<String, dynamic>? _subscription;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final plansRes = await _api.get('/plans');
      Map<String, dynamic>? subRes;
      try {
        subRes = (await _api.get('/subscriptions/mine'))['data'];
      } catch (_) {}
      setState(() {
        _plans = plansRes['data'] ?? [];
        _subscription = subRes;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _subscribe(int planId) async {
    try {
      await _api.post('/subscriptions/subscribe', data: {'planId': planId, 'paymentMethod': 'BANK'});
      if (mounted) {
        context.read<AuthProvider>().setSubscriptionActive(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abonnement activé!')));
        final bp = context.read<BoutiqueProvider>();
        await bp.loadBoutiques();
        if (mounted) {
          if (bp.boutiques.isEmpty) {
            context.go('/create-store');
          } else {
            context.go('/dashboard');
          }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.heroGradient),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Abonnement', style: AppTypography.heading2.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      _subscription != null ? 'Plan ${_subscription!['planName'] ?? "Gratuit"}' : 'Choisissez votre plan',
                      style: AppTypography.body1.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            pinned: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_subscription != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Abonnement actuel', style: AppTypography.heading4),
                          const SizedBox(height: 8),
                          Text('Plan: ${_subscription!['planName'] ?? "Gratuit"}', style: AppTypography.body2),
                          if (_subscription!['expiresAt'] != null) Text('Expire le: ${_subscription!['expiresAt']}', style: AppTypography.caption),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: const LinearProgressIndicator(value: 0.5, backgroundColor: AppColors.border, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ..._plans.map((plan) => _planCard(plan)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(dynamic plan) {
    final isCurrentPlan = _subscription != null && _subscription!['planId'] == plan['id'];
    final name = plan['name'] ?? '';
    final price = (plan['priceDt'] ?? 0).toDouble();
    final days = plan['durationDays'] ?? 0;
    final maxProducts = plan['maxProducts'] ?? 0;
    final features = plan['features'] is String ? plan['features'] : '';
    final isHighlighted = name == '3 Mois';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? AppColors.primary : AppColors.border,
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: AppTypography.heading3),
              if (isHighlighted)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text('Économisez 15%', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${price.toStringAsFixed(2)} TND${days > 0 ? " / $days jours" : ""}', style: AppTypography.heading2.copyWith(color: AppColors.primary)),
          const SizedBox(height: 4),
          Text('Jusqu\'à $maxProducts produits', style: AppTypography.caption),
          const SizedBox(height: 16),
          if (features.isNotEmpty) ...[
            ...features.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',').map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(f.trim(), style: AppTypography.body2),
                ],
              ),
            )),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrentPlan ? null : () => _subscribe(plan['id']),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrentPlan ? AppColors.surfaceAlt : AppColors.primary,
                foregroundColor: isCurrentPlan ? AppColors.textHint : Colors.white,
                side: isCurrentPlan ? const BorderSide(color: AppColors.border) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              child: Text(isCurrentPlan ? 'Plan actuel' : 'Choisir ce plan'),
            ),
          ),
        ],
      ),
    );
  }
}
